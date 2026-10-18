# 04 — Fases y bloques

Cada bloque se cierra con `flutter analyze` limpio, pruebas y validación
funcional del usuario (AGENTS.md).

## Fase 1 — Prototipo web (TERMINADA, en validación del usuario)

Artifact privado de Claude: registro, foto→calorías, plan de intercambios,
días sin carbohidratos, ayuno, ejercicio MET, menús con marcas, lista de
compras, evaluación, evolución, entrenamiento y coach IA.

## Fase 2 — Núcleo nativo

| Bloque | Contenido |
|---|---|
| M0 | Scaffolding Flutter + tema MAGRA + navegación por pestañas |
| M1 | Fórmulas puras en `core/` con pruebas contra valores del nutri |
| M2 | Supabase: proyecto, auth, tablas + RLS, perfil y mediciones |
| M3 | Registro del día con catálogo de intercambios y porciones |
| M4 | Foto → calorías (Edge Function `ai-photo` + revisión editable) |
| M5 | Ejercicio MET + días sin carbohidratos + ayuno con avisos |
| M6 | Peso de tendencia + gasto adaptativo semanal |
| M7 | Código de barras (Open Food Facts) y registro por voz |

## Fase 3 — Conectado

| Bloque | Contenido |
|---|---|
| M8 | Apple Health / Health Connect (pasos, entrenos, sueño, FC) |
| M9 | Menús semanales con IA + lista de compras |
| M10 | Rutinas adaptativas de fuerza |
| M11 | Fotos de progreso y comparador |
| M12 | Notificaciones inteligentes |

## Fase 4 — Producto vendible

| Bloque | Contenido |
|---|---|
| M13 | Coach IA: chat y revisión semanal |
| M14 | Rachas, logros, semáforo de alimentos, banco de calorías |
| M15 | Suscripciones (RevenueCat), plan gratis vs premium |
| M16 | Legal: consentimiento, exportar/borrar cuenta, textos |
| M17 | Publicación en App Store, Google Play, Windows y macOS |
| M18 | PDF para el nutricionista |
