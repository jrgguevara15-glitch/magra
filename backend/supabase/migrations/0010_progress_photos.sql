-- MAGRA · M13 — fotos de progreso.
-- Las imágenes van a un bucket PRIVADO de Supabase Storage, cada usuario en
-- su carpeta (<user_id>/...). La tabla guarda fecha, pose y ruta para
-- listarlas y compararlas. Nadie ve las fotos de otro; no son públicas y
-- no se envían a la IA.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('progress-photos', 'progress-photos', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "progress-photos: ver las propias" on storage.objects;
create policy "progress-photos: ver las propias" on storage.objects
  for select to authenticated
  using (bucket_id = 'progress-photos'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "progress-photos: subir las propias" on storage.objects;
create policy "progress-photos: subir las propias" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'progress-photos'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "progress-photos: borrar las propias" on storage.objects;
create policy "progress-photos: borrar las propias" on storage.objects
  for delete to authenticated
  using (bucket_id = 'progress-photos'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

create table if not exists public.progress_photos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  taken_on    date not null,
  pose        text not null check (pose in ('front', 'side', 'back')),
  path        text not null unique,
  created_at  timestamptz not null default now(),
  -- La ruta siempre dentro de la carpeta del propio usuario.
  check (split_part(path, '/', 1) = user_id::text)
);

create index if not exists progress_photos_user_day
  on public.progress_photos (user_id, taken_on desc);

alter table public.progress_photos enable row level security;

drop policy if exists "progress_photos: ver las propias" on public.progress_photos;
create policy "progress_photos: ver las propias" on public.progress_photos
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "progress_photos: crear las propias" on public.progress_photos;
create policy "progress_photos: crear las propias" on public.progress_photos
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "progress_photos: borrar las propias" on public.progress_photos;
create policy "progress_photos: borrar las propias" on public.progress_photos
  for delete to authenticated using ((select auth.uid()) = user_id);
