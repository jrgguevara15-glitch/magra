import '../../core/format.dart';
import '../../core/formulas/formulas.dart';

/// Una actividad física hecha un día.
class ExerciseEntry {
  const ExerciseEntry({
    this.id,
    required this.date,
    required this.activityId,
    required this.name,
    required this.met,
    required this.minutes,
    required this.kcalNet,
  });

  /// Calcula las calorías netas con el peso actual del usuario.
  factory ExerciseEntry.fromActivity(
    Activity activity,
    int minutes, {
    required DateTime date,
    required double weightKg,
  }) =>
      ExerciseEntry(
        date: date,
        activityId: activity.id,
        name: activity.name,
        met: activity.met,
        minutes: minutes,
        kcalNet: netBurnKcal(activity, minutes.toDouble(), weightKg),
      );

  final String? id;
  final DateTime date;
  final String activityId;
  final String name;
  final double met;
  final int minutes;

  /// (MET − 1) × peso × horas: lo que se quemó además del reposo.
  final double kcalNet;

  factory ExerciseEntry.fromRow(Map<String, dynamic> row) => ExerciseEntry(
        id: row['id'] as String?,
        date: DateTime.parse(row['done_on'] as String),
        activityId: row['activity_id'] as String,
        name: row['name'] as String,
        met: (row['met'] as num).toDouble(),
        minutes: (row['minutes'] as num).toInt(),
        kcalNet: (row['kcal_net'] as num).toDouble(),
      );

  Map<String, dynamic> toRow() => {
        'done_on': isoDate(date),
        'activity_id': activityId,
        'name': name,
        'met': met,
        'minutes': minutes,
        'kcal_net': (kcalNet * 10).round() / 10,
      };
}

/// Calorías que el ejercicio del día suma a la meta (solo una parte: las
/// estimaciones de gasto suelen quedar altas).
double exerciseBonusFor(List<ExerciseEntry> entries) =>
    exerciseBonusKcal(entries.fold<double>(0, (a, e) => a + e.kcalNet));

/// Protocolos de ayuno que ofrece MAGRA. Nunca más de 16 horas.
const fastingProtocols = [12, 14, 16];

/// Más allá de esto MAGRA pide terminar el ayuno.
const fastingHardLimitHours = 24;

/// Un ayuno: en curso mientras no tenga [end].
class Fast {
  const Fast({
    this.id,
    required this.start,
    this.end,
    required this.targetHours,
  });

  final String? id;
  final DateTime start;
  final DateTime? end;
  final int targetHours;

  bool get active => end == null;

  Duration elapsed(DateTime now) => (end ?? now).difference(start);

  DateTime get targetEnd => start.add(Duration(hours: targetHours));

  /// Fracción de la meta cumplida (0–1).
  double progress(DateTime now) =>
      (elapsed(now).inMinutes / (targetHours * 60)).clamp(0, 1).toDouble();

  bool reached(DateTime now) => elapsed(now) >= Duration(hours: targetHours);

  bool overLimit(DateTime now) =>
      elapsed(now) >= const Duration(hours: fastingHardLimitHours);

  factory Fast.fromRow(Map<String, dynamic> row) => Fast(
        id: row['id'] as String?,
        start: DateTime.parse(row['started_at'] as String).toLocal(),
        end: row['ended_at'] == null
            ? null
            : DateTime.parse(row['ended_at'] as String).toLocal(),
        targetHours: (row['target_hours'] as num).toInt(),
      );
}

/// 15 h 40 min
String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}
