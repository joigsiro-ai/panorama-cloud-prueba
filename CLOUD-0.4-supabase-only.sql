
-- Panorama Cloud 0.4 — Supabase como única fuente de verdad
-- Ejecutar UNA VEZ sobre la base existente antes de levantar Panorama Cloud 0.4.
-- No elimina datos existentes. Refuerza integridad, agrega metadatos estructurados
-- y crea exportación/restauración transaccional en el servidor.

begin;

-- ---------------------------------------------------------------------------
-- 1. Columnas de auditoría / estructura faltantes
-- ---------------------------------------------------------------------------
alter table public.categories add column if not exists sort_order integer not null default 0;
alter table public.accounts add column if not exists sort_order integer not null default 0;
alter table public.credit_cards add column if not exists sort_order integer not null default 0;

alter table public.categories
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.card_purchases
  add column if not exists updated_at timestamptz not null default now();

alter table public.app_preferences
  add column if not exists created_at timestamptz not null default now();

alter table public.movements
  add column if not exists payload jsonb not null default '{}'::jsonb;

alter table public.recurring_expenses
  add column if not exists payload jsonb not null default '{}'::jsonb;

alter table public.installment_plans
  add column if not exists payload jsonb not null default '{}'::jsonb,
  add column if not exists total_purchase_amount numeric(16,2),
  add column if not exists input_mode text;

alter table public.card_months
  add column if not exists payload jsonb not null default '{}'::jsonb;

update public.installment_plans
set total_purchase_amount = coalesce(total_purchase_amount, round(amount * count, 2)),
    input_mode = coalesce(nullif(input_mode,''), payload->>'inputMode', 'per_installment')
where total_purchase_amount is null or input_mode is null or input_mode = '';

-- ---------------------------------------------------------------------------
-- 2. Normalización previa a constraints
-- ---------------------------------------------------------------------------
update public.movements set category_id = null where category_id = '';
update public.recurring_expenses set category_id = null where category_id = '';

update public.movements m
set category_id = null
where category_id is not null
  and not exists (
    select 1 from public.categories c
    where c.user_id=m.user_id and c.id=m.category_id
  );

update public.recurring_expenses r
set category_id = null
where category_id is not null
  and not exists (
    select 1 from public.categories c
    where c.user_id=r.user_id and c.id=r.category_id
  );

-- Solo una cuenta predeterminada por usuario. Si por datos históricos hubiera más,
-- conservamos la primera por fecha/id.
with ranked as (
  select user_id,id,
         row_number() over(partition by user_id order by created_at,id) as rn
  from public.accounts
  where is_default
)
update public.accounts a
set is_default=false
from ranked r
where a.user_id=r.user_id and a.id=r.id and r.rn>1;

create unique index if not exists accounts_one_default_per_user
  on public.accounts(user_id) where is_default;

-- ---------------------------------------------------------------------------
-- 3. Checks de integridad de dominio
-- ---------------------------------------------------------------------------
alter table public.installment_plans
  drop constraint if exists installment_plans_input_mode_check;
alter table public.installment_plans
  add constraint installment_plans_input_mode_check
  check (input_mode in ('total','per_installment'));

alter table public.installment_plans
  drop constraint if exists installment_plans_total_purchase_amount_check;
alter table public.installment_plans
  add constraint installment_plans_total_purchase_amount_check
  check (total_purchase_amount is null or total_purchase_amount >= 0);

alter table public.movements
  drop constraint if exists movements_amount_nonnegative;
alter table public.movements
  add constraint movements_amount_nonnegative check (amount >= 0 and paid_amount >= 0);

alter table public.recurring_expenses
  drop constraint if exists recurring_amount_nonnegative;
alter table public.recurring_expenses
  add constraint recurring_amount_nonnegative check (amount >= 0);

alter table public.card_months
  drop constraint if exists card_months_month_format;
alter table public.card_months
  add constraint card_months_month_format check (month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$');

alter table public.installment_plans
  drop constraint if exists installment_plans_start_month_format;
alter table public.installment_plans
  add constraint installment_plans_start_month_format check (start_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$');

alter table public.movements
  drop constraint if exists movements_billing_month_format;
alter table public.movements
  add constraint movements_billing_month_format
  check (billing_month is null or billing_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$');

-- ---------------------------------------------------------------------------
-- 4. Integridad referencial explícita y semántica de borrado
-- ---------------------------------------------------------------------------

-- Categoría: si está en uso no se borra silenciosamente.
alter table public.movements drop constraint if exists movements_category_fk;
alter table public.movements
  add constraint movements_category_fk
  foreign key (user_id,category_id)
  references public.categories(user_id,id)
  on delete restrict;

alter table public.recurring_expenses drop constraint if exists recurring_category_fk;
alter table public.recurring_expenses
  add constraint recurring_category_fk
  foreign key (user_id,category_id)
  references public.categories(user_id,id)
  on delete restrict;

-- Cuentas: el movimiento histórico se conserva, solo pierde la asociación.
alter table public.movements drop constraint if exists movements_user_id_account_id_fkey;
alter table public.movements
  add constraint movements_user_id_account_id_fkey
  foreign key (user_id,account_id)
  references public.accounts(user_id,id)
  on delete restrict;

alter table public.movements drop constraint if exists movements_user_id_destination_account_id_fkey;
alter table public.movements
  add constraint movements_user_id_destination_account_id_fkey
  foreign key (user_id,destination_account_id)
  references public.accounts(user_id,id)
  on delete restrict;

-- Tarjetas: estados/cuotas dependen de la tarjeta; movimientos históricos se conservan.
alter table public.recurring_expenses drop constraint if exists recurring_expenses_user_id_card_id_fkey;
alter table public.recurring_expenses
  add constraint recurring_expenses_user_id_card_id_fkey
  foreign key (user_id,card_id)
  references public.credit_cards(user_id,id)
  on delete restrict;

alter table public.installment_plans drop constraint if exists installment_plans_user_id_card_id_fkey;
alter table public.installment_plans
  add constraint installment_plans_user_id_card_id_fkey
  foreign key (user_id,card_id)
  references public.credit_cards(user_id,id)
  on delete cascade;

alter table public.card_months drop constraint if exists card_months_user_id_card_id_fkey;
alter table public.card_months
  add constraint card_months_user_id_card_id_fkey
  foreign key (user_id,card_id)
  references public.credit_cards(user_id,id)
  on delete cascade;

alter table public.movements drop constraint if exists movements_user_id_card_id_fkey;
alter table public.movements
  add constraint movements_user_id_card_id_fkey
  foreign key (user_id,card_id)
  references public.credit_cards(user_id,id)
  on delete restrict;

-- Recurrentes: sus ocurrencias ya materializadas se conservan como historial.
alter table public.movements drop constraint if exists movements_user_id_source_recurring_id_fkey;
alter table public.movements
  add constraint movements_user_id_source_recurring_id_fkey
  foreign key (user_id,source_recurring_id)
  references public.recurring_expenses(user_id,id)
  on delete restrict;

-- Plan de cuotas: las cuotas generadas pertenecen al plan.
alter table public.movements drop constraint if exists movements_user_id_installment_plan_id_fkey;
alter table public.movements
  add constraint movements_user_id_installment_plan_id_fkey
  foreign key (user_id,installment_plan_id)
  references public.installment_plans(user_id,id)
  on delete cascade;

-- ---------------------------------------------------------------------------
-- 5. updated_at consistente
-- ---------------------------------------------------------------------------
create or replace function public.panorama_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at=now();
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'profiles','categories','accounts','credit_cards','recurring_expenses',
    'installment_plans','card_months','movements','card_purchases','app_preferences'
  ]
  loop
    execute format('drop trigger if exists panorama_set_updated_at on public.%I',t);
    execute format(
      'create trigger panorama_set_updated_at before update on public.%I for each row execute function public.panorama_set_updated_at()',
      t
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Índices
-- ---------------------------------------------------------------------------
create index if not exists movements_user_account_idx on public.movements(user_id,account_id);
create index if not exists movements_user_category_idx on public.movements(user_id,category_id);
create index if not exists movements_user_installment_idx on public.movements(user_id,installment_plan_id);
create index if not exists recurring_user_card_idx on public.recurring_expenses(user_id,card_id);
create index if not exists recurring_user_category_idx on public.recurring_expenses(user_id,category_id);
create index if not exists installment_user_card_idx on public.installment_plans(user_id,card_id);

-- ---------------------------------------------------------------------------
-- 7. RLS reafirmado
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','categories','accounts','credit_cards','recurring_expenses',
    'installment_plans','card_months','movements','card_purchases','app_preferences'
  ]
  loop
    execute format('alter table public.%I enable row level security',t);
    execute format('drop policy if exists %I on public.%I',t||'_own_rows',t);
    execute format(
      'create policy %I on public.%I for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id)',
      t||'_own_rows',t
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 8. Exportación: snapshot directamente desde Supabase
-- ---------------------------------------------------------------------------
create or replace function public.panorama_export_backup()
returns jsonb
language plpgsql
security invoker
set search_path=public
as $$
declare
  uid uuid := auth.uid();
  result jsonb;
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;

  select jsonb_build_object(
    'format','panorama-supabase-backup',
    'schema_version',2,
    'exported_at',now(),
    'profile',coalesce(
      (select jsonb_build_object('display_name',p.display_name) from public.profiles p where p.user_id=uid),
      '{}'::jsonb
    ),
    'tables',jsonb_build_object(
      'categories',coalesce((select jsonb_agg(to_jsonb(c)-'user_id' order by c.sort_order,c.created_at) from public.categories c where c.user_id=uid),'[]'::jsonb),
      'accounts',coalesce((select jsonb_agg(to_jsonb(a)-'user_id' order by a.sort_order,a.created_at) from public.accounts a where a.user_id=uid),'[]'::jsonb),
      'credit_cards',coalesce((select jsonb_agg(to_jsonb(c)-'user_id' order by c.sort_order,c.created_at) from public.credit_cards c where c.user_id=uid),'[]'::jsonb),
      'recurring_expenses',coalesce((select jsonb_agg(to_jsonb(r)-'user_id' order by r.created_at) from public.recurring_expenses r where r.user_id=uid),'[]'::jsonb),
      'installment_plans',coalesce((select jsonb_agg(to_jsonb(i)-'user_id' order by i.created_at) from public.installment_plans i where i.user_id=uid),'[]'::jsonb),
      'card_months',coalesce((select jsonb_agg(to_jsonb(cm)-'user_id' order by cm.month,cm.created_at) from public.card_months cm where cm.user_id=uid),'[]'::jsonb),
      'movements',coalesce((select jsonb_agg(to_jsonb(m)-'user_id' order by m.date,m.created_at) from public.movements m where m.user_id=uid),'[]'::jsonb),
      'card_purchases',coalesce((select jsonb_agg(to_jsonb(cp)-'user_id' order by cp.created_at) from public.card_purchases cp where cp.user_id=uid),'[]'::jsonb),
      'app_preferences',coalesce((select jsonb_agg(to_jsonb(ap)-'user_id') from public.app_preferences ap where ap.user_id=uid),'[]'::jsonb)
    )
  ) into result;

  return result;
end;
$$;

grant execute on function public.panorama_export_backup() to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Restauración: una sola transacción en PostgreSQL
-- ---------------------------------------------------------------------------
create or replace function public.panorama_restore_backup(p_backup jsonb)
returns jsonb
language plpgsql
security invoker
set search_path=public
as $$
declare
  uid uuid := auth.uid();
  t jsonb;
  profile_name text;
  n_movements integer;
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;
  if coalesce(p_backup->>'format','') <> 'panorama-supabase-backup' then
    raise exception 'Formato de respaldo no reconocido';
  end if;
  if coalesce((p_backup->>'schema_version')::integer,0) <> 2 then
    raise exception 'Versión de respaldo no compatible';
  end if;

  t := coalesce(p_backup->'tables','{}'::jsonb);
  if jsonb_typeof(t) <> 'object' then raise exception 'El respaldo no contiene tablas válidas'; end if;

  -- Borrado en orden de dependencia.
  delete from public.movements where user_id=uid;
  delete from public.card_purchases where user_id=uid;
  delete from public.card_months where user_id=uid;
  delete from public.installment_plans where user_id=uid;
  delete from public.recurring_expenses where user_id=uid;
  delete from public.credit_cards where user_id=uid;
  delete from public.accounts where user_id=uid;
  delete from public.categories where user_id=uid;
  delete from public.app_preferences where user_id=uid;

  insert into public.categories(user_id,id,type,name,icon,color,sort_order,created_at,updated_at)
  select uid,x.id,x.type,x.name,x.icon,x.color,coalesce(x.sort_order,0),
         coalesce(x.created_at,now()),coalesce(x.updated_at,now())
  from jsonb_to_recordset(coalesce(t->'categories','[]'::jsonb))
       as x(id text,type text,name text,icon text,color text,sort_order integer,created_at timestamptz,updated_at timestamptz);

  insert into public.accounts(user_id,id,name,bank,currency,is_default,sort_order,created_at,updated_at)
  select uid,x.id,x.name,x.bank,coalesce(x.currency,'UYU'),coalesce(x.is_default,false),coalesce(x.sort_order,0),
         coalesce(x.created_at,now()),coalesce(x.updated_at,now())
  from jsonb_to_recordset(coalesce(t->'accounts','[]'::jsonb))
       as x(id uuid,name text,bank text,currency text,is_default boolean,sort_order integer,created_at timestamptz,updated_at timestamptz);

  insert into public.credit_cards(user_id,id,name,bank,currency,interest_rate,closing_day,due_day,sort_order,created_at,updated_at)
  select uid,x.id,x.name,x.bank,coalesce(x.currency,'UYU'),coalesce(x.interest_rate,0),x.closing_day,x.due_day,coalesce(x.sort_order,0),
         coalesce(x.created_at,now()),coalesce(x.updated_at,now())
  from jsonb_to_recordset(coalesce(t->'credit_cards','[]'::jsonb))
       as x(id uuid,name text,bank text,currency text,interest_rate numeric,closing_day smallint,due_day smallint,sort_order integer,created_at timestamptz,updated_at timestamptz);

  insert into public.recurring_expenses(user_id,id,description,amount,category_id,category,payment_method,card_id,payload,created_at,updated_at)
  select uid,x.id,x.description,coalesce(x.amount,0),x.category_id,x.category,x.payment_method,x.card_id,
         coalesce(x.payload,'{}'::jsonb),coalesce(x.created_at,now()),coalesce(x.updated_at,now())
  from jsonb_to_recordset(coalesce(t->'recurring_expenses','[]'::jsonb))
       as x(id uuid,description text,amount numeric,category_id text,category text,payment_method text,card_id uuid,payload jsonb,created_at timestamptz,updated_at timestamptz);

  insert into public.installment_plans(user_id,id,card_id,label,count,amount,total_purchase_amount,input_mode,purchase_date,start_month,payload,created_at,updated_at)
  select uid,x.id,x.card_id,x.label,x.count,x.amount,x.total_purchase_amount,coalesce(x.input_mode,'per_installment'),
         x.purchase_date,x.start_month,coalesce(x.payload,'{}'::jsonb),coalesce(x.created_at,now()),coalesce(x.updated_at,now())
  from jsonb_to_recordset(coalesce(t->'installment_plans','[]'::jsonb))
       as x(id uuid,card_id uuid,label text,count integer,amount numeric,total_purchase_amount numeric,input_mode text,purchase_date date,start_month text,payload jsonb,created_at timestamptz,updated_at timestamptz);

  insert into public.card_months(user_id,id,card_id,month,previous_balance,paid_amount,single_purchases,interest_adjustment,actual_interest,tax_amount,insurance_amount,other_charges,reconciled,statement_confirmed,payload,created_at,updated_at)
  select uid,x.id,x.card_id,x.month,coalesce(x.previous_balance,0),coalesce(x.paid_amount,0),coalesce(x.single_purchases,0),
         coalesce(x.interest_adjustment,0),coalesce(x.actual_interest,0),coalesce(x.tax_amount,0),coalesce(x.insurance_amount,0),
         coalesce(x.other_charges,0),coalesce(x.reconciled,false),coalesce(x.statement_confirmed,false),
         coalesce(x.payload,'{}'::jsonb),coalesce(x.created_at,now()),coalesce(x.updated_at,now())
  from jsonb_to_recordset(coalesce(t->'card_months','[]'::jsonb))
       as x(id uuid,card_id uuid,month text,previous_balance numeric,paid_amount numeric,single_purchases numeric,interest_adjustment numeric,actual_interest numeric,tax_amount numeric,insurance_amount numeric,other_charges numeric,reconciled boolean,statement_confirmed boolean,payload jsonb,created_at timestamptz,updated_at timestamptz);

  insert into public.movements(
    user_id,id,type,operation_type,description,amount,date,purchase_date,billing_month,
    category_id,category,paid,complete,paid_amount,account_id,destination_account_id,destination_amount,
    currency,payment_method,card_id,applied_amount,applied_currency,effective_rate,origin,
    source_recurring_id,installment_plan_id,installment_number,installment_count,budget_impact,
    carried_to,payload,created_at,updated_at
  )
  select uid,x.id,x.type,x.operation_type,x.description,coalesce(x.amount,0),x.date,x.purchase_date,x.billing_month,
         x.category_id,x.category,coalesce(x.paid,false),coalesce(x.complete,false),coalesce(x.paid_amount,0),
         x.account_id,x.destination_account_id,x.destination_amount,coalesce(x.currency,'UYU'),x.payment_method,x.card_id,
         x.applied_amount,x.applied_currency,x.effective_rate,x.origin,x.source_recurring_id,x.installment_plan_id,
         x.installment_number,x.installment_count,x.budget_impact,coalesce(x.carried_to,'[]'::jsonb),
         coalesce(x.payload,'{}'::jsonb),coalesce(x.created_at,now()),coalesce(x.updated_at,now())
  from jsonb_to_recordset(coalesce(t->'movements','[]'::jsonb))
       as x(
         id uuid,type text,operation_type text,description text,amount numeric,date date,purchase_date date,billing_month text,
         category_id text,category text,paid boolean,complete boolean,paid_amount numeric,account_id uuid,destination_account_id uuid,destination_amount numeric,
         currency text,payment_method text,card_id uuid,applied_amount numeric,applied_currency text,effective_rate numeric,origin text,
         source_recurring_id uuid,installment_plan_id uuid,installment_number integer,installment_count integer,budget_impact text,
         carried_to jsonb,payload jsonb,created_at timestamptz,updated_at timestamptz
       );

  insert into public.card_purchases(user_id,id,payload,created_at,updated_at)
  select uid,x.id,coalesce(x.payload,'{}'::jsonb),coalesce(x.created_at,now()),coalesce(x.updated_at,now())
  from jsonb_to_recordset(coalesce(t->'card_purchases','[]'::jsonb))
       as x(id uuid,payload jsonb,created_at timestamptz,updated_at timestamptz);

  insert into public.app_preferences(user_id,theme,default_month,preferences,created_at,updated_at)
  select uid,x.theme,x.default_month,coalesce(x.preferences,'{}'::jsonb),coalesce(x.created_at,now()),coalesce(x.updated_at,now())
  from jsonb_to_recordset(coalesce(t->'app_preferences','[]'::jsonb))
       as x(theme text,default_month text,preferences jsonb,created_at timestamptz,updated_at timestamptz);

  profile_name := nullif(trim(p_backup->'profile'->>'display_name'),'');
  if profile_name is not null then
    update public.profiles set display_name=profile_name where user_id=uid;
  end if;

  select count(*) into n_movements from public.movements where user_id=uid;
  return jsonb_build_object(
    'ok',true,
    'categories',(select count(*) from public.categories where user_id=uid),
    'accounts',(select count(*) from public.accounts where user_id=uid),
    'credit_cards',(select count(*) from public.credit_cards where user_id=uid),
    'recurring_expenses',(select count(*) from public.recurring_expenses where user_id=uid),
    'installment_plans',(select count(*) from public.installment_plans where user_id=uid),
    'card_months',(select count(*) from public.card_months where user_id=uid),
    'movements',n_movements
  );
end;
$$;

grant execute on function public.panorama_restore_backup(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Reset transaccional
-- ---------------------------------------------------------------------------
create or replace function public.panorama_reset_data()
returns void
language plpgsql
security invoker
set search_path=public
as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'Usuario no autenticado'; end if;
  delete from public.movements where user_id=uid;
  delete from public.card_purchases where user_id=uid;
  delete from public.card_months where user_id=uid;
  delete from public.installment_plans where user_id=uid;
  delete from public.recurring_expenses where user_id=uid;
  delete from public.credit_cards where user_id=uid;
  delete from public.accounts where user_id=uid;
  delete from public.categories where user_id=uid;
  delete from public.app_preferences where user_id=uid;
end;
$$;

grant execute on function public.panorama_reset_data() to authenticated;

commit;
