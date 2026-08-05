-- PANORAMA CLOUD · PRUEBA 1.1
-- Ejecuta TODO este contenido en:
-- Supabase > SQL Editor > New query > Run

create table if not exists public.user_phrases (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phrase text not null check (char_length(phrase) between 1 and 250),
  updated_at timestamptz not null default now()
);

alter table public.user_phrases enable row level security;

drop policy if exists "Leer frase propia" on public.user_phrases;
create policy "Leer frase propia"
on public.user_phrases
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Crear frase propia" on public.user_phrases;
create policy "Crear frase propia"
on public.user_phrases
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Modificar frase propia" on public.user_phrases;
create policy "Modificar frase propia"
on public.user_phrases
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Eliminar frase propia" on public.user_phrases;
create policy "Eliminar frase propia"
on public.user_phrases
for delete
to authenticated
using ((select auth.uid()) = user_id);
