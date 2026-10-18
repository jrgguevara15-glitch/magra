# 03 — Arquitectura

Estado: **APROBADA por el usuario.** Cualquier cambio a estas decisiones
requiere autorización (ver AGENTS.md).

## Vista general

```
App Flutter (Android · iOS · Windows · macOS · web)
   │  Supabase Auth (correo, Apple, Google)
   ▼
Supabase
   ├─ Postgres + Row Level Security (cada usuario ve solo lo suyo)
   ├─ Storage (fotos de comidas y de progreso, privadas)
   └─ Edge Functions (TypeScript/Deno)
         └─ ai-*  →  API de Claude (clave solo aquí, como secreto)
RevenueCat  ←→  App Store / Google Play (suscripciones)
Open Food Facts (código de barras, sin clave)
HealthKit / Health Connect (en el dispositivo, paquete `health`)
```

## App Flutter (`apps/mobile`)

| Tema | Elección | Motivo |
|---|---|---|
| Estado | Riverpod | Testeable, sin contexto global |
| Navegación | go_router | Deep links y rutas por pestaña |
| Backend | supabase_flutter | Auth + datos + storage |
| Caché offline | drift (SQLite) | Registrar comidas sin señal |
| Cámara/archivos | image_picker | Foto del plato en todas las plataformas |
| Código de barras | mobile_scanner | Android/iOS |
| Salud | health | HealthKit + Health Connect |
| Notificaciones | flutter_local_notifications | Ayuno, pesaje, proteína |
| Pagos | purchases_flutter (RevenueCat) | Suscripciones en ambas tiendas |
| Gráficos | fl_chart | Evolución corporal |

Organización por funcionalidad:

```
lib/
  core/        tema, router, fórmulas puras (sin dependencias de UI)
  features/
    today/     registro del día, foto, ejercicio, ayuno
    plan/      intercambios y porciones
    menus/     menú semanal y compras
    progress/  evolución y evaluación
    training/  plan de entrenamiento
    coach/     IA
    profile/   perfil y ajustes
```

Las fórmulas (02_FORMULAS) viven en `core/` como funciones puras con
pruebas unitarias contra los valores verificados del nutricionista.

## IA (Edge Functions → API de Claude)

- SDK oficial `@anthropic-ai/sdk` dentro de Edge Functions (TypeScript).
- Modelo por defecto: `claude-opus-5-5` (visión, JSON y chat).
- Salidas estructuradas (`output_config.format`) para foto→items y menús.
- Funciones previstas: `ai-photo` (plato, carta, etiqueta), `ai-menu`,
  `ai-coach` (evaluación y chat), `ai-text-food`.
- Costo estimado por foto con `claude-opus-5-5` ($4 / $20 por millón de
  tokens de entrada/salida): ~1.500 tokens de entrada + ~500 de salida ≈
  **US$0,016**. Cambiar a un modelo más barato es decisión del usuario.
- Límite por plan (gratis/premium) aplicado en la función, no en la app.

## Datos (Postgres, todas las tablas con `user_id` + RLS)

`profiles`, `measurements`, `food_entries`, `foods` (catálogo + propios),
`workouts`, `fasts`, `menus`, `shopping_checks`, `ai_reports`,
`progress_photos`, `subscriptions` (espejo de RevenueCat).

## Seguridad y legal

- Datos de salud: sensibles. RLS obligatorio, storage privado, borrado y
  exportación de cuenta desde la app.
- Ninguna clave en la app. Secretos en Supabase.
- Consentimiento explícito antes de enviar fotos a la IA.
