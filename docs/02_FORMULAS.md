# 02 — Fórmulas

Todas verificadas contra los informes del nutricionista (Magic Formula,
2021–2022) salvo donde se indica.

## Composición corporal

**% grasa — Marina de EE. UU.** (cm)

- Hombre: `495 / (1.0324 − 0.19077·log10(cintura − cuello) + 0.15456·log10(estatura)) − 450`
- Mujer: `495 / (1.29579 − 0.35004·log10(cintura + cadera − cuello) + 0.22100·log10(estatura)) − 450`

Verificación (180 cm): 112/46 → 28,79 %; 109/45 → 27,61 %; 107/45 → 26,40 %;
105/44 → 25,78 %. Coinciden con el informe.

Discrepancia conocida: el informe del 23-feb-2022 reporta 18,74 % con
102/44, pero la fórmula da 23,88 %. La app usa el valor calculado y muestra
el reportado como referencia.

- Masa grasa = peso × %grasa / 100
- Masa magra = peso − masa grasa
- IMC = peso / estatura(m)²
- IMCM = masa magra / estatura(m)²
- Cintura/estatura: < 0,5 riesgo bajo; 0,5–0,6 elevado; ≥ 0,6 alto.

Tablas de referencia (OMS por edad; IMCM de Eston, Hawes, Martin y Reilly)
en `lib/core/formulas/body_composition.dart`.

Clasificación del % grasa: bajo < mínimo OMS; saludable hasta el tope OMS;
alto hasta tope + 7; muy alto sobre eso. El margen de 7 se calibró con los
encabezados de los planes del nutricionista (hombre 35 años, tope 19 %):
26,40 → Muy alto; 25,78 → Alto; feb-2022 → Alto (coherente con 23,88 % de
la fórmula, no con el 18,74 % informado).

## Energía

- **TMB — Mifflin-St Jeor**: `10·peso + 6,25·estatura − 5·edad + 5`
  (hombre; mujer −161). Verificado: 110,9 kg, 180 cm, 35 años → 2.064.
- **Gasto** = TMB × factor de actividad (1,2 sedentario; usado por el nutri).
- **Meta** = gasto − déficit; déficit = ritmo(kg/semana) × 1.000 kcal/día.
  Verificado: 2.064 × 1,2 − 500 = 1.976,8.
- Piso de seguridad: 1.500 kcal hombre, 1.200 mujer.

## Macros

- Día normal: P30 / C45 / L25 (último plan). P y C a 4 kcal/g, L a 9 kcal/g.
- Día sin carbohidratos: sin carbohidratos; proteína y lípido × 1,25;
  vegetales × 1,5. ≈ 1.500 kcal con la meta base de ~1.950.

## Porciones (intercambios)

Base: plan del 24-feb-2022 (1.976,8 kcal, P30/C45/L25, 100 kcal de
vegetales). Para cada grupo:

```
kcal_grupo_por_comida = (meta × %macro − kcal_vegetales_si_carb) / 4
escala = kcal_grupo_nueva / kcal_grupo_base
porción = porción_base × escala  (redondeo a 5 g)
```

## Ejercicio

- `kcal netas = (MET − 1) × peso(kg) × horas` (el reposo ya está en la TMB).
- Se suma el 50 % a la meta del día (Hoy: "meta + N por ejercicio"); los
  macros objetivo no cambian. Se guarda con el peso del momento.
- MET del Compendio de Actividad Física (pesas 3,5/6; caminar 3,5–6;
  bici 6,8/8,8; fútbol 7/10; etc.).
- Zona 2: 60–70 % de FC máx; FC máx = 208 − 0,7 × edad.

## Meta física

- Peso meta = masa magra / (1 − %grasa meta).
- Grasa a eliminar = peso − peso meta.
- Calorías a oxidar = grasa × 7.700 kcal/kg (el nutri usaba ~9.000).
- Tiempo = calorías / (déficit diario × 7) semanas.

## Tendencia y ajuste (versión actual)

- Regresión lineal del peso de los últimos 28 días (≥ 3 pesajes).
- Pérdida > 1 % del peso/semana → +150 kcal.
- Pérdida < 50 % del ritmo meta → revisar registro; si se repite 2 semanas,
  −100 a −150 kcal o +2.000 pasos.

## Peso de tendencia, gasto real y ajuste semanal (M8)

Código: `lib/core/formulas/trend.dart` y
`lib/core/recommendation/weekly_adjustment.dart`.

- **Peso de tendencia**: un punto por día, interpolando los días sin
  pesaje, con media móvil exponencial α = 0,1. Gráfico de 90 días en
  Progreso (pesajes + línea).
- **Gasto real** = ingesta promedio − pendiente(kg/sem) × 7.700 / 7.
  Ventana: 21 días sin contar hoy. Un día cuenta si tiene ≥ 60 % del mínimo
  seguro registrado. Requiere ≥ 10 días y ≥ 3 pesajes que abarquen
  ≥ 10 días; fuera de 1.000–6.000 kcal se descarta.
- **Ajuste semanal** (semana desde el lunes; el usuario aplica o dice
  "Ahora no"; una decisión por semana):
  - Condición supervisada: nunca se ajusta. Sin 3 pesajes en 28 días: no.
  - Pérdida > 1 % del peso/semana: +150.
  - En ritmo: 0.
  - Lenta (< 50 % del ritmo meta):
    - si la ingesta registrada supera la meta en > 150: 0 y "ajústate al
      plan";
    - con gasto real: hasta (gasto real − ritmo × 1.000) − meta actual,
      máximo −150, redondeado a 10;
    - sin gasto real: la 1.ª semana espera (+2.000 pasos); si la semana
      anterior también era lenta, −100.
  - Nunca deja la meta bajo el mínimo seguro; el acumulado se limita a
    ±500 kcal sobre la fórmula.
- La meta del Plan y de Hoy = fórmula + ajustes aplicados (macros
  escalados, sin bajar del mínimo seguro).

## Rutinas adaptativas (M12)

Código: `lib/core/recommendation/progression.dart`.

- Series de trabajo y rango: principiante 2 × 10–12, intermedio 3 × 8–12,
  avanzado 4 × 6–10.
- Carga de trabajo = la mayor de la sesión (el calentamiento no cuenta).
- Doble progresión: si todas las series llegan al tope del rango, +2,5 kg
  en sentadilla y bisagra, +1 kg en el resto (o el siguiente disponible) y
  se vuelve al mínimo; si no, misma carga y una repetición más que la
  serie más baja.
- 3 sesiones seguidas bajo el mínimo con la misma carga → descarga del
  10 % (redondeo a 0,5 kg).
- Peso corporal y core: al tope, más repeticiones o variante más difícil.
- Sesión que toca: la siguiente de la rotación (A/B o superior/inferior)
  después de la última registrada.
- Al terminar, los minutos de fuerza van a Ejercicio en Hoy como pesas
  moderadas (intensas si es avanzado), con el peso actual.

## Motivación (M16)

Código: `lib/core/recommendation/motivation.dart`.

- Día registrado: ≥ 60 % del mínimo seguro anotado. Día con proteína:
  ≥ 90 % de la meta. Rachas hasta hoy; si hoy aún no cumple, hasta ayer.
- Semanas entrenando: semanas (lunes) con las sesiones del plan; la
  semana en curso cuenta solo si ya se cumplió.
- Semáforo (kcal por g): verde < 1,5, amarillo ≤ 4, rojo > 4. Líquidos
  (kcal por ml): verde ≤ 0,2, amarillo ≤ 0,4, rojo > 0,4. Con ≥ 10 g de
  proteína por 100 kcal sube un nivel. En unidades no se calcula.
- Banco: por cada día de la semana (lunes a ayer) registrado, comiendo
  bajo la meta y sin bajar del mínimo seguro, guarda la diferencia (máx.
  150/día); se descuenta lo usado; se usa hasta 500 en un día; no pasa a
  la semana siguiente. No aplica con plan de mantención.
- Logros: rachas de registro (7/30) y proteína (7), grasa (−1/−5 kg),
  peso (−5 kg), cintura (−5 cm), primera etapa (−10 % del peso),
  entrenos (10/50), fotos (primeras y 2 meses).

## Menú semanal (M11)

- El motor fija las comidas (hora, papel respecto del entreno, kcal y
  macros de cada una). La IA solo elige platos e ingredientes que sumen
  esa meta (±10 %) sin alergias ni alimentos que no le gustan, con su
  presupuesto y cuánto cocina.
- Variedad: proteína principal del almuerzo rota por día según la dieta
  (omnívoro: pollo, vacuno magro, pescado, legumbres, cerdo magro, pavo,
  huevo/vacuno). "Cambiar" pide otra comida evitando los platos de la
  semana.
- Lista de compras = suma de ingredientes de los 7 días (mismo nombre sin
  tildes y unidad), por sección del supermercado; g → kg y ml → L sobre
  1.000; unidades hacia arriba.
- Si el plan cambia (otro n.º de comidas o ±5 % de kcal) se avisa que el
  menú quedó desactualizado.
- Sazón saludable (U4): cada comida trae 2–5 condimentos o grasas con
  cantidad casera; aceites, palta, frutos secos y semillas también se
  cuentan en los ingredientes.

## Motor de recomendación (M4)

Código: `lib/core/recommendation/`. Reglas puras con pruebas.

### Salud
- Condición supervisada (diabetes tipo 1, enfermedad cardíaca o renal,
  embarazo, lactancia, TCA): **sin déficit**, plan de mantención y aviso.
- IMC ≥ 35 o cintura/estatura ≥ 0,6: recomendar control médico.
- Diabetes tipo 2/prediabetes, hipertensión, ≥ 65 años: avisos específicos.

### Meta por etapas
- Etapa 1 = 10 % del peso actual; tiempo = kg × 7.700 / (déficit × 7).
- Meta final = masa magra / (1 − % grasa meta). Si está a menos del 10 %,
  una sola etapa.

### Comidas
- Toma de proteína ideal = 0,4 g/kg de peso, entre 25 y 45 g (≥ 50 años:
  mínimo 35 g). Comidas = proteína diaria / toma, entre 3 y 5.
- Mínimo para no pasar más de 5 h sin comer: ⌈(horas despierto − 3) / 5⌉ + 1.
- < 1.600 kcal: 3 comidas si el horario lo permite. < 14 h despierto: máx. 4.
- Preferencia del usuario manda (2–6), salvo glucosa (diabetes,
  hipoglicemia): mínimo 4 y sin ayuno.
- Ayuno 16:8 solo si lo pide y no hay glucosa alterada, TCA, condición
  supervisada ni ≥ 65 años: 2–3 comidas, ventana que termina 3 h antes de
  dormir.
- Temporizador (Hoy, M7): protocolos 12:12, 14:10 y 16:8; sugiere el del
  plan (16:8 si incluye ayuno) o 12:12. Solo se muestra si no eligió "No
  quiero ayunar"; si una regla lo impide y lo pidió, explica por qué. Meta
  cumplida → romperlo con proteína; ≥ 24 h → aviso de comer ya. Un solo
  ayuno en curso; se puede fijar la hora de la última comida.
- Horario: primera comida 30 min después de despertar; última 2,5 h antes
  de dormir; ninguna durante el entreno; una antes (1–4 h) y otra dentro de
  las 2 h después.
- Reparto: proteína pareja; carbohidratos ×1,5 post-entreno, ×1,3
  pre-entreno, ×0,7 última comida; grasa ×0,6–0,7 cerca del entreno.
- Ejemplos de alimentos filtrados por dieta, alergias y alimentos que no le
  gustan; porciones caseras hasta 4 unidades.

### Entrenamiento
- 0 días → 2; 7 días → 6. 1–3 días: cuerpo completo A/B; 4–6: superior/
  inferior.
- Sesión: 60 % fuerza (20–60 min) y el resto cardio (mínimo 10 min).
- Series según experiencia (2–3 × 10–12 a 4 × 6–10, con repeticiones en
  reserva).
- Bajo impacto si IMC ≥ 30, rodillas/tobillos/caderas o ≥ 60 años.
- Reemplazos por lesión (rodilla, espalda baja, hombro, cadera, tobillo,
  muñeca, cuello). Pasos: 6.000 (IMC ≥ 35) o 7.000, +1.000 cada 2 semanas.
