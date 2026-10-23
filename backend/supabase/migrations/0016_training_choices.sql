-- MAGRA · U21 — sesión alternativa del día.
-- Cuando el usuario decide variar un día (HYROX, CrossFit, yoga, etc.) en
-- vez de su rutina, se guarda aquí qué sesión eligió para esa fecha, para
-- verla igual en todos sus dispositivos. Cada usuario ve y modifica solo lo
-- suyo.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.training_choices (
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  day         date not null,
  session_id  text not null check (length(session_id) between 1 and 40),
  updated_at  timestamptz not null default now(),
  primary key (user_id, day)
);

alter table public.training_choices enable row level security;

drop policy if exists "training_choices: ver los propios" on public.training_choices;
create policy "training_choices: ver los propios" on public.training_choices
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "training_choices: crear los propios" on public.training_choices;
create policy "training_choices: crear los propios" on public.training_choices
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "training_choices: editar los propios" on public.training_choices;
create policy "training_choices: editar los propios" on public.training_choices
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "training_choices: borrar los propios" on public.training_choices;
create policy "training_choices: borrar los propios" on public.training_choices
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Que la API vea la tabla nueva de inmediato.
notify pgrst, 'reload schema';
