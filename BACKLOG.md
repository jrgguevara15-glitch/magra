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
