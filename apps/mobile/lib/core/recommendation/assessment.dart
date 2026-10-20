import '../../features/questionnaire/questionnaire.dart';
import '../formulas/formulas.dart';

/// Un aviso para el usuario, del más importante al menos.
class HealthAlert {
  const HealthAlert(this.title, this.detail, {this.blocking = false});

  final String title;
  final String detail;

  /// `true` cuando MAGRA no debe indicar un déficit por su cuenta.
  final bool blocking;
}

/// Avisos de salud según medidas y cuestionario (docs/01_PRODUCTO.md).
List<HealthAlert> healthAlerts({
  required BodyComposition composition,
  required Questionnaire questionnaire,
  required int age,
}) {
  final alerts = <HealthAlert>[];
  final conditions = questionnaire.healthConditions;

  if (questionnaire.needsProfessionalSupervision) {
    final which = [
      for (final c in conditions)
        if (c.supervised) c.label.toLowerCase(),
    ].join(', ');
    alerts.add(HealthAlert(
      'Tu plan debe guiarlo un profesional',
      'Por $which, MAGRA no te indicará un déficit de calorías. Te '
          'mostramos un plan de mantención como base para conversar con tu '
          'médico o nutricionista.',
      blocking: true,
    ));
  }

  final whtr = composition.waistToHeight;
  if (composition.bmi >= 35 || (whtr != null && whtr >= 0.6)) {
    alerts.add(const HealthAlert(
      'Recomendamos un control médico',
      'Tus medidas indican riesgo cardiometabólico alto. Pide un control '
          'de presión, glucosa y colesterol antes de empezar o en paralelo.',
    ));
  }

  if (conditions.contains(HealthCondition.type2Diabetes) ||
      conditions.contains(HealthCondition.prediabetes)) {
    alerts.add(const HealthAlert(
      'Glucosa',
      'Reparte los carbohidratos en el día y prefiere integrales, '
          'legumbres y fruta entera. Si usas insulina u otro medicamento '
          'para la glucosa, avisa a tu médico antes de bajar calorías: '
          'puede necesitar ajustar la dosis.',
    ));
  }

  if (conditions.contains(HealthCondition.hypertension)) {
    alerts.add(const HealthAlert(
      'Presión',
      'Modera la sal y los embutidos, y evita bebidas energéticas. Al '
          'entrenar fuerza, no aguantes la respiración.',
    ));
  }

  if (age >= 65) {
    alerts.add(const HealthAlert(
      'Mayor de 65 años',
      'Prioriza conservar músculo: proteína en cada comida, fuerza 2–3 '
          'veces por semana y bajadas de peso lentas.',
    ));
  }
  return alerts;
}

/// Una etapa hacia la meta.
class GoalStage {
  const GoalStage({
    required this.targetWeightKg,
    required this.kgToLose,
    required this.weeks,
  });

  final double targetWeightKg;
  final double kgToLose;

  /// `null` si no hay déficit.
  final double? weeks;
}

/// Metas por etapas: primero ~10 % del peso (la bajada que más mejora la
/// salud y la más sostenible), después la meta final.
class StagedGoal {
  const StagedGoal({required this.firstStage, required this.finalGoal});

  final GoalStage firstStage;

  /// `null` si la primera etapa ya es la meta final.
  final GoalStage? finalGoal;
}

/// Fracción del peso de la primera etapa.
const double firstStageFraction = 0.10;

StagedGoal? stagedGoal({
  required double weightKg,
  required double leanKg,
  required double goalFatPct,
  required double dailyDeficitKcal,
}) {
  final finalGoal = PhysicalGoal.from(
    weightKg: weightKg,
    leanKg: leanKg,
    goalFatPct: goalFatPct,
    dailyDeficitKcal: dailyDeficitKcal,
  );
  if (finalGoal.fatToLoseKg <= 0) return null;

  double? weeksFor(double kg) => dailyDeficitKcal > 0
      ? kg * kcalPerKgFatTissue / (dailyDeficitKcal * 7)
      : null;

  final finalStage = GoalStage(
    targetWeightKg: finalGoal.goalWeightKg,
    kgToLose: finalGoal.fatToLoseKg,
    weeks: finalGoal.weeks,
  );
  final firstKg = weightKg * firstStageFraction;
  if (finalGoal.fatToLoseKg <= firstKg) {
    return StagedGoal(firstStage: finalStage, finalGoal: null);
  }
  return StagedGoal(
    firstStage: GoalStage(
      targetWeightKg: weightKg - firstKg,
      kgToLose: firstKg,
      weeks: weeksFor(firstKg),
    ),
    finalGoal: finalStage,
  );
}
