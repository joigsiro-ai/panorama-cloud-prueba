
-- Panorama Cloud 0.4.3 — Auditoría de integridad transaccional
-- Requiere haber aplicado CLOUD-0.4-supabase-only.sql.
-- Todas las operaciones compuestas pasan a PostgreSQL para ser atómicas.

begin;

-- ---------------------------------------------------------------------------
-- 1. card_purchases deja de depender únicamente de un JSON opaco
-- ---------------------------------------------------------------------------
alter table public.card_purchases
  add column if not exists card_id uuid;

update public.card_purchases
set card_id=(payload->>'cardId')::uuid
where card_id is null
  and coalesce(payload->>'cardId','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

alter table public.card_purchases
  drop constraint if exists card_purchases_user_id_card_id_fkey;
alter table public.card_purchases
  add constraint card_purchases_user_id_card_id_fkey
  foreign key (user_id,card_id)
  references public.credit_cards(user_id,id)
  on delete cascade;

create index if not exists card_purchases_user_card_idx
  on public.card_purchases(user_id,card_id);

create or replace function public.panorama_fill_card_purchase_card_id()
returns trigger
language plpgsql
as $$
begin
  if new.card_id is null
     and coalesce(new.payload->>'cardId','') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  then
    new.card_id=(new.payload->>'cardId')::uuid;
  end if;
  return new;
end;
$$;

drop trigger if exists panorama_fill_card_purchase_card_id on public.card_purchases;
create trigger panorama_fill_card_purchase_card_id
before insert or update on public.card_purchases
for each row execute function public.panorama_fill_card_purchase_card_id();

-- ---------------------------------------------------------------------------
-- 2. Conciliación: card_month + tasa de tarjeta en una única transacción
-- ---------------------------------------------------------------------------
create or replace function public.panorama_reconcile_card(
  p_card_id uuid,
  p_month text,
  p_values jsonb,
  p_interest_rate numeric default null
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  uid uuid:=auth.uid();
  result_id uuid;
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;
  if p_month !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then raise exception 'Mes inválido'; end if;
  if not exists(select 1 from public.credit_cards where user_id=uid and id=p_card_id) then
    raise exception 'La tarjeta no pertenece al usuario';
  end if;

  insert into public.card_months(
    user_id,id,card_id,month,previous_balance,paid_amount,single_purchases,
    interest_adjustment,actual_interest,tax_amount,insurance_amount,other_charges,
    reconciled,statement_confirmed,payload
  )
  values(
    uid,gen_random_uuid(),p_card_id,p_month,
    coalesce((p_values->>'previous_balance')::numeric,0),
    coalesce((p_values->>'paid_amount')::numeric,0),
    coalesce((p_values->>'single_purchases')::numeric,0),
    coalesce((p_values->>'interest_adjustment')::numeric,0),
    coalesce((p_values->>'actual_interest')::numeric,0),
    coalesce((p_values->>'tax_amount')::numeric,0),
    coalesce((p_values->>'insurance_amount')::numeric,0),
    coalesce((p_values->>'other_charges')::numeric,0),
    coalesce((p_values->>'reconciled')::boolean,true),
    coalesce((p_values->>'statement_confirmed')::boolean,true),
    jsonb_build_object(
      'cardId',p_card_id,'month',p_month,
      'previousBalance',coalesce((p_values->>'previous_balance')::numeric,0),
      'paidAmount',coalesce((p_values->>'paid_amount')::numeric,0),
      'singlePurchases',coalesce((p_values->>'single_purchases')::numeric,0),
      'interestAdjustment',coalesce((p_values->>'interest_adjustment')::numeric,0),
      'actualInterest',coalesce((p_values->>'actual_interest')::numeric,0),
      'taxAmount',coalesce((p_values->>'tax_amount')::numeric,0),
      'insuranceAmount',coalesce((p_values->>'insurance_amount')::numeric,0),
      'otherCharges',coalesce((p_values->>'other_charges')::numeric,0),
      'reconciled',coalesce((p_values->>'reconciled')::boolean,true),
      'statementConfirmed',coalesce((p_values->>'statement_confirmed')::boolean,true)
    )
  )
  on conflict(user_id,card_id,month) do update
  set previous_balance=excluded.previous_balance,
      actual_interest=excluded.actual_interest,
      tax_amount=excluded.tax_amount,
      insurance_amount=excluded.insurance_amount,
      other_charges=excluded.other_charges,
      reconciled=excluded.reconciled,
      statement_confirmed=excluded.statement_confirmed,
      payload=excluded.payload,
      updated_at=now()
  returning id into result_id;

  if p_interest_rate is not null then
    update public.credit_cards
       set interest_rate=p_interest_rate
     where user_id=uid and id=p_card_id;
  end if;

  return result_id;
end;
$$;

grant execute on function public.panorama_reconcile_card(uuid,text,jsonb,numeric) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Compra en cuotas: plan + movimientos generados, atómicos
-- ---------------------------------------------------------------------------
create or replace function public.panorama_save_installment_bundle(
  p_plan jsonb,
  p_movements jsonb,
  p_replace_movement_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  uid uuid:=auth.uid();
  plan_id uuid:=(p_plan->>'id')::uuid;
  card_id_value uuid:=(p_plan->>'card_id')::uuid;
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;
  if jsonb_typeof(p_movements)<>'array' then raise exception 'Las cuotas no tienen un formato válido'; end if;
  if not exists(select 1 from public.credit_cards where user_id=uid and id=card_id_value) then
    raise exception 'La tarjeta del plan no pertenece al usuario';
  end if;

  insert into public.installment_plans(
    user_id,id,card_id,label,count,amount,total_purchase_amount,input_mode,
    purchase_date,start_month,payload
  )
  values(
    uid,plan_id,card_id_value,p_plan->>'label',
    (p_plan->>'count')::integer,(p_plan->>'amount')::numeric,
    nullif(p_plan->>'total_purchase_amount','')::numeric,
    coalesce(nullif(p_plan->>'input_mode',''),'per_installment'),
    nullif(p_plan->>'purchase_date','')::date,p_plan->>'start_month',
    coalesce(p_plan->'payload','{}'::jsonb)
  )
  on conflict(user_id,id) do update
  set card_id=excluded.card_id,label=excluded.label,count=excluded.count,amount=excluded.amount,
      total_purchase_amount=excluded.total_purchase_amount,input_mode=excluded.input_mode,
      purchase_date=excluded.purchase_date,start_month=excluded.start_month,
      payload=excluded.payload,updated_at=now();

  if p_replace_movement_id is not null then
    delete from public.movements
     where user_id=uid and id=p_replace_movement_id;
  end if;

  delete from public.movements
   where user_id=uid and installment_plan_id=plan_id;

  insert into public.movements(
    user_id,id,type,operation_type,description,amount,date,purchase_date,billing_month,
    category_id,category,paid,complete,paid_amount,account_id,destination_account_id,destination_amount,
    currency,payment_method,card_id,applied_amount,applied_currency,effective_rate,origin,
    source_recurring_id,installment_plan_id,installment_number,installment_count,budget_impact,
    carried_to,payload
  )
  select uid,x.id,x.type,x.operation_type,x.description,x.amount,x.date,x.purchase_date,x.billing_month,
         x.category_id,x.category,coalesce(x.paid,false),coalesce(x.complete,false),coalesce(x.paid_amount,0),
         x.account_id,x.destination_account_id,x.destination_amount,coalesce(x.currency,'UYU'),
         x.payment_method,x.card_id,x.applied_amount,x.applied_currency,x.effective_rate,x.origin,
         x.source_recurring_id,plan_id,x.installment_number,x.installment_count,x.budget_impact,
         coalesce(x.carried_to,'[]'::jsonb),coalesce(x.payload,'{}'::jsonb)
  from jsonb_to_recordset(p_movements) as x(
    id uuid,type text,operation_type text,description text,amount numeric,date date,purchase_date date,billing_month text,
    category_id text,category text,paid boolean,complete boolean,paid_amount numeric,
    account_id uuid,destination_account_id uuid,destination_amount numeric,currency text,payment_method text,
    card_id uuid,applied_amount numeric,applied_currency text,effective_rate numeric,origin text,
    source_recurring_id uuid,installment_plan_id uuid,installment_number integer,installment_count integer,
    budget_impact text,carried_to jsonb,payload jsonb
  );

  if (select count(*) from public.movements where user_id=uid and installment_plan_id=plan_id)
     <> (p_plan->>'count')::integer then
    raise exception 'La cantidad de movimientos generados no coincide con el plan';
  end if;

  return plan_id;
end;
$$;

grant execute on function public.panorama_save_installment_bundle(jsonb,jsonb,uuid) to authenticated;

create or replace function public.panorama_delete_installment_plan(p_plan_id uuid)
returns void
language plpgsql
security invoker
set search_path=public
as $$
declare uid uuid:=auth.uid();
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;
  delete from public.installment_plans where user_id=uid and id=p_plan_id;
  if not found then raise exception 'No se encontró el plan de cuotas'; end if;
  -- movements vinculados se eliminan por ON DELETE CASCADE.
end;
$$;

grant execute on function public.panorama_delete_installment_plan(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Tarjeta: alta/edición con validación de moneda
-- ---------------------------------------------------------------------------
create or replace function public.panorama_save_card(p_card jsonb)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  uid uuid:=auth.uid();
  card_id_value uuid:=(p_card->>'id')::uuid;
  old_currency text;
  new_currency text:=coalesce(nullif(p_card->>'currency',''),'UYU');
  refs integer;
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;
  if nullif(trim(p_card->>'name'),'') is null then raise exception 'El nombre de la tarjeta es obligatorio'; end if;

  select currency into old_currency
    from public.credit_cards where user_id=uid and id=card_id_value;

  if old_currency is not null and old_currency<>new_currency then
    select
      (select count(*) from public.movements where user_id=uid and card_id=card_id_value)
      +(select count(*) from public.card_months where user_id=uid and card_id=card_id_value)
      +(select count(*) from public.installment_plans where user_id=uid and card_id=card_id_value)
      +(select count(*) from public.recurring_expenses where user_id=uid and card_id=card_id_value)
    into refs;
    if refs>0 then
      raise exception 'No se puede cambiar la moneda de una tarjeta que ya tiene actividad asociada';
    end if;
  end if;

  insert into public.credit_cards(
    user_id,id,name,bank,currency,interest_rate,closing_day,due_day
  )
  values(
    uid,card_id_value,trim(p_card->>'name'),nullif(trim(p_card->>'bank'),''),
    new_currency,coalesce((p_card->>'interest_rate')::numeric,0),
    (p_card->>'closing_day')::smallint,nullif(p_card->>'due_day','')::smallint
  )
  on conflict(user_id,id) do update
  set name=excluded.name,bank=excluded.bank,currency=excluded.currency,
      interest_rate=excluded.interest_rate,closing_day=excluded.closing_day,
      due_day=excluded.due_day,updated_at=now();

  return card_id_value;
end;
$$;

grant execute on function public.panorama_save_card(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Tarjeta: eliminación completa y consistente
-- ---------------------------------------------------------------------------
create or replace function public.panorama_delete_card(p_card_id uuid)
returns void
language plpgsql
security invoker
set search_path=public
as $$
declare uid uuid:=auth.uid();
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;
  if not exists(select 1 from public.credit_cards where user_id=uid and id=p_card_id) then
    raise exception 'No se encontró la tarjeta';
  end if;

  -- El comportamiento histórico de Panorama elimina la actividad de esa tarjeta.
  delete from public.movements where user_id=uid and card_id=p_card_id;

  update public.recurring_expenses
     set card_id=null,
         payload=(coalesce(payload,'{}'::jsonb) - 'cardId') || jsonb_build_object('cardId','')
   where user_id=uid and card_id=p_card_id;

  -- card_months, installment_plans y card_purchases caen por CASCADE.
  delete from public.credit_cards where user_id=uid and id=p_card_id;
end;
$$;

grant execute on function public.panorama_delete_card(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Categorías: edición y reasignación sin ventanas de inconsistencia
-- ---------------------------------------------------------------------------
create or replace function public.panorama_update_category(
  p_category_id text,p_name text,p_icon text,p_color text
)
returns void
language plpgsql
security invoker
set search_path=public
as $$
declare uid uuid:=auth.uid();
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;
  if nullif(trim(p_name),'') is null then raise exception 'El nombre de categoría es obligatorio'; end if;

  update public.categories
     set name=trim(p_name),icon=p_icon,color=p_color
   where user_id=uid and id=p_category_id;
  if not found then raise exception 'No se encontró la categoría'; end if;

  update public.movements
     set category=trim(p_name),
         payload=jsonb_set(coalesce(payload,'{}'::jsonb),'{category}',to_jsonb(trim(p_name)),true)
   where user_id=uid and category_id=p_category_id;

  update public.recurring_expenses
     set category=trim(p_name),
         payload=jsonb_set(coalesce(payload,'{}'::jsonb),'{category}',to_jsonb(trim(p_name)),true)
   where user_id=uid and category_id=p_category_id;
end;
$$;

grant execute on function public.panorama_update_category(text,text,text,text) to authenticated;

create or replace function public.panorama_delete_category(
  p_category_id text,p_target_category_id text default null
)
returns void
language plpgsql
security invoker
set search_path=public
as $$
declare
  uid uuid:=auth.uid();
  source_type text;
  target_type text;
  target_name text;
  refs integer;
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;
  select type into source_type from public.categories where user_id=uid and id=p_category_id;
  if source_type is null then raise exception 'No se encontró la categoría'; end if;

  select
    (select count(*) from public.movements where user_id=uid and category_id=p_category_id)
    +(select count(*) from public.recurring_expenses where user_id=uid and category_id=p_category_id)
  into refs;

  if refs>0 then
    if p_target_category_id is null then raise exception 'La categoría está en uso y requiere reasignación'; end if;
    select type,name into target_type,target_name
      from public.categories where user_id=uid and id=p_target_category_id;
    if target_type is null then raise exception 'No se encontró la categoría destino'; end if;
    if target_type<>source_type then raise exception 'La categoría destino debe ser del mismo tipo'; end if;

    update public.movements
       set category_id=p_target_category_id,category=target_name,
           payload=jsonb_set(
             jsonb_set(coalesce(payload,'{}'::jsonb),'{categoryId}',to_jsonb(p_target_category_id),true),
             '{category}',to_jsonb(target_name),true)
     where user_id=uid and category_id=p_category_id;

    update public.recurring_expenses
       set category_id=p_target_category_id,category=target_name,
           payload=jsonb_set(
             jsonb_set(coalesce(payload,'{}'::jsonb),'{categoryId}',to_jsonb(p_target_category_id),true),
             '{category}',to_jsonb(target_name),true)
     where user_id=uid and category_id=p_category_id;
  end if;

  delete from public.categories where user_id=uid and id=p_category_id;
end;
$$;

grant execute on function public.panorama_delete_category(text,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Recurrentes: desvincular historial + borrar definición, atómico
-- ---------------------------------------------------------------------------
create or replace function public.panorama_delete_recurring(p_recurring_id uuid)
returns void
language plpgsql
security invoker
set search_path=public
as $$
declare uid uuid:=auth.uid();
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;

  update public.movements
     set source_recurring_id=null,
         payload=(coalesce(payload,'{}'::jsonb)-'sourceRecurringId') || jsonb_build_object('sourceRecurringId','')
   where user_id=uid and source_recurring_id=p_recurring_id;

  delete from public.recurring_expenses where user_id=uid and id=p_recurring_id;
  if not found then raise exception 'No se encontró el recurrente'; end if;
end;
$$;

grant execute on function public.panorama_delete_recurring(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Cuentas: alta/edición y cambio de predeterminada, atómicos
-- ---------------------------------------------------------------------------
create or replace function public.panorama_save_account(p_account jsonb)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare
  uid uuid:=auth.uid();
  account_id uuid:=(p_account->>'id')::uuid;
  wants_default boolean:=coalesce((p_account->>'is_default')::boolean,false);
  current_count integer;
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;
  if nullif(trim(p_account->>'name'),'') is null then raise exception 'El nombre de la cuenta es obligatorio'; end if;

  if exists(
    select 1 from public.accounts a
    where a.user_id=uid and a.id=account_id
      and a.currency<>coalesce(nullif(p_account->>'currency',''),'UYU')
  ) and exists(
    select 1 from public.movements m
    where m.user_id=uid and (m.account_id=account_id or m.destination_account_id=account_id)
  ) then
    raise exception 'No se puede cambiar la moneda de una cuenta que ya tiene movimientos o transferencias';
  end if;

  if wants_default then
    update public.accounts set is_default=false where user_id=uid and is_default;
  end if;

  insert into public.accounts(user_id,id,name,bank,currency,is_default)
  values(uid,account_id,trim(p_account->>'name'),nullif(trim(p_account->>'bank'),''),
         coalesce(nullif(p_account->>'currency',''),'UYU'),wants_default)
  on conflict(user_id,id) do update
  set name=excluded.name,bank=excluded.bank,currency=excluded.currency,is_default=excluded.is_default,updated_at=now();

  select count(*) into current_count from public.accounts where user_id=uid and is_default;
  if current_count=0 then
    update public.accounts set is_default=true where user_id=uid and id=account_id;
  end if;

  return account_id;
end;
$$;

grant execute on function public.panorama_save_account(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Cuenta: no permitir borrado si participa en movimientos/transferencias;
--    si era predeterminada, promover otra en la misma transacción.
-- ---------------------------------------------------------------------------
create or replace function public.panorama_delete_account(p_account_id uuid)
returns void
language plpgsql
security invoker
set search_path=public
as $$
declare
  uid uuid:=auth.uid();
  was_default boolean;
  refs integer;
  replacement uuid;
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;

  select is_default into was_default
    from public.accounts where user_id=uid and id=p_account_id;
  if was_default is null then raise exception 'No se encontró la cuenta'; end if;

  select count(*) into refs
    from public.movements
   where user_id=uid and (account_id=p_account_id or destination_account_id=p_account_id);
  if refs>0 then raise exception 'La cuenta está utilizada por movimientos o transferencias y no puede eliminarse'; end if;

  if (select count(*) from public.accounts where user_id=uid)<=1 then
    raise exception 'Panorama necesita al menos una cuenta';
  end if;

  -- Primero borrar la predeterminada para no chocar con el índice único parcial.
  delete from public.accounts where user_id=uid and id=p_account_id;

  if was_default then
    select id into replacement
      from public.accounts where user_id=uid
      order by sort_order,created_at,id limit 1;
    update public.accounts set is_default=true where user_id=uid and id=replacement;
  end if;
end;
$$;

grant execute on function public.panorama_delete_account(uuid) to authenticated;

commit;
