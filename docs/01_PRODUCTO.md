# 01 — Producto

## Propuesta

MAGRA ayuda a perder grasa sin perder músculo. Combina el método de un
nutricionista deportivo (sistema de intercambios, déficit calórico,
fuerza + cardio) con IA que reduce la fricción de registrar y ajusta el
plan con datos reales.

Usuario: cualquier persona que quiere bajar grasa. Ingresa sus datos
(perfil y medidas) y MAGRA hace la evaluación y le recomienda plan
nutricional y entrenamiento. Objetivo comercial: venderla como suscripción.

Los informes de un nutricionista deportivo (2021–2022) entregados por el
fundador son material de referencia del método y de verificación de las
fórmulas. No son datos de la app ni se cargan en ninguna cuenta.

## Módulos

### 1. Registro de comidas
- **Foto → calorías**: la IA identifica alimentos y gramos en la foto del
  plato; el usuario corrige antes de guardar; se descuenta de la meta.
- Modos de foto: plato, carta de restaurante (qué pedir/evitar), etiqueta
  nutricional.
- **Código de barras** (Open Food Facts, cubre productos chilenos).
- **Voz**: "almorcé arroz con pollo y ensalada".
- Texto libre estimado por IA.
- Lista de intercambios del plan con porción sugerida del día.

### 2. Plan nutricional (método de intercambios)
- 4 comidas/día: 1 carbohidrato + 1 proteína + 1 lípido + 2–3 vegetales.
- Porciones escaladas desde el plan base del nutricionista hacia la meta
  calórica actual (ver 02_FORMULAS).
- **Días sin carbohidratos** configurables (por defecto martes y jueves).
- **Ayuno intermitente** 12:12 / 14:10 / 16:8 con temporizador y avisos.
  Nunca se proponen ayunos > 24 h.

### 3. Menús y compras
- Menú semanal automático con marcas de supermercados chilenos.
- Personalización con IA según preferencias, presupuesto y horarios.
- "Cambiar" una comida por otra equivalente; "Lo comí" la registra.
- Lista de compras agregada de la semana.
- Modo restaurante / fin de semana: banco de calorías semanal.

### 4. Ejercicio
- Calorías por actividad con MET y peso actual; se recupera solo 50 %.
- Plan de fuerza + cardio (45 + 45 min, mínimo 3 días) generado según días,
  nivel y equipo.
- **Rutinas adaptativas**: progresión de carga por sesión y por grupo
  muscular descansado.
- Integración con Apple Health (HealthKit) y Health Connect (Android):
  pasos, entrenos, frecuencia cardíaca y sueño de cualquier reloj o anillo
  (Apple Watch, Oura, Galaxy Ring…).

### 5. Evaluación y evolución
- Medidas (peso, cuello, cintura, cadera) → % grasa, masa grasa y magra,
  IMC, IMCM, cintura/estatura, meta física.
- **Peso de tendencia** (filtra variaciones diarias).
- **Gasto adaptativo**: estima el gasto real cruzando lo que come y la
  tendencia de peso, y ajusta la meta semanalmente.
- Fotos de progreso mensuales comparadas lado a lado.
- Exportar PDF para el nutricionista.

### 6. Coach IA
- Evaluación con todos los datos y ajustes concretos.
- Revisión semanal automática (domingo).
- Chat libre con contexto del usuario.
- Recordatorios útiles: proteína pendiente, pesaje, fin de ayuno.

### 7. Motivación
- Rachas de registro, logros (ej. −5 kg de grasa, 30 días de proteína).
- Semáforo de densidad calórica de alimentos.
- Agua, sueño y estrés como contexto del hambre.

## Comercial (para vender)
- Cuentas de usuario (correo, Apple, Google).
- Suscripción mensual/anual vía App Store y Google Play (RevenueCat).
- Plan gratis limitado (ej. 3 fotos IA por día) y plan premium.
- Cumplimiento de la ley chilena de datos personales: datos de salud son
  sensibles; consentimiento explícito, exportación y borrado de cuenta.
- Aviso: MAGRA orienta, no reemplaza a profesionales de salud.
