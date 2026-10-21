import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/core/recommendation/progression.dart';
import 'package:magra/core/recommendation/training_plan.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

const squat = Exercise('Sentadilla', '3 × 8–12', pattern: Pattern.squat,
    sets: 3, repMin: 8, repMax: 12, loadStep: 2.5);
const press = Exercise('Press', '3 × 8–12', pattern: Pattern.pushH,
    sets: 3, repMin: 8, repMax: 12, loadStep: 1);
const pushUp = Exercise('Flexiones', '2 × 10–12', pattern: Pattern.pushH,
    sets: 2, repMin: 10, repMax: 12);

ExerciseLog log(String name, double kg, List<int> reps) =>
    ExerciseLog(name: name, sets: [for (final r in reps) SetLog(r, kg)]);

TrainingPlan plan(Questionnaire q) => recommendTraining(
      questionnaire: q,
      composition: BodyComposition.from(
          sex: Sex.male, weightKg: 95, heightCm: 180, neckCm: 40, waistCm: 100),
      age: 40,
    );

Widget app(FakeWorkouts workouts, {FakeExerciseLog? exercise, Questionnaire? q}) => testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
      ]),
      questionnaires: FakeQuestionnaires(q ?? Questionnaire.initial),
      workouts: workouts,
      exerciseLog: exercise,
    );

Future<void> openTraining(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.fitness_center_outlined));
  await tester.pumpAndSettle();
}

void main() {
  group('Doble progresión', () {
    test('sin historial: elegir peso / hacer el rango', () {
      final t = nextTarget(squat, const []);
      expect(t.kg, isNull);
      expect(t.reps, 8);
      expect(t.note, contains('Primera vez'));
      expect(nextTarget(pushUp, const []).note, contains('2 series de 10–12'));
    });

    test('todas las series al tope: sube 2,5 kg piernas, 1 kg el resto', () {
      final t = nextTarget(squat, [log('Sentadilla', 60, [12, 12, 12])]);
      expect(t.kg, 62.5);
      expect(t.reps, 8);
      expect(t.note, contains('62,5 kg'));
      expect(nextTarget(press, [log('Press', 20, [12, 12, 13])]).kg, 21);
    });

    test('dentro del rango: misma carga y una repetición más', () {
      final t = nextTarget(squat, [log('Sentadilla', 60, [12, 10, 9])]);
      expect(t.kg, 60);
      expect(t.reps, 10);
      expect(t.deload, isFalse);
    });

    test('series de calentamiento con menos peso no cuentan', () {
      final warm = ExerciseLog(name: 'Sentadilla', sets: const [
        SetLog(12, 40), SetLog(12, 60), SetLog(12, 60), SetLog(12, 60),
      ]);
      expect(nextTarget(squat, [warm]).kg, 62.5);
    });

    test('3 sesiones seguidas bajo el mínimo con la misma carga: descarga 10 %', () {
      final fail = log('Sentadilla', 80, [8, 7, 6]);
      final t = nextTarget(squat, [fail, fail, fail]);
      expect(t.deload, isTrue);
      expect(t.kg, 72);
      expect(nextTarget(squat, [log('Sentadilla', 75, [8, 7, 6]), fail, fail]).deload, isFalse);
    });

    test('peso corporal: al tope, más reps o variante más difícil', () {
      final t = nextTarget(pushUp, [log('Flexiones', 0, [12, 12])]);
      expect(t.note, contains('variante más difícil'));
      expect(nextTarget(pushUp, [log('Flexiones', 0, [10, 11])]).reps, 11);
    });

    test('historial por ejercicio y sesión que toca en la rotación', () {
      final p = plan(Questionnaire.initial);
      expect(p.days.map((d) => d.title).toSet(), {'Cuerpo completo A', 'Cuerpo completo B'});
      final first = p.days.first.exercises.first;
      expect(first.sets, 2);
      expect(first.loadStep, 2.5);
      expect(p.days.first.exercises.last.loadStep, 0); // core
      expect(nextSession(p, const []).title, 'Cuerpo completo A');
      final a = WorkoutSession(date: today.subtract(const Duration(days: 2)),
          title: 'Cuerpo completo A', minutes: 40, exercises: [log('X', 10, [10])]);
      final b = WorkoutSession(date: today.subtract(const Duration(days: 4)),
          title: 'Cuerpo completo B', minutes: 40, exercises: [log('X', 5, [10])]);
      expect(nextSession(p, [a, b]).title, 'Cuerpo completo B');
      expect(historyOf('X', [a, b]).map((e) => e.topKg), [5, 10]);
      expect(a.volume, 100);
      final row = a.toRow();
      expect(WorkoutSession.fromRow({...row, 'id': 'z'}).exercises.single.sets.single.kg, 10);

      final bw = plan(Questionnaire.initial.copyWith(equipment: Equipment.bodyweight));
      expect(bw.days.first.exercises.every((e) => e.loadStep == 0), isTrue);
      final upper = plan(Questionnaire.initial.copyWith(trainingDays: 4));
      expect(nextSession(upper, [a.copyWithTitle('Tren superior')]).title, 'Tren inferior');
    });
  });

  testWidgets('registrar la sesión: guarda series y suma las calorías a Hoy',
      (tester) async {
    setSize(tester, const Size(700, 5000));
    final workouts = FakeWorkouts();
    final exercise = FakeExerciseLog();
    await tester.pumpWidget(app(workouts, exercise: exercise));
    await tester.pumpAndSettle();
    await openTraining(tester);

    expect(find.text('Hoy te toca'), findsOneWidget);
    expect(find.text('Cuerpo completo A'), findsWidgets);
    await tester.tap(find.text('2 · Empezar sesión'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Primera vez'), findsWidgets);

    await tester.tap(find.text('Terminar sesión'));
    await tester.pumpAndSettle();
    expect(find.textContaining('al menos una serie'), findsOneWidget);

    final reps = find.widgetWithText(TextField, 'Reps');
    final kg = find.widgetWithText(TextField, 'Kg');
    await tester.enterText(reps.at(0), '12');
    await tester.enterText(kg.at(0), '60');
    await tester.enterText(reps.at(1), '12');
    await tester.enterText(kg.at(1), '60');
    await tester.tap(find.text('Terminar sesión'));
    await tester.pumpAndSettle();

    final s = workouts.items.single;
    expect(s.title, 'Cuerpo completo A');
    expect(s.date, today);
    expect(s.exercises.single.sets.length, 2);
    expect(s.exercises.single.topKg, 60);
    expect(exercise.items.single.activityId, 'pesas_mod');
    expect(exercise.items.single.minutes, s.minutes);
    expect(find.textContaining('Sesión guardada'), findsOneWidget);
    expect(find.text('Próxima sesión'), findsOneWidget);
    expect(find.text('Cuerpo completo B'), findsWidgets);
    expect(find.textContaining('2 series · 1.440 kg movidos'), findsOneWidget);
  });

  testWidgets('la sesión siguiente sugiere la carga nueva', (tester) async {
    setSize(tester, const Size(700, 5000));
    final p = plan(Questionnaire.initial);
    final squatName = p.days.first.exercises.first.name;
    final workouts = FakeWorkouts([
      WorkoutSession(id: 'a', date: today.subtract(const Duration(days: 4)), title: 'Cuerpo completo A',
          minutes: 40, exercises: [log(squatName, 60, [12, 12])]),
      WorkoutSession(id: 'b', date: today.subtract(const Duration(days: 2)), title: 'Cuerpo completo B',
          minutes: 40, exercises: [log('Otro', 10, [10, 10])]),
    ]);
    await tester.pumpWidget(app(workouts));
    await tester.pumpAndSettle();
    await openTraining(tester);
    await tester.tap(find.text('2 · Empezar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Hoy: 62,5 kg × 10'), findsOneWidget);
    expect(find.widgetWithText(TextField, '62,5'), findsNWidgets(2));
  });

  testWidgets('borrar una sesión del historial', (tester) async {
    setSize(tester, const Size(700, 5000));
    final workouts = FakeWorkouts([
      WorkoutSession(id: 'a', date: today, title: 'Cuerpo completo A',
          minutes: 40, exercises: [log('X', 10, [10])]),
    ]);
    await tester.pumpWidget(app(workouts));
    await tester.pumpAndSettle();
    await openTraining(tester);
    await tester.tap(find.byTooltip('Borrar sesión del ${today.day}-${const ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'][today.month - 1]}-${today.year}'));
    await tester.pumpAndSettle();
    expect(workouts.items, isEmpty);
    expect(find.text('Hoy te toca'), findsOneWidget);
  });

  testWidgets('teléfono de 360 px: sesión sin desbordes', (tester) async {
    setSize(tester, const Size(360, 5000));
    await tester.pumpWidget(app(FakeWorkouts(),
        q: Questionnaire.initial.copyWith(experience: Experience.advanced, trainingDays: 4)));
    await tester.pumpAndSettle();
    await openTraining(tester);
    await tester.tap(find.text('2 · Empezar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Serie').first);
    await tester.pumpAndSettle();
    expect(find.text('Serie 5'), findsOneWidget);
  });
}

extension on WorkoutSession {
  WorkoutSession copyWithTitle(String t) =>
      WorkoutSession(date: date, title: t, minutes: minutes, exercises: exercises);
}
