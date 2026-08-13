-- Panorama Pre-Cloud 0.1
-- Esquema objetivo para Supabase/PostgreSQL.
-- Todas las tablas funcionales pertenecen a auth.users mediante user_id y RLS.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('income','expense')),
  name text not null,
  icon text,
  color text,
  primary key (user_id, id)
);

create table if not exists public.accounts (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  bank text,
  currency text not null default 'UYU',
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.credit_cards (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  bank text,
  currency text not null default 'UYU',
  interest_rate numeric(12,4) not null default 0,
  closing_day smallint check (closing_day between 1 and 31),
  due_day smallint check (due_day between 1 and 31),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.recurring_expenses (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  description text not null,
  amount numeric(16,2) not null default 0,
  category_id text,
  category text,
  payment_method text,
  card_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  foreign key (user_id, card_id) references public.credit_cards(user_id, id) on delete set null
);

create table if not exists public.installment_plans (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  card_id uuid not null,
  label text not null,
  count integer not null check (count > 0),
  amount numeric(16,2) not null check (amount >= 0),
  purchase_date date,
  start_month text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  foreign key (user_id, card_id) references public.credit_cards(user_id, id) on delete cascade
);

create table if not exists public.card_months (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  card_id uuid not null,
  month text not null,
  previous_balance numeric(16,2) not null default 0,
  paid_amount numeric(16,2) not null default 0,
  single_purchases numeric(16,2) not null default 0,
  interest_adjustment numeric(16,2) not null default 0,
  actual_interest numeric(16,2) not null default 0,
  tax_amount numeric(16,2) not null default 0,
  insurance_amount numeric(16,2) not null default 0,
  other_charges numeric(16,2) not null default 0,
  reconciled boolean not null default false,
  statement_confirmed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  unique (user_id, card_id, month),
  foreign key (user_id, card_id) references public.credit_cards(user_id, id) on delete cascade
);

create table if not exists public.movements (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('income','expense')),
  operation_type text,
  description text not null,
  amount numeric(16,2) not null default 0,
  date date not null,
  purchase_date date,
  billing_month text,
  category_id text,
  category text,
  paid boolean not null default false,
  complete boolean not null default false,
  paid_amount numeric(16,2) not null default 0,
  account_id uuid,
  destination_account_id uuid,
  destination_amount numeric(16,2),
  currency text not null default 'UYU',
  payment_method text,
  card_id uuid,
  applied_amount numeric(16,2),
  applied_currency text,
  effective_rate numeric(16,6),
  origin text,
  source_recurring_id uuid,
  installment_plan_id uuid,
  installment_number integer,
  installment_count integer,
  budget_impact text,
  carried_to jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  foreign key (user_id, account_id) references public.accounts(user_id, id) on delete set null,
  foreign key (user_id, destination_account_id) references public.accounts(user_id, id) on delete set null,
  foreign key (user_id, card_id) references public.credit_cards(user_id, id) on delete set null,
  foreign key (user_id, source_recurring_id) references public.recurring_expenses(user_id, id) on delete set null,
  foreign key (user_id, installment_plan_id) references public.installment_plans(user_id, id) on delete set null
);

create table if not exists public.card_purchases (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table if not exists public.app_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  theme text,
  default_month text,
  preferences jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- RLS: cada usuario solo ve y modifica sus filas.
do $$
declare t text;
begin
  foreach t in array array['profiles','categories','accounts','credit_cards','recurring_expenses','installment_plans','card_months','movements','card_purchases','app_preferences']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_own_rows', t);
    execute format('create policy %I on public.%I for all using (auth.uid() = user_id) with check (auth.uid() = user_id)', t || '_own_rows', t);
  end loop;
end $$;

-- Índices de acceso más frecuentes.
create index if not exists movements_user_date_idx on public.movements(user_id, date);
create index if not exists movements_user_billing_idx on public.movements(user_id, billing_month);
create index if not exists movements_user_card_idx on public.movements(user_id, card_id);
create index if not exists card_months_user_month_idx on public.card_months(user_id, month);
create index if not exists recurring_user_idx on public.recurring_expenses(user_id);
