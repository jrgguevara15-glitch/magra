-- MAGRA · M6 — límite diario de uso de la IA por usuario.
-- La función del servidor llama a ai_consume() antes de cada análisis: así
-- un usuario no puede generar costos sin control. El usuario ve su propio
-- uso; solo ai_consume() lo modifica.
-- Ejecutar en Supabase → SQL Editor → New query → Run.

create table if not exists public.ai_usage (
  user_id  uuid not null default auth.uid()
             references auth.users (id) on delete cascade,
  day      date not null default current_date,
  feature  text not null check (length(feature) <= 30),
  count    integer not null default 0,
  primary key (user_id, day, feature)
);

alter table public.ai_usage enable row level security;

drop policy if exists "ai_usage: ver el propio" on public.ai_usage;
create policy "ai_usage: ver el propio" on public.ai_usage
  for select to authenticated using ((select auth.uid()) = user_id);

-- Suma un uso de hoy y devuelve cuántos lleva. Si pasa el límite, falla
-- con 'limit_reached' y no cuenta.
create or replace function public.ai_consume(p_feature text, p_limit integer)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  n integer;
begin
  if uid is null then
    raise exception 'not_authenticated';
  end if;
  insert into public.ai_usage (user_id, day, feature, count)
  values (uid, current_date, p_feature, 1)
  on conflict (user_id, day, feature)
    do update set count = public.ai_usage.count + 1
  returning count into n;
  if n > p_limit then
    raise exception 'limit_reached';
  end if;
  return n;
end;
$$;

revoke all on function public.ai_consume(text, integer) from public, anon;
grant execute on function public.ai_consume(text, integer) to authenticated;
