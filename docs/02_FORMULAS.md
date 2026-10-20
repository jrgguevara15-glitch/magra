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
- Se suma el 50 % a la meta del día.
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

## Gasto adaptativo (por implementar, Fase 2)

Gasto real ≈ kcal ingeridas promedio − (Δ peso tendencia × 7.700 / días).
Media móvil exponencial del peso (α ≈ 0,1) como peso de tendencia. Ajuste
semanal de la meta con límite de ±150 kcal por semana.

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
