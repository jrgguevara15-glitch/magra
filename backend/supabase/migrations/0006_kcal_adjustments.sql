-- MAGRA · M8 — ajuste semanal de calorías.
-- Una fila por semana (lunes) con el cambio que MAGRA propuso y si el
-- usuario lo aplicó. La meta del día = fórmula + suma de los aplicados
-- (la app la limita a ±500 kcal y nunca baja del mínimo seguro).
-- Cada usuario ve y modifica solo lo suyo.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.kcal_adjustments (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  week_start  date not null check (extract(isodow from week_start) = 1),
  delta_kcal  smallint not null check (delta_kcal between -150 and 150),
  applied     boolean not null,
  reason      text not null check (length(reason) between 1 and 40),
  created_at  timestamptz not null default now(),
  unique (user_id, week_start)
);

alter table public.kcal_adjustments enable row level security;

drop policy if exists "kcal_adjustments: ver los propios" on public.kcal_adjustments;
create policy "kcal_adjustments: ver los propios" on public.kcal_adjustments
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "kcal_adjustments: crear los propios" on public.kcal_adjustments;
create policy "kcal_adjustments: crear los propios" on public.kcal_adjustments
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "kcal_adjustments: editar los propios" on public.kcal_adjustments;
create policy "kcal_adjustments: editar los propios" on public.kcal_adjustments
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "kcal_adjustments: borrar los propios" on public.kcal_adjustments;
create policy "kcal_adjustments: borrar los propios" on public.kcal_adjustments
  for delete to authenticated using ((select auth.uid()) = user_id);
