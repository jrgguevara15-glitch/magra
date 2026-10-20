-- MAGRA · M11 — menú semanal y lista de compras.
-- Una fila por semana (lunes) con las comidas de los 7 días tal como las
-- armó la IA dentro de las metas del plan (slots), y los artículos de la
-- lista de compras ya marcados. Cada usuario ve y modifica solo lo suyo.
-- También permite registrar en el día lo que se comió del menú.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.menus (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  week_start  date not null check (extract(isodow from week_start) = 1),
  slots       jsonb not null check (jsonb_typeof(slots) = 'array'),
  days        jsonb not null check (jsonb_typeof(days) = 'array'
                                    and jsonb_array_length(days) = 7),
  checked     jsonb not null default '[]'::jsonb
                check (jsonb_typeof(checked) = 'array'),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, week_start)
);

alter table public.menus enable row level security;

drop policy if exists "menus: ver los propios" on public.menus;
create policy "menus: ver los propios" on public.menus
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "menus: crear los propios" on public.menus;
create policy "menus: crear los propios" on public.menus
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "menus: editar los propios" on public.menus;
create policy "menus: editar los propios" on public.menus
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "menus: borrar los propios" on public.menus;
create policy "menus: borrar los propios" on public.menus
  for delete to authenticated using ((select auth.uid()) = user_id);

-- "Lo comí" registra los alimentos del menú con origen 'menu'.
alter table public.food_entries drop constraint if exists food_entries_source_check;
alter table public.food_entries add constraint food_entries_source_check
  check (source in ('catalog', 'manual', 'photo', 'barcode', 'voice', 'menu'));
