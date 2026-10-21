-- MAGRA · M12 — sesiones de fuerza registradas.
-- Cada fila es una sesión con sus ejercicios y series (repeticiones y
-- kilos) en jsonb. Con este historial la app calcula la próxima carga
-- (doble progresión) y qué sesión toca. Cada usuario ve y modifica solo lo
-- suyo.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.workout_sessions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  done_on     date not null,
  title       text not null check (length(title) between 1 and 60),
  minutes     smallint not null check (minutes between 1 and 300),
  exercises   jsonb not null check (jsonb_typeof(exercises) = 'array'
                                    and jsonb_array_length(exercises) between 1 and 20),
  created_at  timestamptz not null default now()
);

create index if not exists workout_sessions_user_day
  on public.workout_sessions (user_id, done_on desc);

alter table public.workout_sessions enable row level security;

drop policy if exists "workout_sessions: ver las propias" on public.workout_sessions;
create policy "workout_sessions: ver las propias" on public.workout_sessions
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "workout_sessions: crear las propias" on public.workout_sessions;
create policy "workout_sessions: crear las propias" on public.workout_sessions
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "workout_sessions: borrar las propias" on public.workout_sessions;
create policy "workout_sessions: borrar las propias" on public.workout_sessions
  for delete to authenticated using ((select auth.uid()) = user_id);
