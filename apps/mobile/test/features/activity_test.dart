import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/core/recommendation/nutrition_plan.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/today/activity_log.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

Widget app({
  Questionnaire? q,
  FakeExerciseLog? exercise,
  FakeFasts? fasts,
  DateTime Function()? clock,
}) =>
    testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
      ]),
      questionnaires: FakeQuestionnaires(q ?? Questionnaire.initial),
      foodLog: FakeFoodLog(),
      exerciseLog: exercise,
      fasts: fasts,
      clock: clock,
    );

Future<void> addExercise(WidgetTester tester, String activity, String minutes) async {
  await tester.tap(find.text('Agregar ejercicio'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<Activity>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(activity).last);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Minutos'), minutes);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
  await tester.pumpAndSettle();
}

void main() {
  group('Ejercicio', () {
    test('calorías netas con el peso actual y mitad para la meta', () {
      final e = ExerciseEntry.fromActivity(activityById('pesas_mod')!, 60,
          date: today, weightKg: 95);
      expect(e.kcalNet, closeTo(237.5, 1e-9)); // (3,5 − 1) × 95 × 1 h
      expect(e.toRow()['kcal_net'], 237.5);
      expect(e.toRow()['done_on'], isNotEmpty);
      final walk = ExerciseEntry.fromActivity(activityById('caminar_5')!, 30,
          date: today, weightKg: 95);
      expect(exerciseBonusFor([e, walk]), closeTo((237.5 + 118.75) / 2, 1e-9));
      expect(exerciseBonusFor(const []), 0);
    });

    testWidgets('anotar ejercicio sube la meta del día y se puede quitar',
        (tester) async {
      setSize(tester, const Size(700, 3000));
      final log = FakeExerciseLog();
      await tester.pumpWidget(app(exercise: log));
      await tester.pumpAndSettle();
      await addExercise(tester, 'Pesas / fuerza moderada', '60');

      expect(log.items.single.minutes, 60);
      expect(find.text('60 min · 238 kcal'), findsOneWidget);
      expect(find.textContaining('+ 119 por ejercicio'), findsOneWidget);
      expect(find.textContaining('Suma +119 kcal'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar Pesas / fuerza moderada'));
      await tester.pumpAndSettle();
      expect(log.items, isEmpty);
      expect(find.textContaining('por ejercicio'), findsNothing);
    });

    testWidgets('pide actividad y minutos válidos', (tester) async {
      setSize(tester, const Size(700, 3000));
      final log = FakeExerciseLog();
      await tester.pumpWidget(app(exercise: log));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar ejercicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Elige la actividad'), findsOneWidget);
      expect(log.items, isEmpty);
    });
  });

  group('Ayuno', () {
    test('progreso, meta cumplida y tope de 24 h', () {
      final start = DateTime(2026, 10, 20, 20);
      final f = Fast(start: start, targetHours: 16);
      expect(f.active, isTrue);
      expect(f.targetEnd, DateTime(2026, 10, 21, 12));
      expect(f.progress(start.add(const Duration(hours: 8))), 0.5);
      expect(f.reached(start.add(const Duration(hours: 15, minutes: 59))), isFalse);
      expect(f.reached(start.add(const Duration(hours: 16))), isTrue);
      expect(f.overLimit(start.add(const Duration(hours: 23))), isFalse);
      expect(f.overLimit(start.add(const Duration(hours: 24))), isTrue);
      expect(fmtDuration(const Duration(hours: 15, minutes: 40)), '15 h 40 min');
      expect(fmtDuration(const Duration(minutes: 5)), '5 min');
      expect(fmtDuration(const Duration(hours: 12)), '12 h');
      expect(fastingProtocols.every((h) => h < fastingHardLimitHours), isTrue);
    });

    test('quién no debe ayunar', () {
      final q = Questionnaire.initial;
      String? reason(List<HealthCondition> c, {int age = 40}) =>
          fastingBlockReason(questionnaire: q.copyWith(healthConditions: c), age: age);
      expect(reason(const []), isNull);
      expect(reason([HealthCondition.type2Diabetes]), contains('glucosa'));
      expect(reason([HealthCondition.hypoglycemia]), contains('glucosa'));
      expect(reason([HealthCondition.eatingDisorder]), contains('trastorno'));
      expect(reason([HealthCondition.pregnancy]), contains('profesional'));
      expect(reason(const [], age: 65), contains('edad'));
    });

    testWidgets('empezar, cumplir, pasar de 24 h y terminar', (tester) async {
      setSize(tester, const Size(700, 3000));
      var clock = today.add(const Duration(hours: 20));
      final fasts = FakeFasts();
      await tester.pumpWidget(app(
        q: Questionnaire.initial.copyWith(fasting: Fasting.yes),
        fasts: fasts,
        clock: () => clock,
      ));
      await tester.pumpAndSettle();

      // El plan con ayuno recomienda 16:8.
      expect(find.text('Ayuno'), findsOneWidget);
      expect(find.textContaining('el que te recomienda MAGRA'), findsOneWidget);
      await tester.tap(find.text('12:12'));
      await tester.pumpAndSettle();
      expect(find.textContaining('MAGRA te recomienda 16:8'), findsOneWidget);
      await tester.tap(find.text('16:8'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Empezar ayuno 16:8'));
      await tester.pumpAndSettle();
      expect(fasts.items.single.targetHours, 16);
      expect(fasts.items.single.start, clock);
      expect(find.text('0 min de 16 h'), findsOneWidget);

      clock = clock.add(const Duration(hours: 10));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('10 h de 16 h'), findsOneWidget);
      expect(find.textContaining('faltan 6 h'), findsOneWidget);

      clock = clock.add(const Duration(hours: 7));
      await tester.pump(const Duration(minutes: 1));
      expect(find.textContaining('¡Cumpliste tu ayuno!'), findsOneWidget);

      clock = clock.add(const Duration(hours: 8));
      await tester.pump(const Duration(minutes: 1));
      expect(find.textContaining('más de 24 h'), findsOneWidget);

      await tester.tap(find.text('Terminar ayuno'));
      await tester.pumpAndSettle();
      expect(fasts.items.single.active, isFalse);
      expect(find.textContaining('Último ayuno: 25 h (meta 16 h) ✓'), findsOneWidget);
      expect(find.text('Empezar ayuno 16:8'), findsOneWidget);
    });

    testWidgets('un ayuno empezado por error se borra', (tester) async {
      setSize(tester, const Size(700, 3000));
      final fasts = FakeFasts();
      await tester.pumpWidget(app(fasts: fasts));
      await tester.pumpAndSettle();
      // Sin ayuno en el plan, lo más suave: 12:12.
      await tester.tap(find.text('Empezar ayuno 12:12'));
      await tester.pumpAndSettle();
      expect(fasts.items.single.targetHours, 12);
      await tester.tap(find.text('Lo empecé por error'));
      await tester.pumpAndSettle();
      expect(fasts.items, isEmpty);
      expect(find.text('Empezar ayuno 12:12'), findsOneWidget);
    });

    testWidgets('no aparece si no quiere ayunar; con glucosa se explica',
        (tester) async {
      setSize(tester, const Size(700, 3000));
      await tester.pumpWidget(app(
          q: Questionnaire.initial.copyWith(fasting: Fasting.no)));
      await tester.pumpAndSettle();
      expect(find.text('Ayuno'), findsNothing);
      expect(find.textContaining('Empezar ayuno'), findsNothing);

      await tester.pumpWidget(app(
          q: Questionnaire.initial.copyWith(
              fasting: Fasting.yes,
              healthConditions: [HealthCondition.type2Diabetes])));
      await tester.pumpAndSettle();
      expect(find.text('Ayuno no recomendado'), findsOneWidget);
      expect(find.textContaining('glucosa'), findsWidgets);
      expect(find.textContaining('Empezar ayuno'), findsNothing);
    });

    testWidgets('el ayuno se muestra solo en el día de hoy', (tester) async {
      setSize(tester, const Size(700, 3000));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Ayuno'), findsOneWidget);
      await tester.tap(find.byTooltip('Día anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Ayuno'), findsNothing);
      expect(find.text('Ejercicio'), findsOneWidget);
    });
  });

  testWidgets('teléfono de 360 px: ayuno, ejercicio y su hoja sin desbordes',
      (tester) async {
    setSize(tester, const Size(360, 3000));
    await tester.pumpWidget(app(
        q: Questionnaire.initial.copyWith(fasting: Fasting.yes)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar ayuno 16:8'));
    await tester.pumpAndSettle();
    await addExercise(tester, 'Fútbol recreativo / pichanga', '90');
    expect(find.text('Terminar ayuno'), findsOneWidget);
    expect(find.textContaining('90 min'), findsOneWidget);
  });
}
