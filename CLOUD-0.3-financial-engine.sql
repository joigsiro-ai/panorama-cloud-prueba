-- Panorama Cloud 0.3 — Motor financiero Cloud
alter table public.movements add column if not exists payload jsonb not null default '{}'::jsonb;
alter table public.recurring_expenses add column if not exists payload jsonb not null default '{}'::jsonb;
alter table public.installment_plans add column if not exists payload jsonb not null default '{}'::jsonb;
alter table public.card_months add column if not exists payload jsonb not null default '{}'::jsonb;
alter table public.movements enable row level security;
alter table public.recurring_expenses enable row level security;
alter table public.installment_plans enable row level security;
alter table public.card_months enable row level security;
alter table public.card_purchases enable row level security;
create index if not exists installment_user_card_idx on public.installment_plans(user_id,card_id);
