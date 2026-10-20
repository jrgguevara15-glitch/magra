# BACKLOG

Ideas registradas para bloques futuros. No se implementan en el bloque
activo.

- Evaluación: si la medición no trae cuello y cintura, avisar "Agrega cuello
  y cintura para ver tu % de grasa, masa magra y meta" (detectado en la
  prueba del M2; pendiente de aprobación del usuario).
- % grasa como estimación: la fórmula de la Marina pierde precisión con
  cinturas muy grandes (±3–4 puntos); apoyarse en tendencia de cintura y peso.

- Días bajos en carbohidratos: el motor M4 no los usa. Decidir por reglas a
  quién le convienen (p. ej. glucosa alterada) y quitar el valor por
  defecto martes/jueves del perfil, que venía del plan de referencia.
- `portionScale` del M1 supone 4 comidas; el M4/M5 calculan porciones
  directo por gramos de macronutriente. Evaluar eliminarlo.
- Unificar `referenceFoods` (M4) con `foodCatalog` (M5): hoy son dos listas
  con los mismos alimentos.
- Registro: editar un alimento ya anotado, alimentos recientes y favoritos,
  "repetir comida de ayer" y marcar una comida del plan como "comí lo
  sugerido".
- Proteína: hoy es el % del perfil (30 %). Evaluar fijarla por g/kg de masa
  magra (≈ 2 g/kg en déficit) como haría un nutricionista deportivo.
- Explicaciones del plan redactadas por IA (Coach, M15) sobre los números
  que fija el motor.
- Catálogo de alimentos: completar valores por 100 g con tabla chilena
  (INTA) en vez de valores genéricos.
- Soporte de mujeres en el plan base de intercambios (hoy escalado desde un
  plan masculino).
- Modo nutricionista: el profesional ve el progreso de sus pacientes
  (posible canal de venta B2B).
- Prototipo web (Fase 1): alinear la clasificación de % grasa con el margen
  calibrado en M1 (tope + 7; el prototipo usa tope + 6) y quitarle los
  datos precargados del fundador (debe partir vacío como la app).
- El catálogo de alimentos del prototipo (valores por 100 g y marcas) pasa
  a la app en M3.
- Antes de publicar: reactivar "Confirm email" en Supabase y configurar la
  URL de redirección y los correos en español.
- Inicio de sesión con Google y Apple; recuperar contraseña.
- Migraciones con Supabase CLI en vez de pegarlas en el SQL Editor.
- Foto de la carta de un restaurante (qué pedir y qué evitar), como en el
  prototipo web.
- Límite de fotos por plan (gratis/premium) en M17; hoy es 25/día para
  todos.
- Consentimiento formal y guardado para enviar fotos a la IA (M18); hoy se
  informa en la pantalla antes de elegir la foto.
- iPhone: hoy se prueba en Safari por Wi-Fi. Para la app nativa en iPhone
  (y TestFlight/App Store) se necesita una Mac o compilar en la nube
  (Codemagic) más la cuenta de Apple Developer (US$99/año).
- Ejercicio: actividad libre con calorías del reloj, más actividades en el
  catálogo MET y repetir el entreno de la semana pasada. Con M10 (Apple
  Health / Health Connect) se importa automáticamente.
- Ayuno: notificación al cumplir la meta (requiere notificaciones locales)
  e historial/racha de ayunos.
- Ajuste semanal: cambiar la decisión de la semana, restablecer el
  acumulado y recordatorio de pesaje (lunes).
- Gráfico de cintura junto al de peso y rango de fechas elegible.
- Código de barras: guardar los productos escaneados como recientes, y
  aportar a Open Food Facts los productos que no estén.
- Escáner en vivo en iPhone/Safari requiere https (o la app nativa); hoy
  se escriben los números.
- Texto "Agregar 1 alimentos": usar singular cuando es 1.
- Código no encontrado (aprobado por el usuario): botón directo
  "Fotografiar la etiqueta" y guardar ese código con sus nutrientes para
  encontrarlo al instante la próxima vez (base propia de MAGRA).
- Orden sugerido: M10 (salud) y M14 (notificaciones) solo funcionan en la
  app nativa; antes hace falta compilar para iPhone (Mac o Codemagic +
  Apple Developer) o Android.
