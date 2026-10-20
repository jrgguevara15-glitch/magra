import '../format.dart';
import '../formulas/formulas.dart';

/// Cuánto puede moverse la meta en una semana.
const int weeklyAdjustmentLimit = 150;

/// Tope del ajuste acumulado sobre la fórmula, en ambos sentidos.
const int totalAdjustmentLimit = 500;

/// Lunes de la semana de [day] (sin hora).
DateTime weekStartOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));

/// Ajuste decidido para una semana.
class KcalAdjustment {
  const KcalAdjustment({
    this.id,
    required this.weekStart,
    required this.deltaKcal,
    required this.applied,
    required this.reason,
  });

  final String? id;
  final DateTime weekStart;
  final int deltaKcal;

  /// `false` si el usuario eligió "Ahora no".
  final bool applied;
  final String reason;

  factory KcalAdjustment.fromRow(Map<String, dynamic> row) => KcalAdjustment(
        id: row['id'] as String?,
        weekStart: DateTime.parse(row['week_start'] as String),
        deltaKcal: (row['delta_kcal'] as num).toInt(),
        applied: row['applied'] as bool,
        reason: row['reason'] as String,
      );

  Map<String, dynamic> toRow() => {
        'week_start': isoDate(weekStart),
        'delta_kcal': deltaKcal,
        'applied': applied,
        'reason': reason,
      };
}

/// Suma de los ajustes aplicados, dentro de ±[totalAdjustmentLimit].
int totalAdjustment(List<KcalAdjustment> adjustments) {
  final sum = adjustments
      .where((a) => a.applied)
      .fold<int>(0, (a, b) => a + b.deltaKcal);
  return sum.clamp(-totalAdjustmentLimit, totalAdjustmentLimit);
}

enum AdjustmentReason {
  maintenance,
  notEnoughData,
  tooFast,
  onTrack,

  /// Lento y el registro dice que come sobre su meta: primero ajustarse.
  checkLog,

  /// Lento: ajuste con el gasto real o tras 2 semanas seguidas.
  tooSlow,

  /// Lento por primera vez, sin datos de gasto real: esperar una semana.
  tooSlowWait,

  /// Ya está en el mínimo seguro.
  atFloor,
}

class WeeklySuggestion {
  const WeeklySuggestion(this.deltaKcal, this.reason, this.message);

  /// Cambio propuesto a la meta (0 = mantener).
  final int deltaKcal;
  final AdjustmentReason reason;

  /// Explicación para el usuario.
  final String message;
}

int _round10(double v) => (v / 10).round() * 10;

/// Qué cambiar en la meta esta semana, como lo haría el nutricionista en el
/// control: mira la tendencia del peso, el gasto real (si hay registro
/// suficiente) y nunca baja del mínimo seguro.
WeeklySuggestion weeklySuggestion({
  required WeightTrend trend,
  required WeightTrend previousTrend,
  required AdaptiveTdee? adaptive,
  required double currentKcal,
  required double floorKcal,
  required double paceKgPerWeek,
  required int currentTotal,
  required bool maintenance,
}) {
  if (maintenance) {
    return const WeeklySuggestion(0, AdjustmentReason.maintenance,
        'Por tu condición de salud, los cambios de calorías los define un '
        'profesional.');
  }
  final rate = trend.kgPerWeek;
  if (trend.advice == TrendAdvice.notEnoughData || rate == null) {
    return WeeklySuggestion(0, AdjustmentReason.notEnoughData,
        'Pésate al menos 3 veces en 4 semanas (llevas ${trend.samples}) para '
        'ver tu tendencia. Mejor en ayunas, después del baño.');
  }
  final ritmo = '${fmt(-rate, 2)} kg por semana';

  int delta;
  AdjustmentReason reason;
  String message;
  switch (trend.advice) {
    case TrendAdvice.tooFast:
      delta = weeklyAdjustmentLimit;
      reason = AdjustmentReason.tooFast;
      message = 'Bajas $ritmo: más del 1 % de tu peso. Tan rápido se pierde '
          'músculo; sube $delta kcal.';
    case TrendAdvice.onTrack:
      return WeeklySuggestion(0, AdjustmentReason.onTrack,
          'Vas bien: bajas $ritmo (meta ${fmt(paceKgPerWeek, 2)}). Mantén tu '
          'plan.');
    case TrendAdvice.tooSlow:
    case TrendAdvice.notEnoughData:
      final a = adaptive;
      if (a != null && a.avgIntake > currentKcal + weeklyAdjustmentLimit) {
        return WeeklySuggestion(0, AdjustmentReason.checkLog,
            'Bajas $ritmo. Tu registro promedia ${fmt(a.avgIntake)} kcal y tu '
            'meta es ${fmt(currentKcal)}: antes de bajar calorías, ajústate a '
            'tu plan una semana.');
      }
      final wanted = a == null ? null : a.tdee - paceKgPerWeek * 1000;
      if (wanted != null && wanted < currentKcal - 50) {
        delta = _round10((wanted - currentKcal)
            .clamp(-weeklyAdjustmentLimit.toDouble(), 0));
        reason = AdjustmentReason.tooSlow;
        message = 'Bajas $ritmo. Tu gasto real es ~${fmt(a!.tdee)} kcal '
            '(con ${a.loggedDays} días registrados): baja ${-delta} kcal.';
      } else if (previousTrend.advice == TrendAdvice.tooSlow) {
        delta = -100;
        reason = AdjustmentReason.tooSlow;
        message = 'Segunda semana bajando $ritmo, menos de la mitad de tu '
            'meta: baja 100 kcal y suma 2.000 pasos al día.';
      } else {
        return WeeklySuggestion(0, AdjustmentReason.tooSlowWait,
            'Bajas $ritmo, menos de la mitad de tu meta. Revisa que anotes '
            'todo y suma 2.000 pasos al día; si sigue igual la próxima '
            'semana, ajustamos las calorías.');
      }
  }

  // Mínimo seguro y tope acumulado.
  final wantedDelta = delta;
  if (currentKcal + delta < floorKcal) {
    delta = (((floorKcal - currentKcal) / 10).ceil() * 10).clamp(delta, 0);
  }
  delta = (currentTotal + delta)
          .clamp(-totalAdjustmentLimit, totalAdjustmentLimit) -
      currentTotal;
  if (delta == 0) {
    return WeeklySuggestion(
        0,
        AdjustmentReason.atFloor,
        reason == AdjustmentReason.tooFast
            ? 'Bajas $ritmo, pero ya subimos el máximo ($totalAdjustmentLimit '
                'kcal). Revisa tu registro con un profesional.'
            : 'Bajas $ritmo, pero tus calorías ya están en el mínimo seguro. '
                'Suma pasos o entrenamiento en vez de comer menos.');
  }
  if (delta != wantedDelta) {
    message = '$message Queda en ${delta > 0 ? '+' : '−'}${delta.abs()} kcal '
        'para no pasar el mínimo seguro ni el tope de ±$totalAdjustmentLimit.';
  }
  return WeeklySuggestion(delta, reason, message);
}
