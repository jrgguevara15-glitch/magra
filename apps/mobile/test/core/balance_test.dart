import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/recommendation/balance.dart';
import 'package:magra/core/recommendation/motivation.dart';

void main() {
  final today = DateTime(2026, 10, 22);
  BalanceForecast f({
    Map<DateTime, DayTotals> history = const {},
    double eaten = 1736,
    List<double> pending = const [450],
    double tdee = 2353,
  }) =>
      balanceForecast(
        today: today,
        history: history,
        eatenToday: eaten,
        pendingMealKcal: pending,
        metaKcal: 1853,
        available: 1852,
        tdee: tdee,
        tdeeIsReal: false,
        plannedKgPerWeek: 0.5,
        floorKcal: 1500,
      );

  test('caso del usuario: ayer +229 y hoy le quedan 116 con una comida pendiente', () {
    final r = f(history: {DateTime(2026, 10, 21): const DayTotals(2082, 120)});
    expect(r.projectedToday, 2186);
    expect(r.overToday, closeTo(334, 1e-9));
    expect(r.lines.first, contains('cerrarías en 2.186 kcal'));
    expect(r.lines.first, contains('te quedan 116 kcal'));
    expect(r.days, 2);
    expect(r.avgOverMeta, closeTo(281, 1e-9));
    // (2.134 − 2.353) × 7 / 7.700 ≈ −0,2 kg/semana: baja, pero menos que el plan.
    expect(r.kgPerWeek, closeTo(-0.199, 0.001));
    expect(r.lines.last, contains('menos que tu plan'));
    expect(r.tone, BalanceTone.warn);
  });

  test('si el promedio supera el gasto, avisa que subiría; si queda cerca, que se mantendría', () {
    final up = f(history: {DateTime(2026, 10, 21): const DayTotals(2700, 120)}, tdee: 2300);
    expect(up.tone, BalanceTone.bad);
    expect(up.title, 'A este ritmo subirías de peso');
    expect(up.lines.last, contains('subirías'));
    final flat = f(history: {DateTime(2026, 10, 21): const DayTotals(2400, 120)}, tdee: 2300);
    expect(flat.title, 'A este ritmo no bajarías');
    expect(flat.lines.last, contains('te mantendrías'));
  });

  test('dentro de la meta: lo celebra', () {
    final ok = f(eaten: 1300, pending: const [450], history: {DateTime(2026, 10, 20): const DayTotals(1800, 140)});
    expect(ok.tone, BalanceTone.good);
    expect(ok.lines.first, startsWith('Vas bien'));
    expect(ok.lines.last, contains('¡Sigue así!'));
  });
}
