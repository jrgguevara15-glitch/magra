-- MAGRA · U11 — ejercicios sustituidos por el usuario.
-- Cuando el usuario cambia un ejercicio de su rutina por otro parecido, se
-- guarda aquí (ejercicio original → elegido) para que la rutina lo muestre
-- igual en todos sus dispositivos. Cada usuario ve y modifica solo lo suyo.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.exercise_swaps (
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  original    text not null check (length(original) between 1 and 120),
  chosen      text not null check (length(chosen) between 1 and 120),
  updated_at  timestamptz not null default now(),
  primary key (user_id, original)
);

alter table public.exercise_swaps enable row level security;

drop policy if exists "exercise_swaps: ver los propios" on public.exercise_swaps;
create policy "exercise_swaps: ver los propios" on public.exercise_swaps
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "exercise_swaps: crear los propios" on public.exercise_swaps;
create policy "exercise_swaps: crear los propios" on public.exercise_swaps
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "exercise_swaps: editar los propios" on public.exercise_swaps;
create policy "exercise_swaps: editar los propios" on public.exercise_swaps
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "exercise_swaps: borrar los propios" on public.exercise_swaps;
create policy "exercise_swaps: borrar los propios" on public.exercise_swaps
  for delete to authenticated using ((select auth.uid()) = user_id);
