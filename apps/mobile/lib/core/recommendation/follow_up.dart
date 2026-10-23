/// Seguimiento del coach: avisos motivadores según la hora y lo registrado
/// (hora de entrenar sin empezar, comidas sin anotar, proteína o pasos bajos
/// al final del día, día de pesaje, días sin registrar).
library;

import '../format.dart';

enum NudgeKind {
  training('Entreno'),
  meal('Comidas'),
  protein('Proteína'),
  steps('Pasos'),
  weighIn('Pesaje'),
  comeback('Días sin registrar');

  const NudgeKind(this.label);
  final String label;
}

/// Un aviso: [id] es único por día (para no repetirlo si se descarta).
class Nudge {
  const Nudge({
    required this.kind,
    required this.id,
    required this.title,
    required this.message,
    required this.action,
    this.mealIndex,
  });

  final NudgeKind kind;
  final String id;
  final String title;
  final String message;

  /// Texto del botón ("Ir a entrenar", "Anotar comida").
  final String action;

  /// Comida a anotar, en los avisos de comida.
  final int? mealIndex;
}

/// Lo que el seguimiento necesita saber del día.
class FollowUpState {
  const FollowUpState({
    required this.now,
    required this.name,
    required this.mealTimes,
    this.mealNames = const [],
    required this.loggedMeals,
    required this.proteinEaten,
    required this.proteinTarget,
    required this.sleepMinutes,
    this.trainingToday = false,
    this.trainingTitle,
    this.trainingMinutes,
    this.trainedToday = false,
    this.steps,
    this.stepsGoal,
    this.lastWeighIn,
    this.daysSinceLog,
    this.enabled = const {...NudgeKind.values},
  });

  final DateTime now;

  /// Nombre de la persona (puede venir vacío).
  final String name;

  /// Hora de cada comida del plan, en minutos desde medianoche.
  final List<int> mealTimes;

  /// Nombre de cada comida ("Almuerzo"); si falta, "Comida N".
  final List<String> mealNames;

  /// Comidas con algo anotado hoy (índices).
  final Set<int> loggedMeals;
  final double proteinEaten;
  final double proteinTarget;

  /// Hora de dormir, en minutos desde medianoche.
  final int sleepMinutes;

  /// Hoy toca entrenar según la rutina.
  final bool trainingToday;
  final String? trainingTitle;

  /// Hora de entrenar (minutos desde medianoche) o `null` si varía.
  final int? trainingMinutes;

  /// Ya entrenó o anotó ejercicio hoy.
  final bool trainedToday;
  final int? steps;
  final int? stepsGoal;
  final DateTime? lastWeighIn;

  /// Días seguidos sin anotar comidas antes de hoy (null si no se sabe).
  final int? daysSinceLog;
  final Set<NudgeKind> enabled;
}

/// Frase motivadora que cambia día a día (y no al azar dentro del día).
String _pick(List<String> options, DateTime day, int salt) =>
    options[(day.year * 372 + day.month * 31 + day.day + salt) % options.length];

/// Los avisos que corresponden ahora, del más importante al menos.
List<Nudge> followUps(FollowUpState s) {
  final now = s.now;
  final minute = now.hour * 60 + now.minute;
  final key = isoDate(now);
  // "Alex, tu entreno…" o "Tu entreno…" si no hay nombre.
  String msg(String body) {
    final n = s.name.trim();
    return n.isEmpty ? '${body[0].toUpperCase()}${body.substring(1)}' : '$n, $body';
  }
  final out = <Nudge>[];
  bool on(NudgeKind k) => s.enabled.contains(k);
  // No molestar cerca de la hora de dormir.
  final quietFrom = s.sleepMinutes - 45;
  final late = minute >= quietFrom;

  if (on(NudgeKind.training) &&
      s.trainingToday &&
      !s.trainedToday &&
      s.trainingMinutes != null &&
      minute >= s.trainingMinutes! + 20 &&
      !late) {
    out.add(Nudge(
      kind: NudgeKind.training,
      id: 'training-$key',
      title: 'Es tu hora de entrenar',
      message: msg(_pick([
        'tu ${s.trainingTitle ?? 'entreno'} te está esperando. Empieza con el calentamiento: los primeros 5 minutos son los más difíciles.',
        'hoy toca ${s.trainingTitle ?? 'entrenar'}. No tiene que ser perfecto: hazlo y suma una semana más a tu racha.',
        'cada sesión que haces protege tu músculo mientras bajas grasa. Vamos con ${s.trainingTitle ?? 'el entreno de hoy'}.',
        'tu yo de mañana te lo va a agradecer. Ponte las zapatillas y arranca: ${s.trainingTitle ?? 'el entreno'} ya está listo.',
      ], now, 1)),
      action: 'Ir a entrenar',
    ));
  }

  if (on(NudgeKind.meal) && !late) {
    // Solo la comida pendiente más reciente (sin acumular avisos).
    for (var i = s.mealTimes.length - 1; i >= 0; i--) {
      if (minute < s.mealTimes[i] + 90) continue;
      if (!s.loggedMeals.contains(i)) {
        out.add(Nudge(
          kind: NudgeKind.meal,
          id: 'meal-$i-$key',
          title: '${i < s.mealNames.length ? s.mealNames[i] : 'Comida ${i + 1}'} sin anotar',
          message: msg(_pick([
            'anótala ahora que la tienes fresca: lo que se registra se puede mejorar.',
            'registrarla te toma 30 segundos y mantiene tu plan exacto.',
            'si aún no comes, no la saltes: comer a tus horas te ayuda a no llegar con hambre a la noche.',
          ], now, i)),
          action: 'Anotar comida',
          mealIndex: i,
        ));
      }
      break;
    }
  }

  final evening = minute >= s.sleepMinutes - 3 * 60 && !late;
  if (on(NudgeKind.protein) &&
      evening &&
      s.proteinTarget > 0 &&
      s.loggedMeals.isNotEmpty &&
      s.proteinEaten < s.proteinTarget * 0.75) {
    final missing = s.proteinTarget - s.proteinEaten;
    out.add(Nudge(
      kind: NudgeKind.protein,
      id: 'protein-$key',
      title: 'Te faltan ${fmt(missing)} g de proteína',
      message: msg(_pick([
        'un yogur griego, atún o un batido de proteína te dejan muy cerca. La proteína es lo que cuida tu músculo.',
        'cierra el día fuerte: claras, pollo o quesillo suman rápido sin muchas calorías.',
      ], now, 2)),
      action: 'Anotar comida',
    ));
  }

  if (on(NudgeKind.steps) &&
      evening &&
      s.steps != null &&
      s.stepsGoal != null &&
      s.steps! < s.stepsGoal! * 0.6) {
    out.add(Nudge(
      kind: NudgeKind.steps,
      id: 'steps-$key',
      title: 'Vas en ${fmt(s.steps)} de ${fmt(s.stepsGoal)} pasos',
      message: msg('una caminata de 15–20 minutos después de comer suma unos 2.000 pasos y mejora tu digestión.'),
      action: 'Anotar pasos',
    ));
  }

  final weighedToday = s.lastWeighIn != null && isoDate(s.lastWeighIn!) == key;
  final staleWeight = s.lastWeighIn == null || now.difference(s.lastWeighIn!).inDays >= 7;
  if (on(NudgeKind.weighIn) && !weighedToday && (now.weekday == DateTime.monday || staleWeight) && minute < 14 * 60) {
    out.add(Nudge(
      kind: NudgeKind.weighIn,
      id: 'weigh-$key',
      title: 'Hoy toca pesarte',
      message: msg('en ayunas, después del baño y antes de comer. Es solo un dato: la tendencia de la semana es la que manda.'),
      action: 'Registrar peso',
    ));
  }

  if (on(NudgeKind.comeback) && (s.daysSinceLog ?? 0) >= 2 && s.loggedMeals.isEmpty && !late) {
    out.add(Nudge(
      kind: NudgeKind.comeback,
      id: 'comeback-$key',
      title: 'Te echamos de menos',
      message: msg(_pick([
        'llevas ${s.daysSinceLog} días sin anotar. No pasa nada: hoy es un buen día para retomar con una sola comida.',
        'retomar es lo que hacen las personas que logran su meta. Empieza anotando tu próxima comida.',
      ], now, 3)),
      action: 'Anotar comida',
    ));
  }
  return out;
}
