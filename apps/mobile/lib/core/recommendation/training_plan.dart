import '../../features/questionnaire/questionnaire.dart';
import '../format.dart';
import '../formulas/formulas.dart';

/// Patrones de movimiento de la rutina de fuerza.
enum Pattern { squat, hinge, lunge, pushH, pullH, pushV, pullV, core }

class Exercise {
  const Exercise(
    this.name,
    this.prescription, {
    this.pattern = Pattern.core,
    this.sets = 3,
    this.repMin = 10,
    this.repMax = 12,
    this.loadStep = 0,
    this.original,
  });

  final String name;

  /// Si el usuario lo cambió: el ejercicio que venía en la rutina.
  final String? original;

  /// Clave del ejercicio en la rutina (para guardar el cambio).
  String get slot => original ?? name;

  /// Series × repeticiones y esfuerzo, p. ej. "3 × 10–12 · deja 2 en reserva".
  final String prescription;
  final Pattern pattern;

  /// Series de trabajo que cuentan para progresar.
  final int sets;
  final int repMin;
  final int repMax;

  /// Cuánto subir la carga (kg); 0 = peso corporal, se progresa en reps.
  final double loadStep;
}

class TrainingDay {
  const TrainingDay({
    required this.weekday,
    required this.title,
    required this.exercises,
    required this.strengthMinutes,
    required this.cardioMinutes,
  });

  /// 1 = lunes … 7 = domingo.
  final int weekday;
  final String title;
  final List<Exercise> exercises;
  final int strengthMinutes;
  final int cardioMinutes;
}

class TrainingPlan {
  const TrainingPlan({
    required this.days,
    required this.cardio,
    required this.zone2,
    required this.stepsStart,
    required this.reasons,
    required this.cautions,
    this.lowImpact = false,
  });

  final List<TrainingDay> days;

  /// Cardio y calentamiento sin impacto (peso, articulaciones o edad).
  final bool lowImpact;

  /// Tipo de cardio recomendado.
  final String cardio;
  final (int, int) zone2;

  /// Pasos diarios para empezar; se suman 1.000 cada 2 semanas hasta 10.000.
  final int stepsStart;
  final List<String> reasons;

  /// Cuidados por lesiones o salud.
  final List<String> cautions;
}

/// Ejercicio por patrón según el equipo disponible.
const _byEquipment = <Pattern, Map<Equipment, String>>{
  Pattern.squat: {
    Equipment.gym: 'Sentadilla con barra o prensa de piernas',
    Equipment.homeWeights: 'Sentadilla goblet con mancuerna',
    Equipment.bodyweight: 'Sentadilla con peso corporal',
  },
  Pattern.hinge: {
    Equipment.gym: 'Peso muerto rumano con barra',
    Equipment.homeWeights: 'Peso muerto rumano con mancuernas',
    Equipment.bodyweight: 'Puente de glúteo a una pierna',
  },
  Pattern.lunge: {
    Equipment.gym: 'Zancada con mancuernas',
    Equipment.homeWeights: 'Zancada hacia atrás con mancuernas',
    Equipment.bodyweight: 'Zancada hacia atrás',
  },
  Pattern.pushH: {
    Equipment.gym: 'Press de banca con mancuernas',
    Equipment.homeWeights: 'Press de piso con mancuernas',
    Equipment.bodyweight: 'Flexiones de brazos (inclinadas si cuesta)',
  },
  Pattern.pullH: {
    Equipment.gym: 'Remo en polea baja',
    Equipment.homeWeights: 'Remo con mancuerna a una mano',
    Equipment.bodyweight: 'Remo invertido bajo una mesa firme',
  },
  Pattern.pushV: {
    Equipment.gym: 'Press de hombros sentado con mancuernas',
    Equipment.homeWeights: 'Press de hombros con mancuernas',
    Equipment.bodyweight: 'Flexiones pica (pike push-ups)',
  },
  Pattern.pullV: {
    Equipment.gym: 'Jalón al pecho',
    Equipment.homeWeights: 'Jalón con banda elástica',
    Equipment.bodyweight: 'Remo con toalla en una puerta',
  },
  Pattern.core: {
    Equipment.gym: 'Plancha + Pallof press en polea',
    Equipment.homeWeights: 'Plancha + dead bug',
    Equipment.bodyweight: 'Plancha + dead bug',
  },
};

/// Reemplazos amables con cada zona lesionada.
const _substitutes = <Injury, Map<Pattern, String>>{
  Injury.knee: {
    Pattern.squat: 'Sentadilla a un cajón alto (rango sin dolor)',
    Pattern.lunge: 'Puente de glúteo',
  },
  Injury.lowerBack: {
    Pattern.hinge: 'Hip thrust o puente de glúteo',
    Pattern.squat: 'Prensa de piernas o sentadilla goblet a cajón',
  },
  Injury.shoulder: {
    Pattern.pushV: 'Elevaciones laterales livianas (sin dolor)',
    Pattern.pushH: 'Press de pecho con agarre neutro, rango corto',
  },
  Injury.hip: {
    Pattern.lunge: 'Puente de glúteo',
  },
  Injury.ankle: {
    Pattern.lunge: 'Puente de glúteo',
  },
  Injury.wrist: {
    Pattern.pushH: 'Press con mancuernas en agarre neutro',
    Pattern.core: 'Dead bug + plancha sobre antebrazos',
  },
  Injury.neck: {
    Pattern.pushV: 'Elevaciones laterales livianas',
  },
};

const _weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

String weekdayName(int weekday) => _weekdays[weekday - 1];

List<int> _scheduleDays(int n) => switch (n) {
      1 => [3],
      2 => [1, 4],
      3 => [1, 3, 5],
      4 => [1, 2, 4, 5],
      5 => [1, 2, 3, 5, 6],
      _ => [1, 2, 3, 4, 5, 6],
    };

TrainingPlan recommendTraining({
  required Questionnaire questionnaire,
  required BodyComposition composition,
  required int age,
}) {
  final q = questionnaire;
  final reasons = <String>[];
  final cautions = <String>[];

  var days = q.trainingDays;
  if (days == 0) {
    days = 2;
    reasons.add('Empezamos con 2 días de fuerza: es lo mínimo para conservar '
        'músculo mientras bajas grasa.');
  } else if (days == 7) {
    days = 6;
    reasons.add('6 días de entrenamiento y 1 de descanso: el músculo crece '
        'cuando descansa.');
  }

  // Series y rango de repeticiones para registrar y progresar.
  final (sets, repMin, repMax) = switch (q.experience) {
    Experience.none || Experience.beginner => (2, 10, 12),
    Experience.intermediate => (3, 8, 12),
    Experience.advanced => (4, 6, 10),
  };
  final prescription = switch (q.experience) {
    Experience.none || Experience.beginner =>
      '2–3 × 10–12 · deja 3 repeticiones en reserva',
    Experience.intermediate => '3–4 × 8–12 · deja 2 repeticiones en reserva',
    Experience.advanced => '4 × 6–10 · deja 1–2 repeticiones en reserva',
  };
  if (q.experience == Experience.none) {
    reasons.add('Como recién empiezas, las primeras 2 semanas son para '
        'aprender la técnica con poco peso.');
  }

  // Tiempo de fuerza y de cardio por sesión.
  var strength = ((q.sessionMinutes * 0.6) / 5).round() * 5;
  strength = strength.clamp(20, 60);
  var cardio = q.sessionMinutes - strength;
  if (cardio < 10) {
    strength = q.sessionMinutes;
    cardio = 0;
  }

  // Cardio según peso y articulaciones.
  final joints = q.injuries.any(
      (i) => i == Injury.knee || i == Injury.ankle || i == Injury.hip);
  final lowImpact = composition.bmi >= 30 || joints || age >= 60;
  final cardioType = lowImpact
      ? switch (q.equipment) {
          Equipment.gym => 'Bicicleta, elíptica o caminata en cinta inclinada',
          _ => 'Caminata rápida o bicicleta',
        }
      : switch (q.equipment) {
          Equipment.gym => 'Bicicleta, remo, elíptica o trote suave',
          _ => 'Caminata rápida, trote suave o bicicleta',
        };
  if (lowImpact) {
    reasons.add('Cardio de bajo impacto para cuidar tus articulaciones'
        '${composition.bmi >= 30 ? ' mientras bajas de peso' : ''}.');
  }

  // Ejercicios con los reemplazos por lesión.
  String exerciseFor(Pattern p) {
    for (final i in q.injuries) {
      final sub = _substitutes[i]?[p];
      if (sub != null) return sub;
    }
    return _byEquipment[p]![q.equipment]!;
  }

  for (final i in q.injuries) {
    cautions.add('${i.label}: si un ejercicio te da dolor (no cansancio), '
        'detenlo y usa el reemplazo indicado o reduce el rango.');
  }
  if (q.healthConditions.contains(HealthCondition.hypertension)) {
    cautions.add('Presión alta: respira en cada repetición, sin aguantar el '
        'aire, y evita esfuerzos al máximo.');
  }

  double loadStep(Pattern p) {
    if (p == Pattern.core || q.equipment == Equipment.bodyweight) return 0;
    // Piernas y bisagra toleran saltos más grandes que el tren superior.
    return p == Pattern.squat || p == Pattern.hinge ? 2.5 : 1;
  }

  List<Exercise> session(List<Pattern> patterns) {
    final names = <String>{};
    return [
      for (final p in patterns)
        if (names.add(exerciseFor(p)))
          Exercise(
            exerciseFor(p),
            prescription,
            pattern: p,
            sets: sets,
            repMin: repMin,
            repMax: repMax,
            loadStep: loadStep(p),
          ),
    ];
  }

  const fullA = [Pattern.squat, Pattern.pushH, Pattern.pullH, Pattern.hinge, Pattern.core];
  const fullB = [Pattern.hinge, Pattern.pullV, Pattern.pushV, Pattern.lunge, Pattern.core];
  const upper = [Pattern.pushH, Pattern.pullH, Pattern.pushV, Pattern.pullV, Pattern.core];
  const lower = [Pattern.squat, Pattern.hinge, Pattern.lunge, Pattern.core];

  final schedule = _scheduleDays(days);
  final planDays = <TrainingDay>[];
  for (var k = 0; k < schedule.length; k++) {
    final String title;
    final List<Pattern> patterns;
    if (days <= 3) {
      final a = k.isEven;
      title = 'Cuerpo completo ${a ? 'A' : 'B'}';
      patterns = a ? fullA : fullB;
    } else {
      final up = k.isEven;
      title = up ? 'Tren superior' : 'Tren inferior';
      patterns = up ? upper : lower;
    }
    planDays.add(TrainingDay(
      weekday: schedule[k],
      title: title,
      exercises: session(patterns),
      strengthMinutes: strength,
      cardioMinutes: cardio,
    ));
  }
  reasons.add(days <= 3
      ? '$days días de cuerpo completo: cada músculo se entrena 2 o más '
          'veces por semana, lo ideal para conservarlo en déficit.'
      : '$days días alternando tren superior e inferior: más volumen sin '
          'repetir músculos dos días seguidos.');
  reasons.add('Cada sesión: ${fmt(strength)} min de fuerza'
      '${cardio > 0 ? ' y ${fmt(cardio)} min de cardio después' : ''}.');

  return TrainingPlan(
    days: planDays,
    cardio: cardioType,
    zone2: zone2HeartRate(age),
    stepsStart: composition.bmi >= 35 ? 6000 : 7000,
    reasons: reasons,
    cautions: cautions,
    lowImpact: lowImpact,
  );
}
