-- Panorama Cloud 0.4.6 — Presupuesto + Transferencias
-- Ejecutar UNA vez en Supabase SQL Editor antes de usar la 0.4.6.
-- 1) Agrega guardado/eliminación atómica del doble asiento de transferencias.
-- 2) Migra transferencias antiguas de una sola fila a salida + entrada.
-- No agrega columnas nuevas.

begin;

create or replace function public.panorama_save_transfer(p_out jsonb, p_in jsonb)
returns void
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
  v_transfer_id text := coalesce(p_out->'payload'->>'transferId', p_in->'payload'->>'transferId');
  v_out_id uuid := (p_out->>'id')::uuid;
  v_in_id uuid := (p_in->>'id')::uuid;
begin
  if v_uid is null then
    raise exception 'Usuario no autenticado';
  end if;

  if nullif(v_transfer_id,'') is null then
    raise exception 'La transferencia no tiene identificador vinculado';
  end if;

  if coalesce(p_out->>'type','') <> 'expense'
     or coalesce(p_in->>'type','') <> 'income'
     or coalesce(p_out->>'operation_type','') <> 'transfer'
     or coalesce(p_in->>'operation_type','') <> 'transfer' then
    raise exception 'Los asientos de transferencia no son válidos';
  end if;

  insert into public.movements(
    id,user_id,type,operation_type,description,amount,date,purchase_date,billing_month,
    category_id,category,paid,complete,paid_amount,account_id,destination_account_id,
    destination_amount,currency,payment_method,card_id,applied_amount,applied_currency,
    effective_rate,origin,source_recurring_id,installment_plan_id,installment_number,
    installment_count,budget_impact,carried_to,payload
  )
  select
    (j->>'id')::uuid,
    v_uid,
    j->>'type',
    nullif(j->>'operation_type',''),
    coalesce(nullif(j->>'description',''),'Transferencia'),
    coalesce((j->>'amount')::numeric,0),
    (j->>'date')::date,
    nullif(j->>'purchase_date','')::date,
    nullif(j->>'billing_month',''),
    nullif(j->>'category_id',''),
    nullif(j->>'category',''),
    coalesce((j->>'paid')::boolean,false),
    coalesce((j->>'complete')::boolean,false),
    coalesce((j->>'paid_amount')::numeric,0),
    nullif(j->>'account_id','')::uuid,
    nullif(j->>'destination_account_id','')::uuid,
    nullif(j->>'destination_amount','')::numeric,
    coalesce(nullif(j->>'currency',''),'UYU'),
    nullif(j->>'payment_method',''),
    nullif(j->>'card_id','')::uuid,
    nullif(j->>'applied_amount','')::numeric,
    nullif(j->>'applied_currency',''),
    nullif(j->>'effective_rate','')::numeric,
    nullif(j->>'origin',''),
    nullif(j->>'source_recurring_id','')::uuid,
    nullif(j->>'installment_plan_id','')::uuid,
    nullif(j->>'installment_number','')::integer,
    nullif(j->>'installment_count','')::integer,
    coalesce(nullif(j->>'budget_impact',''),'internal_transfer'),
    coalesce(j->'carried_to','[]'::jsonb),
    coalesce(j->'payload','{}'::jsonb)
  from jsonb_array_elements(jsonb_build_array(p_out,p_in)) as x(j)
  on conflict(user_id,id) do update set
    type=excluded.type,
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

  -- Si una edición dejó una fila vieja del mismo par, la retiramos dentro
  -- de la misma transacción.
  delete from public.movements m
   where m.user_id=v_uid
     and m.operation_type='transfer'
     and m.payload->>'transferId'=v_transfer_id
     and m.id not in (v_out_id,v_in_id);
end;
$$;

revoke all on function public.panorama_save_transfer(jsonb,jsonb) from public;
grant execute on function public.panorama_save_transfer(jsonb,jsonb) to authenticated;

create or replace function public.panorama_delete_transfer(p_transfer_id text)
returns void
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Usuario no autenticado';
  end if;
  delete from public.movements m
   where m.user_id=v_uid
     and m.operation_type='transfer'
     and m.payload->>'transferId'=p_transfer_id;
end;
$$;

revoke all on function public.panorama_delete_transfer(text) from public;
grant execute on function public.panorama_delete_transfer(text) to authenticated;

-- Migración idempotente de transferencias heredadas (una única fila).
do $$
declare
  r record;
  v_pair uuid;
  v_in_id uuid;
  v_source_name text;
  v_dest_currency text;
  v_dest_amount numeric;
begin
  for r in
    select m.*
      from public.movements m
     where m.operation_type='transfer'
       and coalesce(m.payload->>'transferRole','')=''
       and m.account_id is not null
       and m.destination_account_id is not null
  loop
    v_pair := gen_random_uuid();
    v_in_id := gen_random_uuid();

    select a.name into v_source_name
      from public.accounts a
     where a.user_id=r.user_id and a.id=r.account_id;

    select a.currency into v_dest_currency
      from public.accounts a
     where a.user_id=r.user_id and a.id=r.destination_account_id;

    v_dest_amount := coalesce(r.destination_amount,r.amount);

    update public.movements
       set payment_method=coalesce(payment_method,'transfer'),
           budget_impact='internal_transfer',
           payload=coalesce(payload,'{}'::jsonb) || jsonb_build_object(
             'transferId',v_pair::text,
             'transferRole','out',
             'transferSourceAccountId',r.account_id::text,
             'transferDestinationAccountId',r.destination_account_id::text,
             'budgetImpact','internal_transfer',
             'paymentMethod','transfer'
           ),
           updated_at=now()
     where user_id=r.user_id and id=r.id;

    insert into public.movements(
      id,user_id,type,operation_type,description,amount,date,category_id,category,
      paid,complete,paid_amount,account_id,currency,payment_method,effective_rate,
      budget_impact,carried_to,payload
    )
    values(
      v_in_id,r.user_id,'income','transfer',
      'Transferencia desde '||coalesce(v_source_name,'cuenta origen'),
      v_dest_amount,r.date,null,'Transferencia',
      true,true,v_dest_amount,r.destination_account_id,coalesce(v_dest_currency,r.currency),
      'transfer',r.effective_rate,'internal_transfer','[]'::jsonb,
      jsonb_build_object(
        'id',v_in_id::text,
        'type','income',
        'operationType','transfer',
        'description','Transferencia desde '||coalesce(v_source_name,'cuenta origen'),
        'amount',v_dest_amount,
        'date',r.date::text,
        'categoryId','',
        'category','Transferencia',
        'paid',true,
        'complete',true,
        'paidAmount',v_dest_amount,
        'accountId',r.destination_account_id::text,
        'currency',coalesce(v_dest_currency,r.currency),
        'paymentMethod','transfer',
        'effectiveRate',r.effective_rate,
        'budgetImpact','internal_transfer',
        'transferId',v_pair::text,
        'transferRole','in',
        'transferSourceAccountId',r.account_id::text,
        'transferDestinationAccountId',r.destination_account_id::text,
        'carriedTo','[]'::jsonb
      )
    )
    on conflict(user_id,id) do nothing;
  end loop;
end;
$$;

commit;
