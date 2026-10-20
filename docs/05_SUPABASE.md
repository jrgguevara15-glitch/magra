# 05 — Configurar Supabase

Proyecto: `twtkxvbnkxuggsnkihlb` (región São Paulo).
URL: `https://twtkxvbnkxuggsnkihlb.supabase.co`

La app usa la **publishable key** (pública por diseño, en
`apps/mobile/lib/core/config.dart`). La **secret key** y la contraseña de
la base de datos nunca van en el repositorio ni en la app.

## 1. Crear las tablas (una vez por migración, en orden)

1. Supabase → **SQL Editor** → **New query**.
2. Pegar el contenido de cada archivo de `backend/supabase/migrations/`,
   en orden: `0001_profiles_measurements.sql` (M2),
   `0002_questionnaires.sql` (M3), `0003_food_entries.sql` (M5),
   `0004_ai_usage.sql` (M6), `0005_exercise_fasting.sql` (M7),
   `0006_kcal_adjustments.sql` (M8), `0007_custom_products.sql` (M9b).
3. **Run**. Debe terminar con "Success. No rows returned".

Cada migración se puede volver a ejecutar sin romper nada.

## 2. Función de IA "ai-photo" (M6)

1. **Clave de la API de Claude**: console.anthropic.com → Settings → API
   Keys → Create Key. Cargar saldo en Billing (cada foto cuesta ~US$0,016).
   La clave no se comparte con nadie ni se pega en el chat ni en el código.
2. Supabase → **Edge Functions** → **Secrets** → Add new secret:
   nombre `ANTHROPIC_API_KEY`, valor = **solo la clave** (empieza con
   `sk-ant-`), sin comillas ni el comando `curl` de ejemplo que muestra
   la consola → Save.
3. Supabase → **Edge Functions** → **Deploy a new function** → **Via
   Editor** → nombre `ai-photo` → reemplazar el código de ejemplo por
   `backend/supabase/functions/ai-photo/index.ts` → **Deploy function**.

Desde M9 la misma función también recibe texto (`mode: "text"`, lo que
comió escrito o dictado), con su propio límite de 50 por día
(`ai_consume('text', 50)`); no requiere migración nueva. Al actualizar el
archivo hay que volver a desplegarla (Code → pegar → Deploy).

La función exige sesión: valida al usuario con `ai_consume()` (límite de 25
fotos por día) antes de llamar a Claude, aunque "Verify JWT" esté apagado.

## 3. Confirmación de correo (desarrollo)

Por defecto Supabase pide confirmar el correo antes de entrar. Mientras
desarrollamos se puede desactivar:

Authentication → **Sign In / Providers** → **Email** → desactivar
**Confirm email** → Save.

Antes de publicar la app hay que volver a activarlo (registrado en
BACKLOG.md).

## Verificado localmente (Postgres 16 con esquema `auth` simulado)

- Migraciones 0001 a 0007 idempotentes.
- Un usuario ve solo sus filas; otro usuario ve 0, no puede modificarlas,
  borrarlas ni insertar en la cuenta ajena (RLS).
- Restricción: macros deben sumar 100 %.
- Upsert por día (`user_id, measured_on`) como lo usa la app.
- Cuestionario: una fila por usuario; B no ve ni puede escribir la de A.
- Registro de comidas: B no ve, modifica, borra ni inserta en la cuenta de
  A; se rechazan calorías fuera de rango.
- Ejercicio y ayunos (M7): B no ve, termina ni borra lo de A, ni inserta
  en su cuenta; anónimo no ve nada; un solo ayuno en curso por usuario;
  solo metas de 12, 14 o 16 h; el fin debe ser posterior al inicio;
  minutos entre 1 y 600.
- Ajustes semanales (M8): una decisión por semana (upsert), la semana debe
  empezar en lunes, máximo ±150 por semana; B no ve, edita, borra ni
  inserta en la cuenta de A.
- Productos propios (M9b): uno por código y usuario (upsert); código de 8
  a 14 dígitos, kcal 0–900 y macros 0–100 por 100 g/ml, unidad g o ml; B
  no ve ni modifica los de A y puede tener su propio producto con el mismo
  código.
- Límite de IA: 25 por día y por usuario; la 26.ª falla y no cuenta; cada
  usuario su propio conteo; sin sesión o anónimo no se puede usar; nadie
  puede reiniciar su contador.
- Función ai-photo (M9): modo texto validado (largo 3–500, sin imagen,
  prompt con la descripción); 8 pruebas.
- Función ai-photo: compila contra los tipos de @anthropic-ai/sdk 0.132.1 y
  @supabase/supabase-js 2.117.3; 6 pruebas con un Claude simulado (entrada,
  petición, recorte de valores absurdos, rechazo, respuesta ilegible,
  sesión).
- La clave mal pegada (con espacios, comillas o el comando curl) se
  rechaza antes de descontar del límite, y una clave nunca queda en los
  logs aunque venga dentro de un error.
