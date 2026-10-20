-- MAGRA · M5 — registro diario de comidas.
-- Cada fila es un alimento comido un día, en una de las comidas del plan.
-- Los nutrientes se guardan ya calculados para que el historial no cambie
-- si mañana se corrige el catálogo. Cada usuario ve y modifica solo lo suyo.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.food_entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  eaten_on    date not null,
  -- Índice de la comida del plan (0 = primera). Fuera de rango = "Otros".
  meal_index  smallint not null check (meal_index between 0 and 9),
  name        text not null check (length(name) between 1 and 120),
  quantity    numeric(7, 1) check (quantity > 0),
  unit        text not null default 'g' check (length(unit) <= 20),
  kcal        numeric(6, 1) not null check (kcal between 0 and 5000),
  protein_g   numeric(5, 1) not null default 0 check (protein_g between 0 and 500),
  carbs_g     numeric(5, 1) not null default 0 check (carbs_g between 0 and 1000),
  fat_g       numeric(5, 1) not null default 0 check (fat_g between 0 and 500),
  source      text not null default 'catalog'
                check (source in ('catalog', 'manual', 'photo', 'barcode', 'voice')),
  created_at  timestamptz not null default now()
);

create index if not exists food_entries_user_day
  on public.food_entries (user_id, eaten_on);

alter table public.food_entries enable row level security;

drop policy if exists "food_entries: ver las propias" on public.food_entries;
create policy "food_entries: ver las propias" on public.food_entries
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "food_entries: crear las propias" on public.food_entries;
create policy "food_entries: crear las propias" on public.food_entries
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "food_entries: editar las propias" on public.food_entries;
create policy "food_entries: editar las propias" on public.food_entries
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "food_entries: borrar las propias" on public.food_entries;
create policy "food_entries: borrar las propias" on public.food_entries
  for delete to authenticated using ((select auth.uid()) = user_id);
