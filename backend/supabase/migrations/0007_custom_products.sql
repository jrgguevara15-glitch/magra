-- MAGRA · M9b — productos creados por el usuario.
-- Cuando un código de barras no está en Open Food Facts (o viene sin
-- nutrientes), el usuario lo crea con los valores por 100 g/ml de la
-- etiqueta. La próxima vez que lo escanee, MAGRA lo encuentra aquí primero.
-- Cada usuario ve y modifica solo lo suyo.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.custom_products (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null default auth.uid()
                      references auth.users (id) on delete cascade,
  code              text not null check (code ~ '^[0-9]{8,14}$'),
  name              text not null check (length(name) between 1 and 80),
  brand             text check (length(brand) <= 40),
  unit              text not null default 'g' check (unit in ('g', 'ml')),
  kcal_100          numeric(5, 1) not null check (kcal_100 between 0 and 900),
  protein_100       numeric(4, 1) not null default 0 check (protein_100 between 0 and 100),
  carbs_100         numeric(4, 1) not null default 0 check (carbs_100 between 0 and 100),
  fat_100           numeric(4, 1) not null default 0 check (fat_100 between 0 and 100),
  serving_quantity  numeric(6, 1) check (serving_quantity > 0 and serving_quantity <= 2000),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (user_id, code)
);

alter table public.custom_products enable row level security;

drop policy if exists "custom_products: ver los propios" on public.custom_products;
create policy "custom_products: ver los propios" on public.custom_products
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "custom_products: crear los propios" on public.custom_products;
create policy "custom_products: crear los propios" on public.custom_products
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "custom_products: editar los propios" on public.custom_products;
create policy "custom_products: editar los propios" on public.custom_products
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "custom_products: borrar los propios" on public.custom_products;
create policy "custom_products: borrar los propios" on public.custom_products
  for delete to authenticated using ((select auth.uid()) = user_id);
