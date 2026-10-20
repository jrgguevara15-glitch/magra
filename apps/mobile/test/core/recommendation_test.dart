import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/core/recommendation/assessment.dart';
import 'package:magra/core/recommendation/nutrition_plan.dart';
import 'package:magra/core/recommendation/reference_foods.dart';
import 'package:magra/core/recommendation/training_plan.dart';
import 'package:magra/features/profile/user_profile.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

final today = DateTime(2026, 10, 20);

UserProfile profile({int birthYear = 1986, Sex sex = Sex.male, double pace = 0.5}) =>
    UserProfile(
      name: 'Prueba',
      sex: sex,
      birthDate: DateTime(birthYear, 1, 1),
      heightCm: 179,
      paceKgPerWeek: pace,
    );

const base = Questionnaire.initial;

NutritionPlan plan(Questionnaire q, {UserProfile? p, double weight = 123}) =>
    recommendNutrition(
        profile: p ?? profile(), weightKg: weight, questionnaire: q, today: today);

void main() {
  group('Plan nutricional', () {
    test('macros por comida suman el total del día', () {
      final n = plan(base);
      final p = n.meals.fold<double>(0, (a, m) => a + m.protein);
      final c = n.meals.fold<double>(0, (a, m) => a + m.carbs);
      final f = n.meals.fold<double>(0, (a, m) => a + m.fat);
      expect(p, closeTo(n.protein, 1e-6));
      expect(c, closeTo(n.carbs, 1e-6));
      expect(f, closeTo(n.fat, 1e-6));
      expect(n.maintenanceOnly, isFalse);
    });

    test('MAGRA decide el número de comidas según la proteína (3 a 5)', () {
      final n = plan(base);
      // 123 kg, 40 años: 2.085 kcal → 156 g de proteína; tomas de 45 g
      // (0,4 g/kg = 49 g, tope 45) → 3; 16 h despierto exige 4 para no
      // pasar más de 5 h sin comer.
      expect(n.kcal, closeTo(2084.5, 0.1));
      expect(n.protein, closeTo(156.3, 0.1));
      expect(n.meals.length, 4);
      expect(n.reasons.any((r) => r.contains('ideal por toma es ~45 g')), isTrue);
      // Una sola explicación con el número final, sin contradicciones.
      expect(n.reasons.where((r) => r.contains('comidas con ~')), hasLength(1));
      expect(n.reasons.any((r) => r.startsWith('4 comidas')), isTrue);
      // 75 kg: tomas de 30 g → más comidas para la misma lógica.
      final light = plan(base, weight: 75);
      expect(light.reasons.any((r) => r.contains('ideal por toma es ~30 g')), isTrue);
      expect(light.meals.length, 4);
      expect(n.reasons.any((r) => r.contains('más de 5 horas')), isTrue);
    });

    test('respeta las comidas que prefiere el usuario', () {
      expect(plan(base.copyWith(preferredMeals: () => 2)).meals.length, 2);
      expect(plan(base.copyWith(preferredMeals: () => 6)).meals.length, 6);
    });

    test('con poca energía, 3 comidas si el horario lo permite', () {
      final short = base.copyWith(
        wakeTime: const TimeOfDay(hour: 8, minute: 0),
        sleepTime: const TimeOfDay(hour: 21, minute: 0),
      );
      final n = plan(short, p: profile(sex: Sex.female, pace: 0.75), weight: 62);
      expect(n.kcal, lessThan(1600));
      expect(n.meals.length, 3);
      expect(n.reasons.any((r) => r.contains('3 comidas más grandes')), isTrue);
      // Despierta 16 h: gana la regla de no pasar más de 5 h sin comer.
      final long = plan(base, p: profile(sex: Sex.female, pace: 0.75), weight: 62);
      expect(long.meals.length, 4);
    });

    test('glucosa: mínimo 4 comidas y sin ayuno aunque lo pida', () {
      final n = plan(base.copyWith(
        healthConditions: [HealthCondition.type2Diabetes],
        fasting: Fasting.yes,
        preferredMeals: () => 2,
      ));
      expect(n.meals.length, 4);
      expect(n.fastingHours, isNull);
      expect(n.reasons.any((r) => r.startsWith('No incluimos ayuno')), isTrue);
    });

    test('ayuno 16:8 cuando lo pide y es seguro', () {
      final n = plan(base.copyWith(fasting: Fasting.yes));
      expect(n.fastingHours, 16);
      expect(n.meals.length, inInclusiveRange(2, 3));
      final first = n.meals.first.time, last = n.meals.last.time;
      final window = (last.hour * 60 + last.minute) - (first.hour * 60 + first.minute);
      expect(window, lessThanOrEqualTo(8 * 60));
    });

    test('condición supervisada: mantención, sin déficit', () {
      final n = plan(base.copyWith(healthConditions: [HealthCondition.pregnancy]));
      expect(n.maintenanceOnly, isTrue);
      expect(n.reasons.first, contains('mantención'));
    });

    test('horarios: primera comida al despertar, última antes de dormir', () {
      final n = plan(base); // 07:00 a 23:00
      expect(n.meals.first.time, const TimeOfDay(hour: 7, minute: 30));
      expect(n.meals.last.time.hour, lessThanOrEqualTo(20));
    });

    test('ninguna comida durante el entreno; una antes y otra después', () {
      final n = plan(base); // entrena 16:00–17:00
      int m(TimeOfDay t) => t.hour * 60 + t.minute;
      for (final meal in n.meals) {
        final t = m(meal.time);
        expect(t <= 15 * 60 || t >= 17 * 60, isTrue, reason: '${meal.time}');
      }
      final post = n.meals.where((x) => x.role == MealRole.postWorkout);
      expect(post, hasLength(1));
      expect(m(post.first.time) - 17 * 60, inInclusiveRange(0, 120));
      expect(n.meals.where((x) => x.role == MealRole.preWorkout), hasLength(1));
      for (var i = 1; i < n.meals.length; i++) {
        expect(m(n.meals[i].time) - m(n.meals[i - 1].time),
            lessThanOrEqualTo(5 * 60 + 15));
      }
    });

    test('más carbohidratos después de entrenar', () {
      final n = plan(base); // entrena en la tarde 16:00, 60 min
      final post = n.meals.where((m) => m.role == MealRole.postWorkout);
      expect(post, hasLength(1));
      final regular = n.meals.where((m) => m.role == MealRole.regular).first;
      expect(post.first.carbs, greaterThan(regular.carbs));
    });

    test('ejemplos respetan dieta vegana y alergias', () {
      final n = plan(base.copyWith(
          dietPattern: DietPattern.vegan, allergies: [Allergy.gluten, Allergy.soy]));
      final all = n.meals.expand((m) => m.examples.values.expand((e) => e)).join(' | ');
      for (final banned in ['pollo', 'atún', 'huevo', 'yogur', 'quesillo', 'tofu', 'seitán', 'pan integral', 'avena', 'pasta']) {
        expect(all.contains(banned), isFalse, reason: banned);
      }
      expect(all, contains('arroz'));
    });

    test('ejemplos excluyen alimentos que no le gustan', () {
      final foods = allowedFoods(
          base.copyWith(dislikedFoods: 'Atún, palta y merluza'), MacroGroup.protein);
      expect(foods.any((f) => f.name.contains('atún')), isFalse);
      expect(foods.any((f) => f.name.contains('merluza')), isFalse);
      expect(allowedFoods(base.copyWith(dislikedFoods: 'palta'), MacroGroup.fat)
          .any((f) => f.name == 'palta'), isFalse);
    });

    test('porciones caseras', () {
      const huevo = ReferenceFood('huevo', MacroGroup.protein, 12.6,
          unit: 'huevo', unitGrams: 50);
      expect(huevo.portionFor(12.6), '2 huevos');
      expect(huevo.portionFor(25), '4 huevos');
      expect(huevo.portionFor(34), isNull); // 5,5 huevos no es razonable
      expect(referenceFoods.first.portionFor(31), '100 g pechuga de pollo cocida');
    });
  });

  group('Salud y metas', () {
    final big = BodyComposition.from(
        sex: Sex.male, heightCm: 179, weightKg: 123, neckCm: 42, waistCm: 135);

    test('control médico con IMC ≥ 35 o cintura/estatura ≥ 0,6', () {
      final a = healthAlerts(composition: big, questionnaire: base, age: 40);
      expect(a.map((x) => x.title), contains('Recomendamos un control médico'));
      expect(a.any((x) => x.blocking), isFalse);
      final fit = BodyComposition.from(
          sex: Sex.male, heightCm: 179, weightKg: 80, neckCm: 40, waistCm: 85);
      expect(healthAlerts(composition: fit, questionnaire: base, age: 40), isEmpty);
    });

    test('condición supervisada bloquea el déficit', () {
      final a = healthAlerts(
          composition: big,
          questionnaire: base.copyWith(healthConditions: [HealthCondition.kidneyDisease]),
          age: 40);
      expect(a.first.blocking, isTrue);
      expect(a.first.detail, contains('enfermedad renal'));
    });

    test('meta por etapas: primero 10 % del peso', () {
      final g = stagedGoal(
          weightKg: 123, leanKg: 70.7, goalFatPct: 15, dailyDeficitKcal: 750)!;
      expect(g.firstStage.targetWeightKg, closeTo(110.7, 0.01));
      expect(g.firstStage.kgToLose, closeTo(12.3, 0.01));
      expect(g.firstStage.weeks, closeTo(18.0, 0.1));
      expect(g.finalGoal!.targetWeightKg, closeTo(83.18, 0.01));
    });

    test('si la meta está cerca, una sola etapa; sin grasa que perder, nada', () {
      final g = stagedGoal(
          weightKg: 85, leanKg: 70, goalFatPct: 15, dailyDeficitKcal: 500)!;
      expect(g.finalGoal, isNull);
      expect(g.firstStage.targetWeightKg, closeTo(82.35, 0.01));
      expect(stagedGoal(weightKg: 80, leanKg: 70, goalFatPct: 15, dailyDeficitKcal: 500),
          isNull);
    });
  });

  group('Plan de entrenamiento', () {
    final big = BodyComposition.from(
        sex: Sex.male, heightCm: 179, weightKg: 123, neckCm: 42, waistCm: 135);
    final fit = BodyComposition.from(
        sex: Sex.male, heightCm: 179, weightKg: 78, neckCm: 40, waistCm: 82);

    test('3 días: cuerpo completo A/B; 4 días: superior/inferior', () {
      final three = recommendTraining(questionnaire: base, composition: fit, age: 40);
      expect(three.days.map((d) => d.weekday), [1, 3, 5]);
      expect(three.days.first.title, 'Cuerpo completo A');
      final four = recommendTraining(
          questionnaire: base.copyWith(trainingDays: 4), composition: fit, age: 40);
      expect(four.days.map((d) => d.title),
          ['Tren superior', 'Tren inferior', 'Tren superior', 'Tren inferior']);
    });

    test('0 días: empieza con 2; 7 días: deja uno de descanso', () {
      expect(recommendTraining(
              questionnaire: base.copyWith(trainingDays: 0), composition: fit, age: 40)
          .days, hasLength(2));
      expect(recommendTraining(
              questionnaire: base.copyWith(trainingDays: 7), composition: fit, age: 40)
          .days, hasLength(6));
    });

    test('reparte el tiempo entre fuerza y cardio', () {
      final t = recommendTraining(
          questionnaire: base.copyWith(sessionMinutes: 90), composition: fit, age: 40);
      expect(t.days.first.strengthMinutes, 55);
      expect(t.days.first.cardioMinutes, 35);
      final short = recommendTraining(
          questionnaire: base.copyWith(sessionMinutes: 30), composition: fit, age: 40);
      expect(short.days.first.strengthMinutes, 20);
      expect(short.days.first.cardioMinutes, 10);
    });

    test('bajo impacto con IMC ≥ 30 o rodillas; equipo de casa', () {
      final t = recommendTraining(questionnaire: base, composition: big, age: 40);
      expect(t.cardio, isNot(contains('trote')));
      expect(t.stepsStart, 6000);
      final home = recommendTraining(
          questionnaire: base.copyWith(equipment: Equipment.bodyweight),
          composition: fit, age: 40);
      expect(home.days.first.exercises.first.name, 'Sentadilla con peso corporal');
    });

    test('lesiones reemplazan ejercicios y dejan cuidados', () {
      final t = recommendTraining(
          questionnaire: base.copyWith(injuries: [Injury.knee, Injury.lowerBack]),
          composition: fit, age: 40);
      final names = t.days.expand((d) => d.exercises.map((e) => e.name)).toList();
      expect(names, contains('Sentadilla a un cajón alto (rango sin dolor)'));
      expect(names.any((n) => n.contains('Peso muerto')), isFalse);
      expect(names.any((n) => n.startsWith('Zancada')), isFalse);
      expect(t.cautions, hasLength(2));
      for (final d in t.days) {
        final set = d.exercises.map((e) => e.name).toSet();
        expect(set.length, d.exercises.length, reason: 'sin repetidos');
      }
    });

    test('experiencia cambia series y repeticiones', () {
      String rx(Experience e) => recommendTraining(
              questionnaire: base.copyWith(experience: e), composition: fit, age: 40)
          .days.first.exercises.first.prescription;
      expect(rx(Experience.none), startsWith('2–3 × 10–12'));
      expect(rx(Experience.advanced), startsWith('4 × 6–10'));
    });
  });
}
