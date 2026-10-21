-- MAGRA · M15 — Coach IA.
-- coach_messages: la conversación con el coach (lo que escribe el usuario y
-- lo que responde la IA), para mostrarla y darle contexto a la siguiente
-- respuesta. ai_consents: el permiso explícito del usuario para enviar sus
-- datos de salud a la IA en cada función. Cada usuario ve y modifica solo
-- lo suyo.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.coach_messages (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  role        text not null check (role in ('user', 'assistant')),
  kind        text not null default 'chat' check (kind in ('chat', 'review')),
  content     text not null check (length(content) between 1 and 8000),
  created_at  timestamptz not null default now()
);

create index if not exists coach_messages_user_time
  on public.coach_messages (user_id, created_at);

alter table public.coach_messages enable row level security;

drop policy if exists "coach_messages: ver los propios" on public.coach_messages;
create policy "coach_messages: ver los propios" on public.coach_messages
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "coach_messages: crear los propios" on public.coach_messages;
create policy "coach_messages: crear los propios" on public.coach_messages
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "coach_messages: borrar los propios" on public.coach_messages;
create policy "coach_messages: borrar los propios" on public.coach_messages
  for delete to authenticated using ((select auth.uid()) = user_id);

create table if not exists public.ai_consents (
  user_id      uuid not null default auth.uid()
                 references auth.users (id) on delete cascade,
  feature      text not null check (feature in ('coach')),
  accepted_at  timestamptz not null default now(),
  primary key (user_id, feature)
);

alter table public.ai_consents enable row level security;

drop policy if exists "ai_consents: ver los propios" on public.ai_consents;
create policy "ai_consents: ver los propios" on public.ai_consents
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "ai_consents: dar el propio" on public.ai_consents;
create policy "ai_consents: dar el propio" on public.ai_consents
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "ai_consents: retirar el propio" on public.ai_consents;
create policy "ai_consents: retirar el propio" on public.ai_consents
  for delete to authenticated using ((select auth.uid()) = user_id);
