# BACKLOG

Ideas registradas para bloques futuros. No se implementan en el bloque
activo.

- Evaluación: si la medición no trae cuello y cintura, avisar "Agrega cuello
  y cintura para ver tu % de grasa, masa magra y meta" (detectado en la
  prueba del M2; pendiente de aprobación del usuario).
- M4 · metas por etapas: primera meta ~10 % del peso, luego la siguiente,
  en vez de una sola meta lejana (caso de prueba: 123 kg → 13,4 meses).
- M4 · alerta de salud: con cintura/estatura ≥ 0,6 o IMC ≥ 35 recomendar
  control médico (presión, glucosa, colesterol).
- M4 · % grasa como estimación: la fórmula de la Marina pierde precisión con
  cinturas muy grandes (±3–4 puntos); apoyarse en tendencia de cintura y peso.

- M4: generalizar `portionScale` (M1 supone 4 comidas) a 2–6 comidas y
  decidir por reglas si un usuario lleva días bajos en carbohidratos y cómo
  se reparten sus calorías.
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
