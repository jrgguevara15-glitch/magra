-- MAGRA · M16 — banco de calorías.
-- Lo que el usuario decide usar de su banco semanal en un día (para un
-- asado, un cumpleaños...). Lo guardado se calcula en la app con lo
-- registrado; aquí solo se anota cuánto se usó cada día (máximo 500).
-- Cada usuario ve y modifica solo lo suyo.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.calorie_bank_uses (
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  used_on     date not null,
  kcal        smallint not null check (kcal between 1 and 500),
  created_at  timestamptz not null default now(),
  primary key (user_id, used_on)
);

alter table public.calorie_bank_uses enable row level security;

drop policy if exists "calorie_bank_uses: ver los propios" on public.calorie_bank_uses;
create policy "calorie_bank_uses: ver los propios" on public.calorie_bank_uses
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "calorie_bank_uses: crear los propios" on public.calorie_bank_uses;
create policy "calorie_bank_uses: crear los propios" on public.calorie_bank_uses
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "calorie_bank_uses: editar los propios" on public.calorie_bank_uses;
create policy "calorie_bank_uses: editar los propios" on public.calorie_bank_uses
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "calorie_bank_uses: borrar los propios" on public.calorie_bank_uses;
create policy "calorie_bank_uses: borrar los propios" on public.calorie_bank_uses
  for delete to authenticated using ((select auth.uid()) = user_id);
