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
   `0006_kcal_adjustments.sql` (M8), `0007_custom_products.sql` (M9b),
   `0008_menus.sql` (M11), `0009_workouts.sql` (M12),
   `0010_progress_photos.sql` (M13, crea el bucket privado
   `progress-photos` y sus permisos), `0011_coach.sql` (M15), `0012_calorie_bank.sql` (M16).
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

## 2c. Función del coach "ai-coach" (M15)

Igual que ai-menu: Deploy a new function → Via Editor → nombre `ai-coach`
→ pegar `backend/supabase/functions/ai-coach/index.ts` → Deploy. Solo
responde si la persona aceptó compartir sus datos (tabla `ai_consents`).
Límites: 30 mensajes y 3 revisiones semanales por día.

## 2b. Función de menús "ai-menu" (M11)

Edge Functions → **Deploy a new function** → **Via Editor** → nombre
`ai-menu` → reemplazar el ejemplo por `backend/supabase/functions/ai-menu/index.ts`
(copiar con `Get-Content … -Raw -Encoding UTF8 | Set-Clipboard`) → Deploy.
Usa el mismo secreto `ANTHROPIC_API_KEY`. Límites: 3 menús semanales y 20
cambios de comida por día (`ai_consume`). Arma los 7 días en paralelo.

La función ai-photo exige sesión: valida al usuario con `ai_consume()` (límite de 25
fotos por día) antes de llamar a Claude, aunque "Verify JWT" esté apagado.

## 3. Confirmación de correo (desarrollo)

Por defecto Supabase pide confirmar el correo antes de entrar. Mientras
desarrollamos se puede desactivar:

Authentication → **Sign In / Providers** → **Email** → desactivar
**Confirm email** → Save.

Antes de publicar la app hay que volver a activarlo (registrado en
BACKLOG.md).

## Verificado localmente (Postgres 16 con esquema `auth` simulado)

- Migraciones 0001 a 0012 idempotentes.
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
- Menús (M11): uno por semana (lunes) y usuario, 7 días obligatorios; B no
  ve ni modifica el de A; food_entries acepta origen 'menu' y rechaza
  otros desconocidos.
- Sesiones de fuerza (M12): 1–20 ejercicios y 1–300 minutos; B no ve,
  borra ni inserta en la cuenta de A.
- Fotos de progreso (M13, con `storage` simulado): bucket privado de 5 MB
  (JPG/PNG/WebP); cada usuario solo sube, ve y borra en su carpeta
  `<user_id>/`; la ruta de la fila debe estar en su carpeta; anónimo no
  ve nada.
- Coach (M15): mensajes solo 'user'/'assistant' (1–8.000 caracteres) y
  consentimiento solo 'coach'; B no ve, borra ni inserta en la cuenta de
  A; retirar el consentimiento y borrar la conversación funciona.
- Función ai-coach: compila contra los tipos del SDK; 4 pruebas (normaliza
  la conversación, reglas y datos en el system, revisión semanal,
  rechazo/vacío, sesión). Exige consentimiento antes de llamar a la IA.
- Banco de calorías (M16): un uso por día (upsert), 1–500 kcal; B no ve
  ni modifica lo de A.
- Función ai-menu: compila contra los tipos del SDK; 6 pruebas (petición,
  prompt con metas/alergias/gustos/variedad, 7 llamadas en paralelo,
  respuestas incompletas o rechazadas, saneo, sesión).
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
