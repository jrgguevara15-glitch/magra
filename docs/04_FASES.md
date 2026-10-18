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
| M3 | Cuestionario completo: horarios, entrenamiento, experiencia, lesiones, equipo, gustos, alergias, salud, ayuno, presupuesto |
| M4 | Motor de recomendación: plan nutricional (n.º de comidas 2–6, horarios, qué comer, porciones) y plan de entrenamiento, con explicación |
| M5 | Registro del día con catálogo de intercambios y porciones |
| M6 | Foto → calorías (Edge Function `ai-photo` + revisión editable) |
| M7 | Ejercicio MET + ayuno con avisos |
| M8 | Peso de tendencia + gasto adaptativo semanal |
| M9 | Código de barras (Open Food Facts) y registro por voz |

Orden aprobado por el usuario: primero que MAGRA evalúe y recomiende
(M3–M4), después el registro diario.

## Fase 3 — Conectado

| Bloque | Contenido |
|---|---|
| M10 | Apple Health / Health Connect (pasos, entrenos, sueño, FC) |
| M11 | Menús semanales con IA + lista de compras |
| M12 | Rutinas adaptativas de fuerza |
| M13 | Fotos de progreso y comparador |
| M14 | Notificaciones inteligentes |

## Fase 4 — Producto vendible

| Bloque | Contenido |
|---|---|
| M15 | Coach IA: chat y revisión semanal |
| M16 | Rachas, logros, semáforo de alimentos, banco de calorías |
| M17 | Suscripciones (RevenueCat), plan gratis vs premium |
| M18 | Legal: consentimiento, exportar/borrar cuenta, textos |
| M19 | Publicación en App Store, Google Play, Windows y macOS |
| M20 | PDF para compartir con un profesional |
