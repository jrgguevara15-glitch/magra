-- MAGRA · M7 — ejercicio del día y ayunos.
-- exercise_entries: cada actividad hecha un día, con las calorías netas ya
-- calculadas (MET y peso de ese momento) para que el historial no cambie.
-- fasts: cada ayuno con su inicio, su fin (null mientras está en curso) y su
-- meta en horas. Un solo ayuno en curso por usuario y nunca más de 24 h de
-- meta. Cada usuario ve y modifica solo lo suyo.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.exercise_entries (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid()
                 references auth.users (id) on delete cascade,
  done_on      date not null,
  activity_id  text not null check (length(activity_id) between 1 and 40),
  name         text not null check (length(name) between 1 and 120),
  met          numeric(4, 1) not null check (met between 1 and 25),
  minutes      smallint not null check (minutes between 1 and 600),
  kcal_net     numeric(6, 1) not null check (kcal_net between 0 and 5000),
  created_at   timestamptz not null default now()
);

create index if not exists exercise_entries_user_day
  on public.exercise_entries (user_id, done_on);

alter table public.exercise_entries enable row level security;

drop policy if exists "exercise_entries: ver las propias" on public.exercise_entries;
create policy "exercise_entries: ver las propias" on public.exercise_entries
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "exercise_entries: crear las propias" on public.exercise_entries;
create policy "exercise_entries: crear las propias" on public.exercise_entries
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "exercise_entries: borrar las propias" on public.exercise_entries;
create policy "exercise_entries: borrar las propias" on public.exercise_entries
  for delete to authenticated using ((select auth.uid()) = user_id);

create table if not exists public.fasts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  started_at    timestamptz not null,
  ended_at      timestamptz check (ended_at > started_at),
  target_hours  smallint not null check (target_hours in (12, 14, 16)),
  created_at    timestamptz not null default now()
);

create index if not exists fasts_user_started
  on public.fasts (user_id, started_at desc);

-- Un solo ayuno en curso por usuario.
create unique index if not exists fasts_one_open
  on public.fasts (user_id) where ended_at is null;

alter table public.fasts enable row level security;

drop policy if exists "fasts: ver los propios" on public.fasts;
create policy "fasts: ver los propios" on public.fasts
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "fasts: crear los propios" on public.fasts;
create policy "fasts: crear los propios" on public.fasts
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "fasts: terminar los propios" on public.fasts;
create policy "fasts: terminar los propios" on public.fasts
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "fasts: borrar los propios" on public.fasts;
create policy "fasts: borrar los propios" on public.fasts
  for delete to authenticated using ((select auth.uid()) = user_id);
