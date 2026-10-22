-- MAGRA · U13 — distancia con GPS y pasos diarios.
-- exercise_entries.distance_km: kilómetros de una carrera, caminata o
-- bicicleta medidas con GPS (vacío en el resto de las actividades).
-- daily_steps: pasos de cada día (anotados por el usuario; en la app
-- instalada se llenarán desde el teléfono). Cada usuario ve y modifica solo
-- lo suyo.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

alter table public.exercise_entries
  add column if not exists distance_km numeric(6, 2)
    check (distance_km is null or distance_km between 0 and 500);

create table if not exists public.daily_steps (
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  day         date not null,
  steps       integer not null check (steps between 0 and 150000),
  updated_at  timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.daily_steps enable row level security;

drop policy if exists "daily_steps: ver los propios" on public.daily_steps;
create policy "daily_steps: ver los propios" on public.daily_steps
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "daily_steps: crear los propios" on public.daily_steps;
create policy "daily_steps: crear los propios" on public.daily_steps
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "daily_steps: editar los propios" on public.daily_steps;
create policy "daily_steps: editar los propios" on public.daily_steps
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "daily_steps: borrar los propios" on public.daily_steps;
create policy "daily_steps: borrar los propios" on public.daily_steps
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Que la API vea la tabla nueva de inmediato.
notify pgrst, 'reload schema';
