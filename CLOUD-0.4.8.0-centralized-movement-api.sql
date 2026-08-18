-- Panorama Cloud 0.4.8.0
-- API oficial de alta de movimientos para Panorama Web + Panorama Go.
--
-- Objetivo:
--   Centralizar en PostgreSQL/Supabase la lógica que transforma una intención
--   de usuario en filas de movements/installment_plans.
--
-- Soporta:
--   - ingreso/gasto por cuenta
--   - compra con tarjeta en un pago
--   - compra con tarjeta en N cuotas
--
-- No soporta en esta primera versión:
--   - transferencias entre cuentas (ya usan panorama_save_transfer)
--   - pago de tarjeta
--
-- Seguridad:
--   - security invoker
--   - auth.uid()
--   - valida pertenencia de categoría, cuenta y tarjeta

create or replace function public.panorama_save_movement(p_input jsonb)
returns jsonb
language plpgsql
security invoker
set search_path=public
as $$
declare
  uid uuid := auth.uid();

  v_type text := lower(coalesce(nullif(p_input->>'type',''),'expense'));
  v_payment_method text := lower(coalesce(nullif(p_input->>'payment_method',''),'account'));
  v_description text := nullif(btrim(coalesce(p_input->>'description','')),'');
  v_amount numeric := nullif(p_input->>'amount','')::numeric;
  v_date date := nullif(p_input->>'date','')::date;
  v_category_id text := nullif(p_input->>'category_id','');
  v_category_name text;

  v_account_id uuid := nullif(p_input->>'account_id','')::uuid;
  v_card_id uuid := nullif(p_input->>'card_id','')::uuid;

  v_paid boolean := coalesce((p_input->>'paid')::boolean, true);
  v_complete boolean := coalesce((p_input->>'complete')::boolean, true);
  v_paid_amount numeric := nullif(p_input->>'paid_amount','')::numeric;

  v_movement_id uuid := coalesce(nullif(p_input->>'movement_id','')::uuid, gen_random_uuid());

  v_currency text;
  v_closing_day integer;
  v_effective_closing integer;
  v_last_day integer;
  v_billing_month text;

  v_installments integer := greatest(1, coalesce(nullif(p_input->>'installments','')::integer, 1));
  v_plan_id uuid;
  v_installment_amount numeric;
  v_index integer;
  v_generated_id uuid;
begin
  if uid is null then
    raise exception 'Usuario no autenticado';
  end if;

  if v_type not in ('income','expense') then
    raise exception 'Tipo de movimiento inválido';
  end if;

  if v_payment_method not in ('account','card') then
    raise exception 'Medio de movimiento inválido';
  end if;

  if v_amount is null or v_amount <= 0 then
    raise exception 'El importe debe ser mayor a cero';
  end if;

  if v_date is null then
    raise exception 'La fecha es obligatoria';
  end if;

  -- La categoría se resuelve y valida en servidor.
  if v_category_id is not null then
    select c.name
      into v_category_name
      from public.categories c
     where c.user_id=uid
       and c.id=v_category_id
       and c.type=v_type;

    if v_category_name is null then
      raise exception 'La categoría no pertenece al usuario o no corresponde al tipo de movimiento';
    end if;
  else
    v_category_name := 'Sin categoría';
  end if;

  if v_payment_method='account' then
    if v_account_id is null then
      raise exception 'La cuenta es obligatoria';
    end if;

    select a.currency
      into v_currency
      from public.accounts a
     where a.user_id=uid
       and a.id=v_account_id;

    if v_currency is null then
      raise exception 'La cuenta no pertenece al usuario';
    end if;

    -- Un ingreso real siempre queda completo. En gastos Panorama Web puede
    -- enviar explícitamente paid/complete/paid_amount.
    if v_type='income' then
      v_paid := true;
      v_complete := true;
      v_paid_amount := v_amount;
    else
      v_paid_amount := coalesce(v_paid_amount, case when v_complete then v_amount when v_paid then v_amount else 0 end);
      v_paid_amount := greatest(0, least(v_amount, v_paid_amount));
      v_paid := v_paid_amount > 0;
      v_complete := v_paid_amount >= v_amount;
    end if;

    insert into public.movements(
      user_id,id,type,operation_type,description,amount,date,purchase_date,billing_month,
      category_id,category,paid,complete,paid_amount,account_id,destination_account_id,destination_amount,
      currency,payment_method,card_id,applied_amount,applied_currency,effective_rate,origin,
      source_recurring_id,installment_plan_id,installment_number,installment_count,budget_impact,
      carried_to,payload
    )
    values(
      uid,v_movement_id,v_type,null,coalesce(v_description,'Movimiento'),round(v_amount,2),v_date,null,null,
      v_category_id,v_category_name,v_paid,v_complete,round(v_paid_amount,2),v_account_id,null,null,
      v_currency,'account',null,null,null,null,null,
      null,null,null,null,null,
      coalesce(p_input->'carried_to','[]'::jsonb),coalesce(p_input->'payload','{}'::jsonb)
    )
    on conflict(user_id,id) do update
    set type=excluded.type,
        operation_type=excluded.operation_type,
        description=excluded.description,
        amount=excluded.amount,
        date=excluded.date,
        purchase_date=excluded.purchase_date,
        billing_month=excluded.billing_month,
        category_id=excluded.category_id,
        category=excluded.category,
        paid=excluded.paid,
        complete=excluded.complete,
        paid_amount=excluded.paid_amount,
        account_id=excluded.account_id,
        destination_account_id=excluded.destination_account_id,
        destination_amount=excluded.destination_amount,
        currency=excluded.currency,
        payment_method=excluded.payment_method,
        card_id=excluded.card_id,
        applied_amount=excluded.applied_amount,
        applied_currency=excluded.applied_currency,
        effective_rate=excluded.effective_rate,
        origin=excluded.origin,
        source_recurring_id=excluded.source_recurring_id,
        installment_plan_id=excluded.installment_plan_id,
        installment_number=excluded.installment_number,
        installment_count=excluded.installment_count,
        budget_impact=excluded.budget_impact,
        carried_to=excluded.carried_to,
        payload=excluded.payload,
        updated_at=now();

    return jsonb_build_object(
      'kind','account',
      'movement_id',v_movement_id,
      'amount',round(v_amount,2),
      'currency',v_currency,
      'date',v_date
    );
  end if;

  -- Tarjeta: solamente gastos.
  if v_type <> 'expense' then
    raise exception 'Una tarjeta de crédito solo puede utilizarse para gastos';
  end if;

  if v_card_id is null then
    raise exception 'La tarjeta es obligatoria';
  end if;

  select c.currency,c.closing_day
    into v_currency,v_closing_day
    from public.credit_cards c
   where c.user_id=uid
     and c.id=v_card_id;

  if v_currency is null then
    raise exception 'La tarjeta no pertenece al usuario';
  end if;

  -- Replica billingMonthForPurchase() de Panorama:
  -- sin cierre configurado -> mes siguiente
  -- compra hasta el cierre -> mes siguiente
  -- compra después del cierre -> dos meses después
  v_last_day := extract(day from (date_trunc('month',v_date) + interval '1 month - 1 day')::date);
  v_effective_closing := case
    when v_closing_day is null then 0
    else least(greatest(v_closing_day,1),v_last_day)
  end;

  v_billing_month := to_char(
    date_trunc('month',v_date) +
      case
        when v_effective_closing=0 then interval '1 month'
        when extract(day from v_date)::integer <= v_effective_closing then interval '1 month'
        else interval '2 month'
      end,
    'YYYY-MM'
  );

  if v_installments = 1 then
    insert into public.movements(
      user_id,id,type,operation_type,description,amount,date,purchase_date,billing_month,
      category_id,category,paid,complete,paid_amount,account_id,destination_account_id,destination_amount,
      currency,payment_method,card_id,applied_amount,applied_currency,effective_rate,origin,
      source_recurring_id,installment_plan_id,installment_number,installment_count,budget_impact,
      carried_to,payload
    )
    values(
      uid,v_movement_id,'expense',null,coalesce(v_description,'Compra con tarjeta'),round(v_amount,2),
      (v_billing_month||'-01')::date,v_date,v_billing_month,
      v_category_id,v_category_name,false,false,0,null,null,null,
      v_currency,'card',v_card_id,null,null,null,'normal',
      null,null,null,null,'card_activity',
      '[]'::jsonb,coalesce(p_input->'payload','{}'::jsonb)
    )
    on conflict(user_id,id) do update
    set description=excluded.description,
        amount=excluded.amount,
        date=excluded.date,
        purchase_date=excluded.purchase_date,
        billing_month=excluded.billing_month,
        category_id=excluded.category_id,
        category=excluded.category,
        currency=excluded.currency,
        payment_method=excluded.payment_method,
        card_id=excluded.card_id,
        origin=excluded.origin,
        budget_impact=excluded.budget_impact,
        payload=excluded.payload,
        updated_at=now();

    return jsonb_build_object(
      'kind','card_single',
      'movement_id',v_movement_id,
      'amount',round(v_amount,2),
      'currency',v_currency,
      'purchase_date',v_date,
      'billing_month',v_billing_month
    );
  end if;

  -- Compra en cuotas.
  v_plan_id := gen_random_uuid();
  v_installment_amount := round(v_amount / v_installments,2);

  -- Si estamos reemplazando una compra simple, se elimina primero.
  if nullif(p_input->>'movement_id','') is not null then
    delete from public.movements
     where user_id=uid
       and id=v_movement_id;
  end if;

  insert into public.installment_plans(
    user_id,id,card_id,label,count,amount,total_purchase_amount,input_mode,
    purchase_date,start_month,payload
  )
  values(
    uid,v_plan_id,v_card_id,coalesce(v_description,'Compra en cuotas'),
    v_installments,v_installment_amount,round(v_amount,2),'total',
    v_date,v_billing_month,coalesce(p_input->'payload','{}'::jsonb)
  );

  for v_index in 1..v_installments loop
    v_generated_id := gen_random_uuid();

    insert into public.movements(
      user_id,id,type,operation_type,description,amount,date,purchase_date,billing_month,
      category_id,category,paid,complete,paid_amount,account_id,destination_account_id,destination_amount,
      currency,payment_method,card_id,applied_amount,applied_currency,effective_rate,origin,
      source_recurring_id,installment_plan_id,installment_number,installment_count,budget_impact,
      carried_to,payload
    )
    values(
      uid,v_generated_id,'expense',null,
      coalesce(v_description,'Compra en cuotas')||' · cuota '||v_index||'/'||v_installments,
      v_installment_amount,
      (to_char(date_trunc('month',to_date(v_billing_month||'-01','YYYY-MM-DD')) + ((v_index-1)||' month')::interval,'YYYY-MM')||'-01')::date,
      v_date,
      to_char(date_trunc('month',to_date(v_billing_month||'-01','YYYY-MM-DD')) + ((v_index-1)||' month')::interval,'YYYY-MM'),
      v_category_id,v_category_name,false,false,0,null,null,null,
      v_currency,'card',v_card_id,null,null,null,'installment',
      null,v_plan_id,v_index,v_installments,'card_activity',
      '[]'::jsonb,coalesce(p_input->'payload','{}'::jsonb)
    );
  end loop;

  return jsonb_build_object(
    'kind','card_installments',
    'plan_id',v_plan_id,
    'installments',v_installments,
    'installment_amount',v_installment_amount,
    'total_purchase_amount',round(v_amount,2),
    'currency',v_currency,
    'purchase_date',v_date,
    'billing_month',v_billing_month
  );
end;
$$;

revoke all on function public.panorama_save_movement(jsonb) from public;
grant execute on function public.panorama_save_movement(jsonb) to authenticated;
