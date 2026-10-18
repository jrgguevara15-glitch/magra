# 05 — Configurar Supabase

Proyecto: `twtkxvbnkxuggsnkihlb` (región São Paulo).
URL: `https://twtkxvbnkxuggsnkihlb.supabase.co`

La app usa la **publishable key** (pública por diseño, en
`apps/mobile/lib/core/config.dart`). La **secret key** y la contraseña de
la base de datos nunca van en el repositorio ni en la app.

## 1. Crear las tablas (una vez por migración)

1. Supabase → **SQL Editor** → **New query**.
2. Pegar el contenido de `backend/supabase/migrations/0001_profiles_measurements.sql`.
3. **Run**. Debe terminar con "Success. No rows returned".

Se puede volver a ejecutar sin romper nada.

## 2. Confirmación de correo (desarrollo)

Por defecto Supabase pide confirmar el correo antes de entrar. Mientras
desarrollamos se puede desactivar:

Authentication → **Sign In / Providers** → **Email** → desactivar
**Confirm email** → Save.

Antes de publicar la app hay que volver a activarlo (registrado en
BACKLOG.md).

## Verificado localmente (Postgres 16 con esquema `auth` simulado)

- Migración idempotente.
- Un usuario ve solo sus filas; otro usuario ve 0, no puede modificarlas,
  borrarlas ni insertar en la cuenta ajena (RLS).
- Restricción: macros deben sumar 100 %.
- Upsert por día (`user_id, measured_on`) como lo usa la app.
