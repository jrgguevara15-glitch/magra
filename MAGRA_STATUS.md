# ESTADO ACTUAL DE MAGRA

## Fase 1 — Prototipo web

- TERMINADA por el agente; validación funcional del usuario PENDIENTE.

## Fase 2 — Núcleo nativo

- M0 — Scaffolding Flutter: TERMINADO. Validación funcional del usuario
  APROBADA en Chrome (Windows) con Flutter 3.47: wordmark MAGRA, 6 pestañas
  y navegación lateral en escritorio. analyze sin issues, 3/3 pruebas.
- M1 — Fórmulas puras: TERMINADO. Validación del usuario APROBADA
  (flutter test en Windows, Flutter 3.47: 32/32).
  `lib/core/formulas/` (composición corporal, energía, intercambios,
  ejercicio MET, meta física, tendencia). 29 pruebas contra los valores de
  los informes del nutricionista. analyze sin issues; suite 32/32.
- M2 — Supabase (cuentas, perfil, mediciones): TERMINADO. Validación del
  usuario APROBADA (Chrome/Windows: crear cuenta, perfil, medición con y sin
  perímetros, evaluación completa, cerrar sesión y volver a entrar). Migración + RLS validadas en Postgres local; inicio de
  sesión con correo, perfil, mediciones y evaluación en Progreso.
  analyze sin issues; suite 44/44; build web OK.
- M3 — Cuestionario completo: TERMINADO. Validación del usuario APROBADA
  (responder, editar, aviso de salud, persistencia tras cerrar sesión). Migración 0002 (questionnaires + RLS) validada en Postgres
  local. 4 pasos (rutina, entrenamiento, salud, alimentación) desde
  Progreso; aviso cuando una condición requiere un profesional.
  analyze sin issues; suite 52/52; build web OK.
- M4 — Motor de recomendación: TERMINADO. Validación del usuario APROBADA
  (Plan, Entreno, meta por etapas y cambios al editar el cuestionario). Pestaña Plan (calorías, n.º de comidas, horarios, qué comer
  con ejemplos filtrados por dieta/alergias/gustos, porqué), pestaña Entreno
  (rutina por días/experiencia/equipo/lesiones, cardio, zona 2, pasos),
  avisos de salud y meta por etapas en Progreso. Reglas en
  docs/02_FORMULAS.md. analyze sin issues; suite 81/81; build web OK.
- M5 — Registro del día: TERMINADO. Validación del usuario APROBADA
  (catálogo, cantidad sugerida, a mano, quitar, días, persistencia).
  Migración 0003 (food_entries + RLS) validada en Postgres local. Pestaña
  Hoy: resumen de calorías y macros contra el plan, comidas del plan con lo
  registrado, "Fuera del plan", catálogo de 41 alimentos filtrado por dieta
  y alergias con cantidad sugerida, ingreso a mano, quitar y navegar días.
  analyze sin issues; suite 92/92; build web OK.
- M6 — Foto → calorías con IA: TERMINADO. Validación del usuario APROBADA
  en Chrome/Windows (foto de pabellón criollo → 4 alimentos con porciones y
  macros) y en iPhone/Safari por Wi-Fi (tomar foto con la cámara).
  Edge Function ai-photo (claude-opus-5-5, salida estructurada, fallbacks,
  límite 25/día con migración 0004). En Hoy → Agregar → Foto: plato o
  etiqueta, aclaración, revisar/corregir cantidades y agregar. Permisos de
  cámara (iOS) y archivos/red (macOS). analyze sin issues; suite 102/102;
  build web OK.
- M7 — Ejercicio MET + ayuno con avisos: TERMINADO. Validación del usuario
  APROBADA (migración 0005 aplicada; ejercicio y ayuno en Hoy). En Hoy: tarjeta Ejercicio
  (18 actividades MET, minutos, kcal netas con el peso actual, +50 % a la
  meta del día) y tarjeta Ayuno (12:12/14:10/16:8, hora de inicio,
  progreso, avisos de meta cumplida y > 24 h, terminar o borrar; bloqueado
  con explicación por glucosa, TCA, condición supervisada o ≥ 65 años).
  Migración 0005 + RLS validadas en Postgres local. analyze sin issues;
  suite 112/112; build web OK.
- M8 — Peso de tendencia + gasto adaptativo semanal: TERMINADO.
  Validación del usuario APROBADA (migración 0006; gráfico, propuesta
  +150 por bajar rápido, aplicar, Plan y Hoy con la meta ajustada). En
  Progreso: gráfico de 90 días (pesajes + tendencia), ritmo semanal, gasto
  real estimado con el registro de Hoy y ajuste de la semana (aplicar /
  ahora no); el Plan y Hoy usan la meta ajustada. Reglas en
  docs/02_FORMULAS.md. Migración 0006 + RLS validadas en Postgres local.
  analyze sin issues; suite 133/133; build web OK.
- M9 — Código de barras y registro por voz: TERMINADO. Validación del
  usuario APROBADA (ai-photo redesplegada; Describir → completo + Pepsi
  Zero; escaneo con cámara del PC y consulta a Open Food Facts; el
  producto chileno probado no estaba en la base). En Hoy →
  Agregar: "Código" (escribir o escanear con mobile_scanner; datos de Open
  Food Facts por 100 g/ml, porción del envase, cantidad editable) y
  "Describir" (texto o dictado con el micrófono del teclado → IA → revisar
  y agregar, 50 por día). analyze sin issues; suite 143/143; build web OK.
- M9b — Crear productos que no están (pedido por el usuario): TERMINADO.
  Validación del usuario APROBADA (migración 0007; crear y volver a
  encontrar un producto).
  Si un código no está en Open Food Facts o viene sin nutrientes: "Crear
  producto" con valores por 100 g/ml (o "Leer la etiqueta con una foto"),
  queda guardado en la cuenta y se busca primero la próxima vez; los
  propios se pueden corregir. analyze sin issues; suite 147/147; build web
  OK.
- M11 — Menús semanales con IA + lista de compras: TERMINADO. Validación
  del usuario APROBADA (migración 0008 y ai-menu desplegada; menú de la
  semana generado y guardado). Durante la prueba: si no se puede guardar
  se conserva el menú para reintentar, y una respuesta inesperada de la
  función se muestra tal cual. Pestaña Menús: generar la semana con las metas del plan, ver
  por día, "Lo comí" (registra en Hoy), "Cambiar" una comida, nuevo menú
  y lista de compras por sección con marcas sugeridas y checks guardados.
  analyze sin issues; suite 156/156; build web OK.
- M12 — Rutinas adaptativas de fuerza: TERMINADO. Validación del usuario
  APROBADA (migración 0009; registrar sesiones, rotación y carga
  sugerida). Entreno: "Hoy te toca" con
  la sesión de la rotación, registrar series (reps y kg) con la carga
  sugerida por doble progresión, descarga tras 3 fallos, historial con
  borrar y calorías a Hoy. analyze sin issues; suite 169/169; build web
  OK.
- M13 — Fotos de progreso y comparador: TERMINADO. Validación del usuario
  APROBADA (migración 0010; subir, ver y comparar). Publicado en Netlify
  (https://magrafit.netlify.app) y probado en iPhone. Progreso: recordatorio cada
  30 días, subir frente/perfil/espalda por fecha a un bucket privado,
  última tanda, ver/borrar y comparar dos fechas con peso, cintura y %
  grasa de la medición más cercana. analyze sin issues; suite 176/176;
  build web OK.
- M15 — Coach IA (chat y revisión semanal): TERMINADO. Validación del
  usuario APROBADA (migración 0011, ai-coach desplegada; chat y revisión).
  Pestaña Coach: consentimiento explícito antes de enviar datos, chat con
  resumen de los datos (sin nombre ni correo), sugerencias, revisión
  semanal (destacada domingo/lunes), reintentar, borrar conversación y
  dejar de compartir. analyze sin issues; suite 182/182; build web OK.
- M16 — Rachas, logros, semáforo y banco de calorías: TERMINADO.
  Validación del usuario APROBADA (migración 0012). Hoy:
  rachas (registro, proteína, semanas entrenando), semáforo en el
  catálogo y en lo registrado, banco de la semana (usar/dejar de usar).
  Progreso: logros con avance. analyze sin issues; suite 191/191; build
  web OK.
- M10, M14 y M17 en adelante — NO ABIERTOS.

## Mejoras pedidas por el usuario (antes de M18)

- U1 — Nueva interfaz "energía neón" (elegida por el usuario): TERMINADO,
  validación del usuario APROBADA. Tema oscuro #0B0F1A con lima #B6FF3B, violeta
  #7C5CFF y cian; botones píldora, tarjetas redondeadas, campos rellenos,
  wordmark en degradado, cambio de pestaña animado, anillo de calorías y
  barras animadas en Hoy, tarjetas destacadas con degradado y efecto al
  tocar/pasar el mouse (Entreno, Coach), navegación lateral con nombres
  en PC (≥ 1.200 px). analyze sin issues; suite 191/191; build web OK.
- U2 — Ejercicios tocables con imágenes: IMPLEMENTADO, validación
  PENDIENTE. 28 movimientos con fotos de Free Exercise DB (dominio
  público, 56 imágenes reducidas a 600 px, 1,7 MB en assets/exercises),
  ficha en español con fotos que se alternan (inicio/fin), equipo,
  músculos, pasos y errores comunes; miniatura y acceso desde la rutina y
  desde la sesión. Prueba que todo ejercicio del motor tiene ficha.
  analyze sin issues; suite 194/194; build web OK.
- U3 — Calentamiento y estiramiento guiados con temporizador: PENDIENTE.
- U4 — Recetas con condimentos, aceites y grasas saludables: PENDIENTE.

## PAUSA (21-oct-2026)

El usuario pidió pausar antes de M18 para proponer mejoras. Al retomar:
primero sus mejoras (como bloques cerrados, con su validación), después
la hoja de ruta de abajo.

## Próximos pasos (hoja de ruta acordada)

1. Mejoras que pida el usuario (pendiente que las describa).
2. M18 — Legal: términos, política de privacidad, consentimiento al
   crear la cuenta, exportar datos y borrar la cuenta con todo su
   contenido (obligatorio antes de vender: datos de salud).
3. M20 — PDF para el nutricionista (medidas, evolución, plan, registro).
4. Preparar compilación nativa: cuenta Apple Developer (US$99/año) +
   Codemagic (no hay Mac); Android con APK.
5. M10 — Apple Health / Health Connect (requiere app nativa).
6. M14 — Notificaciones (requiere app nativa).
7. M17 — Suscripciones con RevenueCat, gratis vs premium.
8. M19 — Publicación en App Store, Google Play, Windows y macOS.

Antes de abrir al público: reactivar "Confirm email" y "Allow new users
to sign up" en Supabase, login con Google/Apple, recuperar contraseña y
publicación automática en Netlify (ver BACKLOG.md).

## Cómo actualizar el entorno del usuario (recordatorio)

- `git restore .` + `git pull` en `apps/mobile` (los archivos generados
  bloquean el pull).
- Migraciones: `Get-Content <archivo> -Raw -Encoding UTF8 | Set-Clipboard`
  → Supabase SQL Editor → Run (aplicadas: 0001–0012).
- Funciones: ai-photo, ai-menu, ai-coach (pegar con -Encoding UTF8 y
  revisar la primera línea antes de Deploy).
- Web: `flutter build web --release` → `explorer build` → arrastrar
  `web` a Netlify → magrafit → Deploys (https://magrafit.netlify.app).

## Decisiones tomadas por el usuario

- Tecnología: Flutter (móvil y escritorio).
- Objetivo: vender la app más adelante (cuentas y suscripciones).
- Sin reloj inteligente por ahora; interés en Apple Watch o un anillo
  (Oura, Galaxy Ring). Se integra vía Apple Health / Health Connect.
- Todas las mejoras de docs/01_PRODUCTO.md entran al plan.
- Arquitectura de docs/03_ARQUITECTURA.md APROBADA.

## Decisiones pendientes

- Proyecto Supabase creado (twtkxvbnkxuggsnkihlb, São Paulo).
- Cuenta de la API de Claude creada; clave solo como secreto de Supabase.
- Precio y límites del plan gratis vs premium.
