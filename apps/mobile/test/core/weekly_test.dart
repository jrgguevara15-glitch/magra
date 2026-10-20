import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/core/recommendation/nutrition_plan.dart';
import 'package:magra/core/recommendation/weekly_adjustment.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';

void main() {
  group('Peso de tendencia', () {
    test('media móvil exponencial diaria con días interpolados', () {
      final d = DateTime(2026, 10, 1);
      final line = trendLine([
        WeighIn(d, 100),
        WeighIn(d.add(const Duration(days: 2)), 98),
      ]);
      expect(line.length, 3);
      expect(line[0].weightKg, 100);
      expect(line[1].weightKg, closeTo(99.9, 1e-9)); // 100 + 0,1 × (99 − 100)
      expect(line[2].weightKg, closeTo(99.71, 1e-9)); // 99,9 + 0,1 × (98 − 99,9)
      expect(line[2].date, DateTime(2026, 10, 3));
    });

    test('un pesaje por día (el último) y lista vacía', () {
      final d = DateTime(2026, 10, 1);
      final line = trendLine([
        WeighIn(d.add(const Duration(hours: 7)), 101),
        WeighIn(d.add(const Duration(hours: 20)), 99),
      ]);
      expect(line.single.weightKg, 99);
      expect(trendLine(const []), isEmpty);
    });

    test('filtra una subida de agua de un día', () {
      final d = DateTime(2026, 10, 1);
      final line = trendLine([
        for (var i = 0; i < 10; i++) WeighIn(d.add(Duration(days: i)), 100),
        WeighIn(d.add(const Duration(days: 10)), 101.5),
      ]);
      expect(line.last.weightKg, closeTo(100.15, 1e-9));
    });
  });

  group('Gasto real', () {
    final today = DateTime(2026, 10, 21);
    DateTime ago(int days) => today.subtract(Duration(days: days));
    final weighIns = [
      WeighIn(ago(21), 100),
      WeighIn(ago(14), 99.5),
      WeighIn(ago(7), 99),
      WeighIn(today, 98.5),
    ];

    test('ingesta promedio − Δpeso × 7.700 / días', () {
      final a = adaptiveTdee(
        dailyKcal: {
          for (var i = 1; i <= 14; i++) ago(i): 2000,
          ago(15): 500, // día con registro incompleto: no cuenta
          today: 300, // hoy aún no termina: no cuenta
        },
        weighIns: weighIns,
        today: today,
        minDayKcal: 900,
      )!;
      expect(a.loggedDays, 14);
      expect(a.avgIntake, 2000);
      expect(a.kgPerWeek, closeTo(-0.5, 1e-6));
      expect(a.tdee, closeTo(2550, 1e-3)); // 2.000 + 0,5 × 7.700 / 7
    });

    test('sin datos suficientes no estima', () {
      expect(
          adaptiveTdee(
              dailyKcal: {for (var i = 1; i <= 9; i++) ago(i): 2000},
              weighIns: weighIns,
              today: today,
              minDayKcal: 900),
          isNull);
      expect(
          adaptiveTdee(
              dailyKcal: {for (var i = 1; i <= 14; i++) ago(i): 2000},
              weighIns: weighIns.sublist(2),
              today: today,
              minDayKcal: 900),
          isNull);
    });
  });

  group('Ajuste semanal', () {
    test('semana desde el lunes y ajuste acumulado con tope', () {
      expect(weekStartOf(DateTime(2026, 10, 21, 18)), DateTime(2026, 10, 19));
      expect(weekStartOf(DateTime(2026, 10, 19)), DateTime(2026, 10, 19));
      expect(weekStartOf(DateTime(2026, 10, 25)), DateTime(2026, 10, 19));
      KcalAdjustment a(int d, {bool applied = true}) => KcalAdjustment(
          weekStart: DateTime(2026, 1, 5), deltaKcal: d, applied: applied, reason: 'x');
      expect(totalAdjustment([a(-100), a(-150, applied: false), a(-50)]), -150);
      expect(totalAdjustment([for (var i = 0; i < 5; i++) a(150)]), 500);
      expect(a(-100).toRow(), {
        'week_start': '2026-01-05',
        'delta_kcal': -100,
        'applied': true,
        'reason': 'x',
      });
    });

    WeightTrend t(TrendAdvice advice, [double? rate]) =>
        WeightTrend(kgPerWeek: rate, samples: 5, advice: advice);
    const none = WeightTrend(kgPerWeek: null, samples: 1, advice: TrendAdvice.notEnoughData);
    AdaptiveTdee tdee(double tdee, double intake) =>
        AdaptiveTdee(tdee: tdee, avgIntake: intake, loggedDays: 14, kgPerWeek: -0.1);

    WeeklySuggestion s(
      WeightTrend trend, {
      WeightTrend previous = none,
      AdaptiveTdee? adaptive,
      double kcal = 2000,
      int total = 0,
      bool maintenance = false,
    }) =>
        weeklySuggestion(
          trend: trend,
          previousTrend: previous,
          adaptive: adaptive,
          currentKcal: kcal,
          floorKcal: 1500,
          paceKgPerWeek: 0.5,
          currentTotal: total,
          maintenance: maintenance,
        );

    test('condición supervisada y sin pesajes: no se toca', () {
      expect(s(t(TrendAdvice.tooFast, -2), maintenance: true).reason,
          AdjustmentReason.maintenance);
      final n = s(none);
      expect(n.deltaKcal, 0);
      expect(n.message, contains('llevas 1'));
    });

    test('muy rápido sube 150; en ritmo mantiene', () {
      final fast = s(t(TrendAdvice.tooFast, -1.4));
      expect(fast.deltaKcal, 150);
      expect(fast.message, contains('1,40 kg'));
      final ok = s(t(TrendAdvice.onTrack, -0.5));
      expect(ok.deltaKcal, 0);
      expect(ok.reason, AdjustmentReason.onTrack);
    });

    test('lento con gasto real: baja hasta lo necesario, máximo 150', () {
      // Meta ideal = 2.400 − 500 = 1.900 → −100.
      expect(s(t(TrendAdvice.tooSlow, -0.1), adaptive: tdee(2400, 1950)).deltaKcal, -100);
      // Meta ideal = 2.100 − 500 = 1.600 → tope −150.
      expect(s(t(TrendAdvice.tooSlow, -0.1), adaptive: tdee(2100, 1950)).deltaKcal, -150);
    });

    test('lento pero come sobre la meta: primero ajustarse al plan', () {
      final c = s(t(TrendAdvice.tooSlow, -0.1), adaptive: tdee(2600, 2400));
      expect(c.deltaKcal, 0);
      expect(c.reason, AdjustmentReason.checkLog);
      expect(c.message, contains('2.400'));
    });

    test('lento sin gasto real: espera una semana y luego baja 100', () {
      final first = s(t(TrendAdvice.tooSlow, -0.1));
      expect(first.deltaKcal, 0);
      expect(first.reason, AdjustmentReason.tooSlowWait);
      final second = s(t(TrendAdvice.tooSlow, -0.1), previous: t(TrendAdvice.tooSlow, 0));
      expect(second.deltaKcal, -100);
      expect(second.message, contains('2.000 pasos'));
    });

    test('nunca baja del mínimo seguro ni pasa el tope acumulado', () {
      final slow = t(TrendAdvice.tooSlow, -0.1);
      final prev = t(TrendAdvice.tooSlow, 0);
      final near = s(slow, previous: prev, kcal: 1535);
      expect(near.deltaKcal, -30);
      expect(near.message, contains('mínimo seguro'));
      final floor = s(slow, previous: prev, kcal: 1500);
      expect(floor.deltaKcal, 0);
      expect(floor.reason, AdjustmentReason.atFloor);
      expect(s(t(TrendAdvice.tooFast, -1.4), total: 450).deltaKcal, 50);
      final capped = s(t(TrendAdvice.tooFast, -1.4), total: 500);
      expect(capped.deltaKcal, 0);
      expect(capped.message, contains('máximo'));
    });
  });

  group('Plan con ajuste', () {
    NutritionPlan plan(int adj, {Questionnaire? q, double weight = 95}) =>
        recommendNutrition(
          profile: sampleProfile,
          weightKg: weight,
          questionnaire: q ?? Questionnaire.initial,
          today: DateTime(2026, 10, 21),
          kcalAdjustment: adj,
        );

    test('suma el ajuste, reparte macros y lo explica', () {
      final base = plan(0);
      final down = plan(-100);
      expect(down.kcal, closeTo(base.kcal - 100, 1e-9));
      expect(down.adjustmentKcal, closeTo(-100, 1e-9));
      expect(down.protein / base.protein, closeTo(down.kcal / base.kcal, 1e-9));
      expect(down.reasons.any((r) => r.contains('ajuste semanal de −100')), isTrue);
      expect(base.reasons.any((r) => r.contains('ajuste semanal')), isFalse);
      expect(base.tdee, greaterThan(base.kcal));
    });

    test('respeta el mínimo seguro y no aplica con condición supervisada', () {
      expect(plan(-500, weight: 70).kcal, greaterThanOrEqualTo(1500));
      final supervised = plan(-150,
          q: Questionnaire.initial.copyWith(healthConditions: [HealthCondition.pregnancy]));
      expect(supervised.adjustmentKcal, 0);
    });
  });
}
