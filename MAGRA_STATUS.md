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
- U2 — Ejercicios tocables con imágenes: TERMINADO, validación del
  usuario APROBADA. 28 movimientos con fotos de Free Exercise DB (dominio
  público, 56 imágenes reducidas a 600 px, 1,7 MB en assets/exercises),
  ficha en español con fotos que se alternan (inicio/fin), equipo,
  músculos, pasos y errores comunes; miniatura y acceso desde la rutina y
  desde la sesión. Prueba que todo ejercicio del motor tiene ficha.
  analyze sin issues; suite 194/194; build web OK.
- U3 — Calentamiento y estiramiento guiados: TERMINADO, validación del
  usuario APROBADA. warmup.dart: calentamiento (activación, movilidad de lo que
  se entrena, series de aproximación) y vuelta a la calma (estiramientos
  30 s por lado + respiración) según foco (completo/superior/inferior),
  lesiones, impacto y equipo; 18 fotos más (dominio público). Rutina
  guiada paso a paso con fotos animadas, temporizador en anillo, avance
  automático, repeticiones con "Listo", saltar y lista. En Entreno: "1 ·
  Calentar" / "2 · Empezar sesión", botones por día y "Estirar" al
  terminar la sesión. analyze sin issues; suite 200/200; build web OK.
- U4 — Recetas con sazón saludable: TERMINADO, validación del usuario
  APROBADA
  (requiere volver a desplegar ai-menu). Cada plato trae "Sazón
  saludable": 2–5 condimentos, aceites o grasas con cantidad casera y
  consejo (oliva extra virgen, palta, frutos secos, semillas, ajo, comino,
  merkén, limón…; sin margarina, frituras ni cubitos); las grasas con
  calorías se suman a los ingredientes. Plan: "Grasas saludables
  recomendadas" y "Condimentos y sazón" según dieta y alergias. Menús
  anteriores siguen funcionando. analyze sin issues; suite 202/202;
  ai-menu 7 pruebas; build web OK.

- U5 — Pantallas resumidas (opción A, índice con tarjetas): TERMINADO,
  validación del usuario APROBADA. SectionList: subtítulos tocables (chips) que
  abren y llevan a cada sección; cada sección muestra un resumen de una
  línea y se abre/cierra con un toque. Hoy (Comidas abierta; Rachas,
  Ayuno, Ejercicio, Banco), Plan (Comidas y horarios abierta; Por qué,
  Grasas saludables, Condimentos), Progreso (Evaluación abierta;
  Tendencia y ajuste, Fotos, Logros, Historial), Entreno (Rutina de la
  semana abierta; Resumen, Por qué, Cuidados, Cómo progresar). Menús y
  Coach ya estaban divididos (Menú/Compras, chat). analyze sin issues;
  suite 203/203; build web OK. Maqueta:
  https://claude.ai/artifact/4oPHq3QYMfxpxKBftZeK5f
- U6 — Figura anatómica: VALIDADO (22-oct-2026; queda como figura de respaldo). body_map.dart:
  figura vectorial sin rostro de hombre o mujer según el perfil, 16 zonas
  musculares (8 de frente, 8 de espalda), principales en rojo con brillo y
  secundarias en naranja; empieza mirando lo más trabajado y gira con el
  dedo (arrastre), con un toque o con Frente/Espalda/360. En la ficha de
  cada ejercicio y en el calentamiento/estiramiento guiado (músculos por
  ejercicio); miniaturas de la rutina también con la figura. Las fotos
  reales quedan ocultas tras "Ver fotos del movimiento". Sin IA de
  imágenes/3D en este entorno: un 360° real por ejercicio requeriría una
  biblioteca 3D licenciada (BACKLOG). analyze sin issues; suite 206/206;
  build web OK. Reemplazada en la ficha y la rutina guiada por U7 (queda
  como respaldo si un movimiento no tiene animación).
- U7 — Maniquí 3D animado: REEMPLAZADO por U9.
  mannequin.dart: motor 3D propio (cinemática directa + cámara con
  perspectiva, sin dependencias ni licencias) que dibuja un maniquí sin
  rostro de mujer u hombre según el perfil; hace el ejercicio en bucle,
  gira 360° arrastrando el dedo o con Frente/Lado/Espalda, se pausa, y
  pinta en rojo lo que más trabaja y en naranja lo que ayuda. Incluye
  implementos (barra, mancuernas, banco, cajón, prensa, poleas, banda,
  pared, colchoneta). mannequin_poses.dart: animación para todos los
  ejercicios de las fichas y todos los pasos de calentamiento/estiramiento
  (54 animaciones; una prueba exige que no falte ninguna).
  Miniaturas de la rutina con el maniquí quieto. Respeta "reducir
  movimiento" del teléfono. analyze sin issues; suite 212/212; build web OK.
- U8 — Avatar 3D vestido (estilo de la referencia del usuario):
  REEMPLAZADO por U9 (queda como respaldo si falta una imagen). mannequin_render.dart: malla 3D con
  sombreado suave y prueba de profundidad por píxel (rasterizador propio,
  sin dependencias), figura adulta sin rostro con camiseta de manga corta,
  pantalón largo, zapatillas, pelo (moño en la figura femenina), estudio
  oscuro con aro en el piso y acentos cyan (mujer) / coral (hombre). Los
  músculos se tiñen sobre la ropa (se pueden ocultar). Visor: fases
  (inicio, excéntrica, transición, concéntrica; estiramientos: entrar,
  mantener, salir), pausa/reproducir, reiniciar, barra para recorrer paso
  a paso, Frente/Lado/Espalda, giro 360°, elección explícita de figura
  (mujer/hombre; por defecto la del perfil). Reducir movimiento: sin
  animación y con la barra. Si el dibujo falla o el ejercicio no tiene
  animación: figura anatómica estática (resolvedor único demoFor). Cámara
  más alta en ejercicios acostados. analyze sin issues; suite 217/217;
  build web OK. Rendimiento medido en Chromium sin GPU del entorno: dibujo
  ~13 ms por cuadro; la subida de la imagen al GPU emulado limita a ~12–16
  cuadros/s ahí: validar fluidez en el iPhone.
- U9 — Maniquí realista renderizado: VALIDADO por el usuario (22-oct-2026).
  Versión final hiperrealista (aprobada sobre muestra): más tono muscular,
  piel gris tipo escultura, camiseta sin mangas, manos que se cierran sobre
  mangos y barras, zapatillas con suela/cordones, implementos con
  materiales reales (mancuernas hexagonales, barra olímpica con discos,
  bancos tapizados, cajón de madera, poleas, bandas); cuadros de 576 px.
  Reducir movimiento: parte en pausa pero se puede reproducir. tools/avatar: avatar.py arma en Blender un maniquí
  adulto sin rostro y gris a partir de MakeHuman (CC0): camiseta con vivos,
  calzas (mujer) o jogger (hombre), zapatillas, pelo esculpido (moño en la
  mujer). render_demos.py toma las poses exportadas desde la app
  (test/tool/export_demos_test.dart → anims.json) y renderiza cada uno de
  los 54 movimientos en mujer y hombre y en 3 vistas fijas (frente, lado ¾,
  espalda), con implementos, sombras y músculos teñidos, como hojas WebP
  con transparencia en assets/demos (+ miniaturas). App: DemoPlayer
  (demo_player.dart) muestra la hoja según la fase (pausa, vuelta y fundido
  entre cuadros), con pausa/reanudar, reiniciar, barra paso a paso,
  Frente/Lado/Espalda y figura mujer/hombre; reducir movimiento la deja
  quieta con la barra; si falta una imagen usa el maniquí dibujado (U8).
  Se quitó el giro libre (vistas fijas, pedido del usuario).
- U10 — Registro de comidas mejorado: VALIDADO por el usuario (22-oct-2026).
  Base ampliada dentro de la app (food_catalog_extra.dart, valores de
  referencia USDA FoodData Central redondeados): café y bebidas calientes,
  bebidas y jugos, alcoholes (cerveza, vinos, pisco, piscola, tragos),
  snacks, dulces y golosinas, comida rápida chilena y salsas, cada uno con
  su porción casera (taza, lata, copa, corrida, unidad). "Buscar"
  (antes Catálogo) muestra primero "Tus alimentos" —todo lo que el usuario
  ya anotó, por cualquier vía— y luego la base, con filtros por categoría;
  cantidad en porciones o gramos/ml; aviso del alcohol. Si no está: "Crear
  «…»" abre "A mano" con el nombre; "A mano" pide cantidad y unidad y queda
  guardado para la próxima vez. Sin migración (usa food_entries).
- U11 — Sustituir ejercicios: VALIDADO por el usuario (22-oct-2026). Botón
  "Cambiar" en cada ejercicio de la rutina: opciones del mismo patrón de
  movimiento filtradas por equipo y lesiones (exercise_alternatives.dart),
  con ficha y animación; se guardan en exercise_swaps (MIGRACIÓN 0013) y se
  aplican a la rutina, la sesión y el coach; "Volver a …" deshace. Mismas
  series y repeticiones; el progreso del nuevo parte de cero.
- U12 — Editar comidas: VALIDADO por el usuario (22-oct-2026). Tocar un
  alimento registrado abre "Editar alimento" (cantidad recalcula en
  proporción, o nutrientes directos). En el menú semanal, "Editar" cambia
  cantidades, quita o agrega ingredientes de la base y se guarda en el menú;
  "Lo comí" registra la versión editada. Sin migración.
- U13 — GPS y pasos: VALIDADO por el usuario (22-oct-2026). "Correr, caminar o
  bici con GPS" (Hoy → Ejercicio, solo hoy): distancia filtrada (precisión,
  saltos, temblor), tiempo con pausa, ritmo o velocidad, recorrido dibujado,
  MET por velocidad; se guarda como ejercicio con sus km
  (exercise_entries.distance_km, MIGRACIÓN 0014). En el navegador necesita
  pantalla encendida. Pasos: sección "Pasos" con la meta del plan y registro
  manual (daily_steps, migración 0014); conteo automático en la app
  instalada (M10). Dependencia nueva: geolocator.
- U14 — Katch-McArdle: VALIDADO por el usuario (22-oct-2026). Si hay % de
  grasa válido (medidas de cuello/cintura/cadera), el metabolismo basal sale
  de 370 + 21,6 × masa magra; si no, Mifflin-St Jeor. Se aplica al plan, la
  revisión semanal, los logros y Progreso, y se explica cuál se usó.

- U16 — Calorías estables: IMPLEMENTADO, validación PENDIENTE. Una sola
  meta en toda la app (weekly_basis.dart → weeklyNutrition): se calcula el
  lunes con el peso promedio de la semana pasada y el mejor % de grasa
  (profesional > medidas); no cambia con cada pesaje. Progreso ahora
  incluye el ajuste semanal (antes mostraba otra cifra). El ejercicio se
  muestra aparte ("+X por tu ejercicio") y no mueve la meta.
- U15 — Evaluación corporal con foto: EN CURSO.
- U17 — Coach motivador y seguimiento (avisos): PENDIENTE.

## Mejoras U7–U14 cerradas (22-oct-2026)

Todas validadas por el usuario. Se retoma la hoja de ruta en M18.

## Próximos pasos (hoja de ruta acordada)

1. M18 — Legal: términos, política de privacidad, consentimiento al
   crear la cuenta, exportar datos y borrar la cuenta con todo su
   contenido (obligatorio antes de vender: datos de salud).
2. M20 — PDF para el nutricionista (medidas, evolución, plan, registro).
3. Preparar compilación nativa: cuenta Apple Developer (US$99/año) +
   Codemagic (no hay Mac); Android con APK.
4. M10 — Apple Health / Health Connect (requiere app nativa).
5. M14 — Notificaciones (requiere app nativa).
6. M17 — Suscripciones con RevenueCat, gratis vs premium.
7. M19 — Publicación en App Store, Google Play, Windows y macOS.

Antes de abrir al público: reactivar "Confirm email" y "Allow new users
to sign up" en Supabase, login con Google/Apple, recuperar contraseña y
publicación automática en Netlify (ver BACKLOG.md).

## Cómo actualizar el entorno del usuario (recordatorio)

- `git restore .` + `git pull` en `apps/mobile` (los archivos generados
  bloquean el pull).
- Migraciones: `Get-Content <archivo> -Raw -Encoding UTF8 | Set-Clipboard`
  → Supabase SQL Editor → Run (aplicadas: 0001–0014).
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
