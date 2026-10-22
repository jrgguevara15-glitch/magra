-- MAGRA · U15 — evaluación corporal con foto.
-- body_assessments guarda el RESULTADO de cada evaluación (no las fotos):
-- % de grasa estimado por la foto con su rango, el de las medidas, el %
-- final combinado y las observaciones y recomendaciones. ai_consents suma
-- el permiso 'body' (enviar fotos del cuerpo a la IA). Cada usuario ve y
-- modifica solo lo suyo.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

alter table public.ai_consents drop constraint if exists ai_consents_feature_check;
alter table public.ai_consents
  add constraint ai_consents_feature_check check (feature in ('coach', 'body'));

create table if not exists public.body_assessments (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid()
                   references auth.users (id) on delete cascade,
  assessed_on    date not null default current_date,
  weight_kg      numeric(5, 1) not null check (weight_kg between 25 and 400),
  photo_fat_pct  numeric(4, 1) check (photo_fat_pct between 3 and 70),
  photo_fat_low  numeric(4, 1) check (photo_fat_low between 3 and 70),
  photo_fat_high numeric(4, 1) check (photo_fat_high between 3 and 70),
  tape_fat_pct   numeric(4, 1) check (tape_fat_pct between 3 and 70),
  final_fat_pct  numeric(4, 1) not null check (final_fat_pct between 3 and 70),
  confidence     text not null default 'media' check (confidence in ('alta', 'media', 'baja')),
  details        jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now()
);

create index if not exists body_assessments_user_day
  on public.body_assessments (user_id, assessed_on);

alter table public.body_assessments enable row level security;

drop policy if exists "body_assessments: ver las propias" on public.body_assessments;
create policy "body_assessments: ver las propias" on public.body_assessments
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "body_assessments: crear las propias" on public.body_assessments;
create policy "body_assessments: crear las propias" on public.body_assessments
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "body_assessments: borrar las propias" on public.body_assessments;
create policy "body_assessments: borrar las propias" on public.body_assessments
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Que la API vea la tabla nueva de inmediato.
notify pgrst, 'reload schema';
