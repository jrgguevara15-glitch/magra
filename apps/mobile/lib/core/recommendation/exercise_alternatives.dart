/// Ejercicios parecidos para sustituir uno de la rutina: mismo patrón de
/// movimiento (los mismos músculos principales), filtrados por el equipo
/// que tiene el usuario y por sus lesiones.
library;

import '../../features/questionnaire/questionnaire.dart';
import 'training_plan.dart';

class ExerciseOption {
  const ExerciseOption(this.name, this.equipment, {this.avoid = const {}, this.bodyweight = false});

  final String name;

  /// Con qué equipo se puede hacer.
  final Set<Equipment> equipment;

  /// Lesiones con las que conviene evitarlo.
  final Set<Injury> avoid;

  /// Sin carga externa (no se progresa sumando kilos).
  final bool bodyweight;
}

const _all = {Equipment.gym, Equipment.homeWeights, Equipment.bodyweight};
const _weights = {Equipment.gym, Equipment.homeWeights};
const _gym = {Equipment.gym};

const exerciseOptions = <Pattern, List<ExerciseOption>>{
  Pattern.squat: [
    ExerciseOption('Sentadilla con barra', _gym, avoid: {Injury.knee, Injury.lowerBack}),
    ExerciseOption('Prensa de piernas', _gym, avoid: {Injury.knee}),
    ExerciseOption('Sentadilla goblet', _weights, avoid: {Injury.knee}),
    ExerciseOption('Sentadilla a un cajón', _all, bodyweight: true),
    ExerciseOption('Sentadilla con peso corporal', _all, avoid: {Injury.knee}, bodyweight: true),
  ],
  Pattern.hinge: [
    ExerciseOption('Peso muerto rumano con barra', _gym, avoid: {Injury.lowerBack}),
    ExerciseOption('Peso muerto rumano con mancuernas', _weights, avoid: {Injury.lowerBack}),
    ExerciseOption('Hip thrust', _weights),
    ExerciseOption('Puente de glúteo', _all, bodyweight: true),
    ExerciseOption('Puente de glúteo a una pierna', _all, bodyweight: true),
  ],
  Pattern.lunge: [
    ExerciseOption('Zancada con mancuernas', _weights, avoid: {Injury.knee, Injury.hip, Injury.ankle}),
    ExerciseOption('Zancada hacia atrás con mancuernas', _weights, avoid: {Injury.knee, Injury.hip, Injury.ankle}),
    ExerciseOption('Zancada hacia atrás', _all, avoid: {Injury.knee, Injury.hip, Injury.ankle}, bodyweight: true),
    ExerciseOption('Puente de glúteo a una pierna', _all, bodyweight: true),
    ExerciseOption('Puente de glúteo', _all, bodyweight: true),
  ],
  Pattern.pushH: [
    ExerciseOption('Press de banca con mancuernas', _gym, avoid: {Injury.shoulder}),
    ExerciseOption('Press con mancuernas en agarre neutro', _gym),
    ExerciseOption('Press de piso con mancuernas', _weights),
    ExerciseOption('Flexiones de brazos', _all, avoid: {Injury.wrist, Injury.shoulder}, bodyweight: true),
    ExerciseOption('Flexiones inclinadas', _all, avoid: {Injury.wrist}, bodyweight: true),
  ],
  Pattern.pullH: [
    ExerciseOption('Remo en polea baja', _gym),
    ExerciseOption('Remo con mancuerna a una mano', _weights),
    ExerciseOption('Remo invertido', _all, bodyweight: true),
    ExerciseOption('Remo con toalla en una puerta', _all, bodyweight: true),
  ],
  Pattern.pushV: [
    ExerciseOption('Press de hombros sentado con mancuernas', _weights, avoid: {Injury.shoulder, Injury.neck}),
    ExerciseOption('Press de hombros con mancuernas', _weights, avoid: {Injury.shoulder, Injury.neck, Injury.lowerBack}),
    ExerciseOption('Elevaciones laterales', _weights),
    ExerciseOption('Flexiones pica', _all, avoid: {Injury.shoulder, Injury.wrist, Injury.neck}, bodyweight: true),
  ],
  Pattern.pullV: [
    ExerciseOption('Jalón al pecho', _gym),
    ExerciseOption('Jalón con banda elástica', _weights),
    ExerciseOption('Remo con toalla en una puerta', _all, bodyweight: true),
    ExerciseOption('Remo invertido', _all, bodyweight: true),
  ],
  Pattern.core: [
    ExerciseOption('Plancha', _all, avoid: {Injury.wrist}, bodyweight: true),
    ExerciseOption('Pallof press', _weights),
    ExerciseOption('Dead bug', _all, bodyweight: true),
  ],
};

/// Opciones parecidas a [e] que el usuario puede hacer, sin repetir la
/// actual. Las que conviene evitar por una lesión no aparecen.
List<ExerciseOption> alternativesFor(Exercise e, Questionnaire q) {
  final injuries = q.injuries.toSet();
  return [
    for (final o in exerciseOptions[e.pattern] ?? const <ExerciseOption>[])
      if (o.name != e.name && o.equipment.contains(q.equipment) && o.avoid.intersection(injuries).isEmpty) o,
  ];
}

/// La rutina con los cambios del usuario ([swaps]: nombre original →
/// elegido). Se mantienen series, repeticiones y día; si el nuevo es sin
/// carga, no se progresa en kilos.
TrainingPlan applySwaps(TrainingPlan plan, Map<String, String> swaps) {
  if (swaps.isEmpty) return plan;
  Exercise swap(Exercise e) {
    final chosen = swaps[e.name];
    if (chosen == null) return e;
    final opt = exerciseOptions[e.pattern]?.where((o) => o.name == chosen).firstOrNull;
    return Exercise(
      chosen,
      e.prescription,
      pattern: e.pattern,
      sets: e.sets,
      repMin: e.repMin,
      repMax: e.repMax,
      loadStep: opt?.bodyweight ?? false ? 0 : (e.loadStep == 0 ? 1 : e.loadStep),
      original: e.name,
    );
  }

  return TrainingPlan(
    days: [
      for (final d in plan.days)
        TrainingDay(
          weekday: d.weekday,
          title: d.title,
          exercises: [for (final e in d.exercises) swap(e)],
          strengthMinutes: d.strengthMinutes,
          cardioMinutes: d.cardioMinutes,
        ),
    ],
    cardio: plan.cardio,
    zone2: plan.zone2,
    stepsStart: plan.stepsStart,
    reasons: plan.reasons,
    cautions: plan.cautions,
    lowImpact: plan.lowImpact,
  );
}
