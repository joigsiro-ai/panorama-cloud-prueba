-- Panorama Cloud 0.4.4 — Cloud Efficiency
-- Ejecutar UNA vez en Supabase SQL Editor antes de usar la 0.4.4.
-- Consolida las 9 lecturas iniciales en una sola llamada Data API / PostgREST.

begin;

create or replace function public.panorama_load_snapshot()
returns jsonb
language sql
stable
security invoker
set search_path=public
as $$
  select jsonb_build_object(
    'categories', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.sort_order, t.created_at)
      from public.categories t where t.user_id=auth.uid()
    ), '[]'::jsonb),
    'accounts', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.sort_order, t.created_at)
      from public.accounts t where t.user_id=auth.uid()
    ), '[]'::jsonb),
    'credit_cards', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.sort_order, t.created_at)
      from public.credit_cards t where t.user_id=auth.uid()
    ), '[]'::jsonb),
    'app_preferences', (
      select to_jsonb(t) from public.app_preferences t where t.user_id=auth.uid() limit 1
    ),
    'movements', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.date, t.created_at)
      from public.movements t where t.user_id=auth.uid()
    ), '[]'::jsonb),
    'recurring_expenses', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.created_at)
      from public.recurring_expenses t where t.user_id=auth.uid()
    ), '[]'::jsonb),
    'installment_plans', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.created_at)
      from public.installment_plans t where t.user_id=auth.uid()
    ), '[]'::jsonb),
    'card_months', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.month)
      from public.card_months t where t.user_id=auth.uid()
    ), '[]'::jsonb),
    'card_purchases', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.created_at)
      from public.card_purchases t where t.user_id=auth.uid()
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.panorama_load_snapshot() from public;
grant execute on function public.panorama_load_snapshot() to authenticated;

commit;
