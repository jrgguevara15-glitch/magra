import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/formulas/formulas.dart';

/// Mediciones reales de informes de un nutricionista deportivo (referencia),
/// estatura 180 cm, hombre: (peso, cuello, cintura, % grasa informado).
const nutritionistReports = <(double, double, double, double)>[
  (116.4, 46, 112, 28.79), // 2-ago-2021
  (114.8, 45, 109, 27.61), // 8-sep-2021
  (114.6, 45, 107, 26.40), // 6-oct-2021
  (110.9, 44, 105, 25.78), // 17-dic-2021
];

void main() {
  group('Composición corporal', () {
    test('% grasa (Marina EE. UU.) igual a los 4 informes del nutricionista',
        () {
      for (final (_, neck, waist, reported) in nutritionistReports) {
        final pct = bodyFatNavy(
          sex: Sex.male,
          heightCm: 180,
          neckCm: neck,
          waistCm: waist,
        );
        expect(pct, closeTo(reported, 0.01), reason: 'cintura $waist');
      }
    });

    test('feb-2022: la fórmula da 23,88 %, no el 18,74 % informado', () {
      final pct = bodyFatNavy(
          sex: Sex.male, heightCm: 180, neckCm: 44, waistCm: 102);
      expect(pct, closeTo(23.88, 0.01));
    });

    test('masa grasa, magra, IMC e IMCM del 2-ago-2021', () {
      final c = BodyComposition.from(
        sex: Sex.male,
        heightCm: 180,
        weightKg: 116.4,
        neckCm: 46,
        waistCm: 112,
      );
      // Informe: IMC 35,93; peso graso 33,51; peso magro 82,89; IMCM 25,58.
      expect(c.bmi, closeTo(35.93, 0.01));
      expect(c.fatKg, closeTo(33.51, 0.01));
      expect(c.leanKg, closeTo(82.89, 0.01));
      expect(c.imcm, closeTo(25.58, 0.01));
      expect(c.waistToHeight, closeTo(0.622, 0.001));
    });

    test('índice magro de dic-2021 = 25,40 (informe)', () {
      final c = BodyComposition.from(
        sex: Sex.male,
        heightCm: 180,
        weightKg: 110.9,
        neckCm: 44,
        waistCm: 105,
      );
      expect(c.fatKg, closeTo(28.59, 0.01));
      expect(c.leanKg, closeTo(82.31, 0.01));
      expect(c.imcm, closeTo(25.40, 0.01));
    });

    test('sin medidas no inventa % grasa', () {
      final c =
          BodyComposition.from(sex: Sex.male, heightCm: 180, weightKg: 110);
      expect(c.fatPct, isNull);
      expect(c.leanKg, isNull);
      expect(c.imcm, isNull);
    });

    test('mujer sin cadera o cintura ≤ cuello devuelve null', () {
      expect(
          bodyFatNavy(
              sex: Sex.female, heightCm: 165, neckCm: 33, waistCm: 80),
          isNull);
      expect(
          bodyFatNavy(sex: Sex.male, heightCm: 180, neckCm: 44, waistCm: 44),
          isNull);
    });

    test('% grasa mujer con cadera', () {
      final pct = bodyFatNavy(
          sex: Sex.female,
          heightCm: 165,
          neckCm: 33,
          waistCm: 80,
          hipCm: 100);
      // 495 / (1,29579 − 0,35004·log(147) + 0,221·log(165)) − 450
      expect(pct, closeTo(31.89, 0.01));
    });

    test('clasificaciones', () {
      expect(bmiRating(34.23), const Rating('Obesidad tipo I', Severity.bad));
      expect(bmiRating(22), const Rating('Normal', Severity.good));
      // Tablas del informe: hombre 31–40 años, meta 13–19 %.
      expect(omsFatRangeFor(35).forSex(Sex.male), (13, 19));
      expect(fatRating(Sex.male, 35, 16).severity, Severity.good);
      // Clasificación de los encabezados de los planes del nutricionista.
      expect(fatRating(Sex.male, 35, 26.40).label, 'Muy alto'); // oct-2021
      expect(fatRating(Sex.male, 35, 25.78).label, 'Alto'); // dic-2021
      expect(fatRating(Sex.male, 35, 23.88).label, 'Alto'); // feb-2022
      expect(bmiRating(35.37).label, 'Obesidad tipo II'); // oct-2021
      // IMCM hombre: definido 21–24, superior > 25 (meta del informe).
      expect(imcmRating(Sex.male, 25.58).label, 'Nivel superior');
      expect(imcmRating(Sex.male, 22).label, 'Definido');
      expect(waistToHeightRating(0.62).severity, Severity.bad);
    });
  });

  group('Energía', () {
    test('TMB Mifflin-St Jeor = 2.064 kcal (plan del nutricionista)', () {
      expect(
        bmrMifflin(sex: Sex.male, weightKg: 110.9, heightCm: 180, age: 35),
        closeTo(2064, 0.01),
      );
    });

    test('meta para bajar 0,5 kg/semana = 1.976,8 kcal', () {
      final t = energyTarget(
          sex: Sex.male, weightKg: 110.9, heightCm: 180, age: 35);
      expect(t.kcal, closeTo(1976.8, 0.01));
      expect(t.deficit, closeTo(500, 0.01));
      expect(t.floorApplied, isFalse);
    });

    test('macros P30 / C45 / L25 en gramos', () {
      final t = energyTarget(
          sex: Sex.male, weightKg: 110.9, heightCm: 180, age: 35);
      expect(t.grams.protein, closeTo(148.26, 0.01));
      expect(t.grams.carbs, closeTo(222.39, 0.01));
      expect(t.grams.lipids, closeTo(54.91, 0.01));
    });

    test('día sin carbohidratos: ~1.500 kcal y más déficit', () {
      final normal = energyTarget(
          sex: Sex.male, weightKg: 110.9, heightCm: 180, age: 35);
      final low = energyTarget(
          sex: Sex.male,
          weightKg: 110.9,
          heightCm: 180,
          age: 35,
          dayType: DayType.lowCarb);
      // 1976,8×0,30×1,25 + 1976,8×0,25×1,25 + 100×1,5
      expect(low.kcal, closeTo(1509.05, 0.01));
      expect(low.deficit, greaterThan(normal.deficit));
      expect(low.grams.carbs, LowCarbRules.vegetableCarbsG);
    });

    test('nunca baja del piso seguro', () {
      final t = energyTarget(
          sex: Sex.female,
          weightKg: 50,
          heightCm: 155,
          age: 40,
          paceKgPerWeek: 0.75);
      expect(t.kcal, 1200);
      expect(t.floorApplied, isTrue);
    });

    test('reparto de macros válido solo si suma 100', () {
      expect(MacroSplit.nutritionistDefault.isValid, isTrue);
      expect(
          const MacroSplit(proteinPct: 30, carbPct: 45, lipidPct: 30).isValid,
          isFalse);
    });
  });

  group('Intercambios y porciones', () {
    const arroz = ExchangeFood(
        name: 'Arroz blanco (cocido)',
        group: FoodGroup.carb,
        unit: PortionUnit.grams,
        basePortion: 135,
        kcal: 130,
        protein: 2.7,
        carbs: 28,
        lipids: 0.3);
    const pollo = ExchangeFood(
        name: 'Pechuga de pollo cocida',
        group: FoodGroup.protein,
        unit: PortionUnit.grams,
        basePortion: 100,
        kcal: 165,
        protein: 31,
        carbs: 0,
        lipids: 3.6);
    const ensalada = ExchangeFood(
        name: 'Ensalada de frutas',
        group: FoodGroup.carb,
        unit: PortionUnit.portion,
        basePortion: 1,
        kcal: 169,
        protein: 1.5,
        carbs: 43.5,
        lipids: 0.6);

    test('con la meta del plan base las porciones no cambian', () {
      for (final g in [FoodGroup.carb, FoodGroup.protein, FoodGroup.lipid]) {
        expect(portionScale(group: g, baseKcal: BasePlan.kcal),
            closeTo(1, 1e-9));
      }
      expect(suggestedPortion(arroz, baseKcal: BasePlan.kcal), 135);
      expect(suggestedPortion(pollo, baseKcal: BasePlan.kcal), 100);
    });

    test('meta menor achica porciones y redondea a 5 g', () {
      // 1.800 kcal: proteína ×(1800/1976,8) = 0,9106 → 91,06 g → 90 g.
      expect(suggestedPortion(pollo, baseKcal: 1800), 90);
      expect(suggestedPortion(arroz, baseKcal: 1800)! % 5, 0);
      expect(suggestedPortion(arroz, baseKcal: 1800), lessThan(135));
    });

    test('día sin carbohidratos: sin carbohidrato, proteína +25 %', () {
      expect(
          suggestedPortion(arroz,
              baseKcal: BasePlan.kcal, dayType: DayType.lowCarb),
          isNull);
      expect(
          suggestedPortion(ensalada,
              baseKcal: BasePlan.kcal, dayType: DayType.lowCarb),
          isNull);
      expect(
          suggestedPortion(pollo,
              baseKcal: BasePlan.kcal, dayType: DayType.lowCarb),
          125);
      expect(
          portionScale(
              group: FoodGroup.vegetable,
              baseKcal: BasePlan.kcal,
              dayType: DayType.lowCarb),
          LowCarbRules.vegetableFactor);
    });

    test('porciones por unidad no se escalan', () {
      expect(suggestedPortion(ensalada, baseKcal: 1500), 1);
    });

    test('nutrientes por cantidad', () {
      final n = pollo.nutrientsFor(100);
      expect(n.kcal, closeTo(165, 1e-9));
      expect(n.protein, closeTo(31, 1e-9));
      final total = n + arroz.nutrientsFor(135);
      expect(total.kcal, closeTo(165 + 175.5, 1e-9));
      expect(ensalada.nutrientsFor(2).kcal, closeTo(338, 1e-9));
    });
  });

  group('Ejercicio (MET)', () {
    final pesas = activityById('pesas_mod')!;
    final futbol = activityById('futbol_rec')!;

    test('45 min de pesas con 110,9 kg ≈ 208 kcal netas', () {
      expect(netBurnKcal(pesas, 45, 110.9), closeTo(207.94, 0.01));
      expect(exerciseBonusKcal(netBurnKcal(pesas, 45, 110.9)),
          closeTo(103.97, 0.01));
    });

    test('fútbol 60 min con 110 kg: 770 brutas, 660 netas', () {
      expect(grossBurnKcal(futbol, 60, 110), closeTo(770, 1e-9));
      expect(netBurnKcal(futbol, 60, 110), closeTo(660, 1e-9));
    });

    test('actividad desconocida y zona 2', () {
      expect(activityById('no-existe'), isNull);
      // 40 años: FC máx 180 → zona 2 108–126.
      expect(zone2HeartRate(40), (108, 126));
    });
  });

  group('Meta física', () {
    test('conserva la masa magra y calcula tiempo con el déficit', () {
      final g = PhysicalGoal.from(
        weightKg: 110.9,
        leanKg: 84.4,
        goalFatPct: 17,
        dailyDeficitKcal: 500,
      );
      expect(g.goalWeightKg, closeTo(101.69, 0.01));
      expect(g.fatToLoseKg, closeTo(9.21, 0.01));
      expect(g.kcalToBurn, closeTo(9.21 * 7700, 100));
      expect(g.weeks, closeTo(20.3, 0.1));
    });

    test('ya en la meta: nada que perder; sin déficit: sin tiempo', () {
      final g = PhysicalGoal.from(
          weightKg: 80, leanKg: 70, goalFatPct: 17, dailyDeficitKcal: 0);
      expect(g.fatToLoseKg, 0);
      expect(g.weeks, isNull);
    });
  });

  group('Tendencia de peso', () {
    final start = DateTime(2026, 10, 1);
    List<WeighIn> series(double perWeek) => [
          for (var d = 0; d <= 21; d += 3)
            WeighIn(start.add(Duration(days: d)), 110 + perWeek * d / 7),
        ];

    test('menos de 3 pesajes: sin datos suficientes', () {
      final t = weightTrend([WeighIn(start, 110)], paceKgPerWeek: 0.5);
      expect(t.advice, TrendAdvice.notEnoughData);
      expect(t.kgPerWeek, isNull);
    });

    test('bajando 0,5 kg/semana va en ritmo', () {
      final t = weightTrend(series(-0.5), paceKgPerWeek: 0.5);
      expect(t.kgPerWeek, closeTo(-0.5, 1e-6));
      expect(t.advice, TrendAdvice.onTrack);
    });

    test('bajando 0,1 kg/semana va lento', () {
      expect(weightTrend(series(-0.1), paceKgPerWeek: 0.5).advice,
          TrendAdvice.tooSlow);
    });

    test('bajando 1,5 kg/semana (>1 % del peso) va muy rápido', () {
      expect(weightTrend(series(-1.5), paceKgPerWeek: 0.5).advice,
          TrendAdvice.tooFast);
    });

    test('ignora pesajes fuera de la ventana de 28 días', () {
      final old = WeighIn(start.subtract(const Duration(days: 60)), 130);
      final t = weightTrend([old, ...series(-0.5)], paceKgPerWeek: 0.5);
      expect(t.samples, 8);
      expect(t.kgPerWeek, closeTo(-0.5, 1e-6));
    });
  });
}
