/// Base fija de la semana para calcular las calorías: el peso promedio de
/// los pesajes de la semana pasada y el mejor % de grasa disponible. Así la
/// meta no sube y baja con cada pesaje: se recalcula cada lunes.
library;

import '../../features/profile/user_profile.dart';
import '../../features/progress/measurement.dart';
import '../../features/questionnaire/questionnaire.dart';
import '../format.dart';
import '../formulas/formulas.dart';
import 'nutrition_plan.dart';
import 'weekly_adjustment.dart';

/// De dónde sale el % de grasa usado en el plan.
enum FatSource {
  professional('informado por un profesional'),
  tape('según tus medidas');

  const FatSource(this.label);
  final String label;
}

class PlanBasis {
  const PlanBasis({
    required this.weekStart,
    required this.weightKg,
    required this.weighIns,
    required this.fromLastWeek,
    this.fatPct,
    this.fatSource,
  });

  /// Lunes de la semana a la que corresponde la meta.
  final DateTime weekStart;

  /// Peso usado para el plan (promedio de [weighIns] pesajes).
  final double weightKg;
  final int weighIns;

  /// `true` si sale de los pesajes de la semana pasada; `false` en la
  /// primera semana (se usa el primer registro, fijo hasta el lunes).
  final bool fromLastWeek;

  final double? fatPct;
  final FatSource? fatSource;

  /// Explicación para "Por qué".
  String get note => fromLastWeek
      ? 'Tu meta usa ${fmt(weightKg, 1)} kg, el promedio de '
          '$weighIns ${weighIns == 1 ? 'pesaje' : 'pesajes'} de la semana pasada, '
          'y queda fija hasta el próximo lunes: así no cambia con cada pesaje.'
      : 'Tu meta usa tu primer registro (${fmt(weightKg, 1)} kg) y queda fija '
          'hasta el lunes; desde ahí se calcula con el promedio de tus pesajes '
          'de la semana.';
}

/// La base de la semana de [today]. [measurements] van de la más antigua a
/// la más reciente y no puede estar vacía.
PlanBasis planBasis(List<Measurement> measurements, UserProfile profile, DateTime today) {
  final week = weekStartOf(today);
  final before = [for (final m in measurements) if (m.date.isBefore(week)) m];
  final List<Measurement> pool;
  if (before.isNotEmpty) {
    final last = before.last.date;
    final from = DateTime(last.year, last.month, last.day - 6);
    pool = [for (final m in before) if (!m.date.isBefore(from)) m];
  } else {
    final first = measurements.first.date;
    pool = [for (final m in measurements) if (_sameDay(m.date, first)) m];
  }
  final weight = pool.fold<double>(0, (a, m) => a + m.weightKg) / pool.length;

  // % de grasa: el más reciente antes del lunes (o el primero de esta
  // semana si aún no hay); el de un profesional gana en la misma fecha.
  final candidates = before.isNotEmpty ? before.reversed : measurements;
  double? fat;
  FatSource? source;
  for (final m in candidates) {
    final pro = usableBodyFat(m.reportedFatPct) ? m.reportedFatPct : null;
    final tape = m.compositionFor(profile).fatPct;
    if (pro != null) {
      fat = pro;
      source = FatSource.professional;
    } else if (usableBodyFat(tape)) {
      fat = tape;
      source = FatSource.tape;
    }
    if (fat != null) break;
  }
  return PlanBasis(
    weekStart: week,
    weightKg: weight,
    weighIns: pool.length,
    fromLastWeek: before.isNotEmpty,
    fatPct: fat,
    fatSource: source,
  );
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// El plan nutricional de la semana: la misma meta en Hoy, Plan, Progreso y
/// la revisión semanal.
NutritionPlan weeklyNutrition({
  required UserProfile profile,
  required List<Measurement> measurements,
  required Questionnaire questionnaire,
  required DateTime today,
  int kcalAdjustment = 0,
}) {
  final basis = planBasis(measurements, profile, today);
  return recommendNutrition(
    profile: profile,
    weightKg: basis.weightKg,
    questionnaire: questionnaire,
    today: today,
    kcalAdjustment: kcalAdjustment,
    bodyFatPct: basis.fatPct,
    fatSource: basis.fatSource?.label ?? FatSource.tape.label,
    basisNote: basis.note,
  );
}
