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
en el código de evaluación.

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
