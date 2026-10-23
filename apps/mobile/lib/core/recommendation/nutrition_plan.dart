import 'package:flutter/material.dart' show TimeOfDay;

import '../../features/profile/user_profile.dart';
import '../../features/questionnaire/questionnaire.dart';
import '../format.dart';
import '../formulas/formulas.dart';
import 'reference_foods.dart';

/// Papel de una comida respecto del entrenamiento.
enum MealRole { regular, preWorkout, postWorkout }

class PlannedMeal {
  const PlannedMeal({
    required this.time,
    required this.role,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.examples,
  });

  final TimeOfDay time;
  final MealRole role;

  /// Gramos de cada macronutriente.
  final double protein;
  final double carbs;
  final double fat;

  /// Ejemplos por grupo: "115 g pechuga de pollo cocida".
  final Map<MacroGroup, List<String>> examples;

  double get kcal => protein * 4 + carbs * 4 + fat * 9;
}

class NutritionPlan {
  const NutritionPlan({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.meals,
    required this.reasons,
    required this.maintenanceOnly,
    this.fastingHours,
    this.tdee = 0,
    this.adjustmentKcal = 0,
    this.bmr = 0,
    this.formula = BmrFormula.mifflin,
  });

  /// Metabolismo basal y con qué fórmula se calculó.
  final double bmr;
  final BmrFormula formula;

  /// Déficit diario respecto del gasto estimado.
  double get deficit => tdee - kcal;

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final List<PlannedMeal> meals;

  /// Por qué el plan es así, en lenguaje de nutricionista.
  final List<String> reasons;

  /// `true` cuando una condición de salud impide indicar déficit.
  final bool maintenanceOnly;

  /// Horas de ayuno diario si el plan lo incluye.
  final int? fastingHours;

  /// Gasto estimado con la fórmula (TMB × actividad).
  final double tdee;

  /// Ajuste semanal incluido en [kcal] (después del mínimo seguro).
  final double adjustmentKcal;
}

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
TimeOfDay _time(int minutes) {
  final m = ((minutes % 1440) + 1440) % 1440;
  return TimeOfDay(hour: m ~/ 60, minute: (m % 60) ~/ 15 * 15);
}

/// Hora aproximada de entrenamiento según el horario elegido.
int? trainingStartMinutes(TrainingTime t) => switch (t) {
      TrainingTime.early => 6 * 60,
      TrainingTime.morning => 9 * 60,
      TrainingTime.midday => 12 * 60 + 30,
      TrainingTime.afternoon => 16 * 60,
      TrainingTime.evening => 19 * 60 + 30,
      TrainingTime.varies => null,
    };

String _hhmm(int minutes) {
  final t = _time(minutes);
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Por qué este usuario no debe ayunar, o `null` si puede hacerlo.
String? fastingBlockReason({
  required Questionnaire questionnaire,
  required int age,
}) {
  final conditions = questionnaire.healthConditions;
  if (conditions.contains(HealthCondition.type1Diabetes) ||
      conditions.contains(HealthCondition.type2Diabetes) ||
      conditions.contains(HealthCondition.hypoglycemia)) {
    return 'por tu glucosa conviene comer a horas regulares';
  }
  if (conditions.contains(HealthCondition.eatingDisorder)) {
    return 'con antecedentes de trastorno alimentario no se recomienda ayunar';
  }
  if (questionnaire.needsProfessionalSupervision) {
    return 'tu plan lo debe guiar un profesional';
  }
  if (age >= 65) return 'a tu edad priorizamos proteína repartida en el día';
  return null;
}

/// Arma el plan nutricional del día para un usuario.
NutritionPlan recommendNutrition({
  required UserProfile profile,
  required double weightKg,
  required Questionnaire questionnaire,
  required DateTime today,
  int kcalAdjustment = 0,
  double? bodyFatPct,
  String fatSource = 'según tus medidas',
  String? basisNote,
}) {
  final q = questionnaire;
  final age = profile.ageOn(today);
  final reasons = <String>[];
  final conditions = q.healthConditions;

  // 1. Calorías y macros.
  final energy = energyTarget(
    sex: profile.sex,
    weightKg: weightKg,
    heightCm: profile.heightCm,
    age: age,
    activityFactor: profile.activityFactor,
    paceKgPerWeek: q.needsProfessionalSupervision ? 0 : profile.paceKgPerWeek,
    split: profile.split,
    bodyFatPct: bodyFatPct,
  );
  final maintenance = q.needsProfessionalSupervision;
  if (maintenance) {
    reasons.add('Calorías de mantención (${fmt(energy.kcal)} kcal): por tu '
        'condición de salud el déficit debe indicarlo un profesional.');
  } else {
    reasons.add('${fmt(energy.kcal)} kcal al día: tu gasto estimado '
        '(${fmt(energy.tdee)} kcal) menos ${fmt(energy.deficit)} kcal para '
        'bajar ~${fmt(profile.paceKgPerWeek, 2)} kg por semana.'
        '${energy.floorApplied ? ' Quedó en el mínimo seguro; no se baja más.' : ''}');
  }
  if (basisNote != null) reasons.add(basisNote);
  reasons.add(energy.formula == BmrFormula.katch
      ? 'Tu metabolismo en reposo (${fmt(energy.bmr)} kcal) se calcula con '
          'Katch-McArdle a partir de tu masa magra (${fmt(weightKg * (1 - bodyFatPct! / 100), 1)} kg, '
          'con ${fmt(bodyFatPct, 1)} % de grasa $fatSource).'
      : 'Tu metabolismo en reposo (${fmt(energy.bmr)} kcal) se calcula con '
          'Mifflin-St Jeor. Si registras cuello y cintura (y cadera, en mujeres), '
          'MAGRA usará Katch-McArdle con tu masa magra, que es más precisa.');
  // Ajuste semanal según el progreso real, sin bajar del mínimo seguro.
  final floor = safeFloorKcal(profile.sex);
  var kcal = energy.kcal;
  if (!maintenance && kcalAdjustment != 0) {
    kcal = energy.kcal + kcalAdjustment;
    if (kcal < floor) kcal = floor < energy.kcal ? floor : energy.kcal;
    final applied = kcal - energy.kcal;
    if (applied != 0) {
      reasons.add('Incluye tu ajuste semanal de ${applied > 0 ? '+' : '−'}'
          '${fmt(applied.abs())} kcal según tu progreso real: '
          '${fmt(kcal)} kcal al día.');
    }
  }
  final scale = kcal / energy.kcal;
  final protein = energy.grams.protein * scale;
  final carbs = energy.grams.carbs * scale;
  final fat = energy.grams.lipids * scale;

  // 2. ¿Puede ayunar?
  final noFastReason = fastingBlockReason(questionnaire: q, age: age);
  final fasting = q.fasting == Fasting.yes && noFastReason == null;
  if (q.fasting == Fasting.yes && noFastReason != null) {
    reasons.add('No incluimos ayuno: $noFastReason.');
  }

  // 3. Cuántas comidas.
  // Toma de proteína que mejor estimula el músculo: ~0,4 g/kg por comida,
  // entre 25 y 45 g; desde los 50 años al menos 35 g.
  final perMealProtein =
      (0.4 * weightKg).clamp(age >= 50 ? 35.0 : 25.0, 45.0).toDouble();
  int meals;
  if (fasting) {
    meals = kcal < 1800 ? 2 : 3;
    reasons.add('Ayuno 16:8 como pediste: $meals comidas en 8 horas.');
  } else if (q.preferredMeals != null) {
    meals = q.preferredMeals!;
    reasons.add('$meals comidas al día, como te acomoda.');
  } else {
    meals = (protein / perMealProtein).round().clamp(3, 5);
    final why = <String>[];
    // No más de 5 horas entre comidas (primera 30 min tras despertar,
    // última 2,5 h antes de dormir).
    final minByGap = ((q.awakeHours - 3) / 5).ceil() + 1;
    if (kcal < 1600 && meals > 3 && minByGap <= 3) {
      meals = 3;
      why.add('con ${fmt(kcal)} kcal, 3 comidas más grandes sacian '
          'mejor que muchas pequeñas');
    }
    if (q.awakeHours < 14 && meals > 4) {
      meals = 4;
      why.add('con ${fmt(q.awakeHours)} horas despierto no hace falta comer '
          'más seguido');
    }
    if (meals < minByGap) {
      meals = minByGap;
      why.add('así no pasas más de 5 horas sin comer en tus '
          '${fmt(q.awakeHours)} horas despierto');
    }
    reasons.add('$meals comidas con ~${fmt(protein / meals)} g de proteína '
        'cada una (tu ideal por toma es ~${fmt(perMealProtein)} g, 0,4 g por '
        'kg de peso): repartir la proteína es lo que mejor conserva músculo '
        'en déficit${why.isEmpty ? '' : '; ${why.join('; ')}'}.');
  }
  final regular = conditions.contains(HealthCondition.type1Diabetes) ||
      conditions.contains(HealthCondition.type2Diabetes) ||
      conditions.contains(HealthCondition.hypoglycemia);
  if (regular && meals < 4) {
    meals = 4;
    reasons.add('Subimos a 4 comidas para mantener estable tu glucosa.');
  }
  meals = meals.clamp(2, 6);

  // 4. Horarios.
  final wake = _minutes(q.wakeTime);
  var sleep = _minutes(q.sleepTime);
  if (sleep <= wake) sleep += 1440;
  late int first;
  late int last;
  int? fastingHours;
  if (fasting) {
    last = sleep - 180;
    first = last - 8 * 60;
    if (first < wake) first = wake + 30;
    fastingHours = 16;
  } else {
    first = wake + 30;
    last = sleep - 150;
  }
  final step = meals == 1 ? 0 : (last - first) / (meals - 1);
  final times = [for (var i = 0; i < meals; i++) (first + step * i).round()];

  // Comidas alrededor del entrenamiento: ninguna durante la sesión, una
  // antes y otra dentro de las 2 horas siguientes.
  final trainStart = trainingStartMinutes(q.trainingTime);
  int? sessionStart;
  if (q.trainingDays > 0 && trainStart != null) {
    var start = trainStart;
    if (start < wake) start += 1440;
    sessionStart = start;
    final end = start + q.sessionMinutes;
    for (var i = 0; i < meals; i++) {
      final t = times[i];
      if (t > start - 60 && t < end + 30) {
        times[i] = (t - (start - 60)) < (end + 30 - t) ? start - 90 : end + 45;
      }
    }
    times.sort();
    final j = times.indexWhere((t) => t >= end);
    if (j >= 0 && times[j] - end > 120) {
      final previous = j > 0 ? times[j - 1] : first;
      final moved = end + 60;
      if (moved - previous >= 120) times[j] = moved;
    }
  }
  if (q.workSchedule == WorkSchedule.night ||
      q.workSchedule == WorkSchedule.shifts) {
    reasons.add('Con turnos, mantén el mismo orden contando desde que '
        'despiertas aunque cambien las horas.');
  }

  // 5. Papel de cada comida respecto del entrenamiento.
  final roles = List.filled(meals, MealRole.regular);
  if (sessionStart != null) {
    final start = sessionStart;
    final end = start + q.sessionMinutes;
    final post = times.indexWhere((t) => t >= end && t - end <= 180);
    final pre = times.lastIndexWhere((t) => t <= start - 60 && start - t <= 240);
    if (post >= 0) roles[post] = MealRole.postWorkout;
    if (pre >= 0 && pre != post) roles[pre] = MealRole.preWorkout;
    if (post < 0 && start >= first && start <= last + 120) {
      reasons.add('Entrenas a las ${_hhmm(start)}: come algo con proteína '
          'dentro de 2 horas después de entrenar.');
    } else if (post >= 0) {
      reasons.add('La comida de las ${_hhmm(times[post])} va después de '
          'entrenar: lleva más carbohidratos para recuperar.');
    }
  }

  // 6. Reparto: proteína pareja; carbohidratos cerca del entrenamiento.
  double carbWeight(int i) => switch (roles[i]) {
        MealRole.postWorkout => 1.5,
        MealRole.preWorkout => 1.3,
        MealRole.regular => i == meals - 1 ? 0.7 : 1.0,
      };
  double fatWeight(int i) => switch (roles[i]) {
        MealRole.postWorkout => 0.7,
        MealRole.preWorkout => 0.6,
        MealRole.regular => 1.0,
      };
  final cw = [for (var i = 0; i < meals; i++) carbWeight(i)];
  final fw = [for (var i = 0; i < meals; i++) fatWeight(i)];
  final cSum = cw.reduce((a, b) => a + b);
  final fSum = fw.reduce((a, b) => a + b);

  final foods = {
    for (final g in MacroGroup.values) g: allowedFoods(q, g),
  };
  List<String> examples(MacroGroup g, double grams, int meal) {
    final list = foods[g]!;
    if (list.isEmpty || grams < 3) return const [];
    final out = <String>[];
    for (var k = 0; k < list.length && out.length < 3; k++) {
      final portion = list[(meal + k) % list.length].portionFor(grams);
      if (portion != null) out.add(portion);
    }
    return out;
  }

  final planned = [
    for (var i = 0; i < meals; i++)
      PlannedMeal(
        time: _time(times[i]),
        role: roles[i],
        protein: protein / meals,
        carbs: carbs * cw[i] / cSum,
        fat: fat * fw[i] / fSum,
        examples: {
          MacroGroup.protein: examples(MacroGroup.protein, protein / meals, i),
          MacroGroup.carb: examples(MacroGroup.carb, carbs * cw[i] / cSum, i),
          MacroGroup.fat: examples(MacroGroup.fat, fat * fw[i] / fSum, i),
        },
      ),
  ];

  return NutritionPlan(
    kcal: kcal,
    protein: protein,
    carbs: carbs,
    fat: fat,
    meals: planned,
    reasons: reasons,
    maintenanceOnly: maintenance,
    fastingHours: fastingHours,
    tdee: energy.tdee,
    adjustmentKcal: kcal - energy.kcal,
    bmr: energy.bmr,
    formula: energy.formula,
  );
}

/// Nombre de cada comida según su hora (desayuno, colación, almuerzo, once,
/// cena). Si se repite, se numera: "Colación 1", "Colación 2".
List<String> mealNames(List<PlannedMeal> meals) {
  String byTime(TimeOfDay t) {
    final m = t.hour * 60 + t.minute;
    if (m < 4 * 60) return 'Cena';
    if (m < 10 * 60 + 30) return 'Desayuno';
    if (m < 12 * 60 + 30) return 'Colación';
    if (m < 15 * 60 + 30) return 'Almuerzo';
    if (m < 18 * 60 + 45) return 'Once';
    return 'Cena';
  }

  final base = [for (final m in meals) byTime(m.time)];
  final seen = <String, int>{};
  return [
    for (final n in base)
      base.where((x) => x == n).length > 1 ? '$n ${seen[n] = (seen[n] ?? 0) + 1}' : n,
  ];
}
