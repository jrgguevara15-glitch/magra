-- MAGRA · M3 — cuestionario: rutina, entrenamiento, salud y alimentación.
-- Datos que el motor de recomendación (M4) usa para decidir el plan.
-- Una fila por usuario; cada usuario ve y modifica solo la suya (RLS).
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.questionnaires (
  user_id            uuid primary key default auth.uid()
                       references auth.users (id) on delete cascade,

  -- Rutina
  wake_time          time not null,
  sleep_time         time not null,
  work_schedule      text not null
                       check (work_schedule in ('day', 'night', 'shifts', 'flexible', 'none')),

  -- Entrenamiento
  training_days      smallint not null check (training_days between 0 and 7),
  session_minutes    smallint not null check (session_minutes between 15 and 180),
  training_time      text not null
                       check (training_time in ('early', 'morning', 'midday', 'afternoon', 'evening', 'varies')),
  experience         text not null
                       check (experience in ('none', 'beginner', 'intermediate', 'advanced')),
  equipment          text not null
                       check (equipment in ('gym', 'home_weights', 'bodyweight')),
  injuries           text[] not null default '{}',

  -- Salud
  health_conditions  text[] not null default '{}',
  health_notes       text not null default '' check (length(health_notes) <= 500),

  -- Alimentación
  diet_pattern       text not null
                       check (diet_pattern in ('omnivore', 'pescatarian', 'vegetarian', 'vegan')),
  allergies          text[] not null default '{}',
  disliked_foods     text not null default '' check (length(disliked_foods) <= 500),
  preferred_meals    smallint check (preferred_meals between 2 and 6),
  fasting            text not null check (fasting in ('no', 'open', 'yes')),
  cooking            text not null check (cooking in ('daily', 'batch', 'rarely')),
  budget             text not null check (budget in ('low', 'medium', 'high')),

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

alter table public.questionnaires enable row level security;

drop policy if exists "questionnaires: ver el propio" on public.questionnaires;
create policy "questionnaires: ver el propio" on public.questionnaires
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "questionnaires: crear el propio" on public.questionnaires;
create policy "questionnaires: crear el propio" on public.questionnaires
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "questionnaires: editar el propio" on public.questionnaires;
create policy "questionnaires: editar el propio" on public.questionnaires
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop trigger if exists questionnaires_touch on public.questionnaires;
create trigger questionnaires_touch before update on public.questionnaires
  for each row execute function public.touch_updated_at();
