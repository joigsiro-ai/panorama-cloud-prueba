-- Panorama Cloud 0.2.1 - Configuración Cloud
-- Ejecutar una sola vez sobre el esquema 0.2.0 ya creado.

alter table public.categories add column if not exists sort_order integer not null default 0;
alter table public.accounts add column if not exists sort_order integer not null default 0;
alter table public.credit_cards add column if not exists sort_order integer not null default 0;

-- Mantiene la corrección aplicada a profiles para futuros usuarios.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id, display_name)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      split_part(new.email, '@', 1)
    )
  )
  on conflict (user_id) do update
    set display_name = excluded.display_name,
        updated_at = now();
  return new;
end;
$$;
