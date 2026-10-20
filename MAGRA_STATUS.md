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
- M8 en adelante — NO ABIERTOS.

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
