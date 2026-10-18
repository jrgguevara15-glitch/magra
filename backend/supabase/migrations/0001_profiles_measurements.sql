-- MAGRA · M2 — perfiles y mediciones.
-- Cada usuario ve y modifica solo sus filas (Row Level Security).
-- Ejecutar en Supabase → SQL Editor → New query → Run.

-- ---------------------------------------------------------------
-- Perfil: datos para las fórmulas (docs/02_FORMULAS.md)
-- ---------------------------------------------------------------
create table if not exists public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  name             text not null default '',
  sex              text not null check (sex in ('male', 'female')),
  birth_date       date not null,
  height_cm        numeric(5, 1) not null check (height_cm between 120 and 230),
  activity_factor  numeric(4, 3) not null default 1.2
                     check (activity_factor between 1.1 and 2.0),
  pace_kg_week     numeric(3, 2) not null default 0.5
                     check (pace_kg_week between 0 and 1),
  goal_fat_pct     numeric(4, 1) not null default 17
                     check (goal_fat_pct between 5 and 45),
  protein_pct      numeric(4, 1) not null default 30,
  carb_pct         numeric(4, 1) not null default 45,
  lipid_pct        numeric(4, 1) not null default 25,
  low_carb_days    smallint[] not null default '{2,4}',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint macros_sum_100
    check (abs(protein_pct + carb_pct + lipid_pct - 100) < 0.5)
);

alter table public.profiles enable row level security;

drop policy if exists "profiles: ver el propio" on public.profiles;
create policy "profiles: ver el propio" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);

drop policy if exists "profiles: crear el propio" on public.profiles;
create policy "profiles: crear el propio" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);

drop policy if exists "profiles: editar el propio" on public.profiles;
create policy "profiles: editar el propio" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- ---------------------------------------------------------------
-- Mediciones: peso y, opcionalmente, perímetros
-- ---------------------------------------------------------------
create table if not exists public.measurements (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null default auth.uid()
                      references auth.users (id) on delete cascade,
  measured_on       date not null,
  weight_kg         numeric(5, 2) not null check (weight_kg between 30 and 300),
  neck_cm           numeric(4, 1) check (neck_cm between 20 and 70),
  waist_cm          numeric(5, 1) check (waist_cm between 40 and 200),
  hip_cm            numeric(5, 1) check (hip_cm between 50 and 200),
  -- % grasa informado por un profesional, solo como referencia.
  reported_fat_pct  numeric(4, 2),
  source            text not null default 'app',
  created_at        timestamptz not null default now(),
  unique (user_id, measured_on)
);

create index if not exists measurements_user_date
  on public.measurements (user_id, measured_on desc);

alter table public.measurements enable row level security;

drop policy if exists "measurements: ver las propias" on public.measurements;
create policy "measurements: ver las propias" on public.measurements
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "measurements: crear las propias" on public.measurements;
create policy "measurements: crear las propias" on public.measurements
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "measurements: editar las propias" on public.measurements;
create policy "measurements: editar las propias" on public.measurements
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "measurements: borrar las propias" on public.measurements;
create policy "measurements: borrar las propias" on public.measurements
  for delete to authenticated using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------
-- updated_at automático
-- ---------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();
