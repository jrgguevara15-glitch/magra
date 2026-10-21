import '../format.dart';
import 'training_plan.dart';

/// Una serie hecha: repeticiones y kilos (0 = peso corporal).
class SetLog {
  const SetLog(this.reps, this.kg);

  factory SetLog.fromJson(Map<String, dynamic> j) =>
      SetLog((j['reps'] as num).toInt(), (j['kg'] as num? ?? 0).toDouble());

  final int reps;
  final double kg;

  Map<String, dynamic> toJson() => {'reps': reps, 'kg': kg};
}

/// Lo que se hizo de un ejercicio en una sesión.
class ExerciseLog {
  const ExerciseLog({required this.name, required this.sets});

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        name: j['name'] as String,
        sets: [
          for (final s in j['sets'] as List? ?? const [])
            SetLog.fromJson((s as Map).cast<String, dynamic>()),
        ],
      );

  final String name;
  final List<SetLog> sets;

  /// Carga de trabajo: la mayor de la sesión.
  double get topKg => sets.fold(0, (a, s) => s.kg > a ? s.kg : a);

  /// Series hechas con la carga de trabajo.
  List<SetLog> get workSets => [for (final s in sets) if (s.kg == topKg) s];

  Map<String, dynamic> toJson() => {
        'name': name,
        'sets': [for (final s in sets) s.toJson()],
      };
}

/// Una sesión de fuerza registrada.
class WorkoutSession {
  const WorkoutSession({
    this.id,
    required this.date,
    required this.title,
    required this.minutes,
    required this.exercises,
  });

  factory WorkoutSession.fromRow(Map<String, dynamic> row) => WorkoutSession(
        id: row['id'] as String?,
        date: DateTime.parse(row['done_on'] as String),
        title: row['title'] as String,
        minutes: (row['minutes'] as num).toInt(),
        exercises: [
          for (final e in row['exercises'] as List)
            ExerciseLog.fromJson((e as Map).cast<String, dynamic>()),
        ],
      );

  final String? id;
  final DateTime date;
  final String title;
  final int minutes;
  final List<ExerciseLog> exercises;

  /// Kilos × repeticiones de la sesión.
  double get volume => exercises.fold(
      0, (a, e) => a + e.sets.fold<double>(0, (b, s) => b + s.kg * s.reps));

  Map<String, dynamic> toRow() => {
        'done_on': isoDate(date),
        'title': title,
        'minutes': minutes,
        'exercises': [for (final e in exercises) e.toJson()],
      };
}

/// Lo que MAGRA propone para la próxima vez en un ejercicio.
class NextTarget {
  const NextTarget({this.kg, required this.reps, required this.note, this.deload = false});

  /// Carga sugerida; `null` si aún no hay registro (la elige el usuario).
  final double? kg;

  /// Repeticiones a buscar en cada serie.
  final int reps;
  final String note;
  final bool deload;
}

double _roundHalf(double v) => (v * 2).round() / 2;

String _kg(double v) => '${fmt(v, v % 1 == 0 ? 0 : 1)} kg';

/// Doble progresión: primero repeticiones dentro del rango; cuando todas
/// las series llegan al tope, sube la carga y vuelve al mínimo. Tres
/// sesiones seguidas sin llegar al mínimo con la misma carga → descarga del
/// 10 %. [history] es lo hecho en ese ejercicio, de la más antigua a la
/// más reciente.
NextTarget nextTarget(Exercise ex, List<ExerciseLog> history) {
  final done = [for (final h in history) if (h.sets.isNotEmpty) h];
  if (done.isEmpty) {
    return NextTarget(
      reps: ex.repMin,
      note: ex.loadStep == 0
          ? 'Haz ${ex.sets} series de ${ex.repMin}–${ex.repMax} con buena técnica.'
          : 'Primera vez: elige un peso con el que hagas ${ex.repMax} '
              'repeticiones dejando 2–3 en reserva.',
    );
  }
  final last = done.last;
  final kg = last.topKg;
  final work = last.workSets;
  bool failed(ExerciseLog l) =>
      l.workSets.length < ex.sets ||
      l.workSets.take(ex.sets).any((s) => s.reps < ex.repMin);
  final allTop = work.length >= ex.sets &&
      work.take(ex.sets).every((s) => s.reps >= ex.repMax);

  if (allTop) {
    if (ex.loadStep > 0 && kg > 0) {
      final next = kg + ex.loadStep;
      return NextTarget(
        kg: next,
        reps: ex.repMin,
        note: 'Sube a ${_kg(next)} (o al siguiente peso disponible): '
            'completaste ${ex.sets} series de ${ex.repMax}.',
      );
    }
    return NextTarget(
      kg: kg,
      reps: ex.repMax,
      note: 'Completaste todo: suma 2 repeticiones por serie o pasa a una '
          'variante más difícil.',
    );
  }

  final recent = done.length >= 3 ? done.sublist(done.length - 3) : const <ExerciseLog>[];
  if (kg > 0 &&
      recent.length == 3 &&
      recent.every((l) => l.topKg == kg && failed(l))) {
    final next = _roundHalf(kg * 0.9);
    return NextTarget(
      kg: next,
      reps: ex.repMax,
      deload: true,
      note: 'Tres sesiones sin llegar a ${ex.repMin}: baja a ${_kg(next)} y '
          'vuelve a subir. Revisa sueño y comida.',
    );
  }

  final lowest = work.take(ex.sets).fold<int>(ex.repMax, (a, s) => s.reps < a ? s.reps : a);
  final reps = (lowest + 1).clamp(ex.repMin, ex.repMax);
  return NextTarget(
    kg: kg,
    reps: reps,
    note: kg > 0
        ? 'Mantén ${_kg(kg)} y busca $reps repeticiones en cada serie.'
        : 'Busca $reps repeticiones en cada serie.',
  );
}

/// Historial de un ejercicio (por nombre) en las sesiones, de la más
/// antigua a la más reciente.
List<ExerciseLog> historyOf(String exercise, List<WorkoutSession> sessions) {
  final sorted = [...sessions]..sort((a, b) => a.date.compareTo(b.date));
  return [
    for (final s in sorted)
      for (final e in s.exercises)
        if (e.name == exercise) e,
  ];
}

/// Qué sesión toca: la siguiente en la rotación (A/B o superior/inferior)
/// después de la última registrada, para que descanse lo trabajado.
TrainingDay nextSession(TrainingPlan plan, List<WorkoutSession> sessions) {
  final titles = <String>[];
  for (final d in plan.days) {
    if (!titles.contains(d.title)) titles.add(d.title);
  }
  if (sessions.isEmpty) return plan.days.first;
  final last = ([...sessions]..sort((a, b) => a.date.compareTo(b.date))).last;
  final i = titles.indexOf(last.title);
  final next = titles[(i + 1) % titles.length];
  return plan.days.firstWhere((d) => d.title == next);
}
