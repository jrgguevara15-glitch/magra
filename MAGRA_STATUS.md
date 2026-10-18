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
- M2 — Supabase (cuentas, perfil, mediciones): IMPLEMENTADO, validación del
  usuario PENDIENTE. Migración + RLS validadas en Postgres local; inicio de
  sesión con correo, perfil, mediciones y evaluación en Progreso.
  analyze sin issues; suite 44/44; build web OK.
- M3 a M7 — NO ABIERTOS.

## Decisiones tomadas por el usuario

- Tecnología: Flutter (móvil y escritorio).
- Objetivo: vender la app más adelante (cuentas y suscripciones).
- Sin reloj inteligente por ahora; interés en Apple Watch o un anillo
  (Oura, Galaxy Ring). Se integra vía Apple Health / Health Connect.
- Todas las mejoras de docs/01_PRODUCTO.md entran al plan.
- Arquitectura de docs/03_ARQUITECTURA.md APROBADA.

## Decisiones pendientes

- Proyecto Supabase creado (twtkxvbnkxuggsnkihlb, São Paulo).
- Pendiente: cuenta de la API de Claude (para M4).
- Precio y límites del plan gratis vs premium.
