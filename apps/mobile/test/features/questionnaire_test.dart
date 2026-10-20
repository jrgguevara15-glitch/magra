import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

Future<void> openProgress(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
  await tester.pumpAndSettle();
}

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.text('Siguiente'));
  await tester.pumpAndSettle();
}

Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.text(label);
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  group('Modelo', () {
    test('ida y vuelta con la fila de Supabase', () {
      final q = Questionnaire.initial.copyWith(
        wakeTime: const TimeOfDay(hour: 6, minute: 30),
        injuries: [Injury.knee, Injury.lowerBack],
        healthConditions: [HealthCondition.hypertension],
        allergies: [Allergy.lactose],
        preferredMeals: () => 3,
        fasting: Fasting.yes,
      );
      final row = q.toRow();
      expect(row['wake_time'], '06:30');
      expect(row['injuries'], ['knee', 'lower_back']);
      expect(row['equipment'], 'gym');
      final back = Questionnaire.fromRow({...row, 'wake_time': '06:30:00'});
      expect(back.wakeTime, const TimeOfDay(hour: 6, minute: 30));
      expect(back.injuries, [Injury.knee, Injury.lowerBack]);
      expect(back.healthConditions, [HealthCondition.hypertension]);
      expect(back.preferredMeals, 3);
      expect(back.fasting, Fasting.yes);
      expect(back.toRow(), row);
    });

    test('códigos desconocidos no rompen la lectura', () {
      final row = Questionnaire.initial.toRow()
        ..['injuries'] = ['knee', 'algo_nuevo']
        ..['budget'] = 'raro';
      final q = Questionnaire.fromRow(row);
      expect(q.injuries, [Injury.knee]);
      expect(q.budget, Budget.medium);
    });

    test('horas despierto, también si se acuesta después de medianoche', () {
      expect(Questionnaire.initial.awakeHours, 16);
      final late = Questionnaire.initial.copyWith(
        wakeTime: const TimeOfDay(hour: 9, minute: 0),
        sleepTime: const TimeOfDay(hour: 1, minute: 30),
      );
      expect(late.awakeHours, 16.5);
    });

    test('condiciones que requieren un profesional', () {
      expect(Questionnaire.initial.needsProfessionalSupervision, isFalse);
      expect(
          Questionnaire.initial.copyWith(
              healthConditions: [HealthCondition.hypertension]).needsProfessionalSupervision,
          isFalse);
      for (final c in [
        HealthCondition.type1Diabetes,
        HealthCondition.pregnancy,
        HealthCondition.eatingDisorder,
        HealthCondition.kidneyDisease,
      ]) {
        expect(
            Questionnaire.initial
                .copyWith(healthConditions: [c]).needsProfessionalSupervision,
            isTrue,
            reason: c.code);
      }
    });
  });

  testWidgets('responder el cuestionario completo y guardarlo', (tester) async {
    setSize(tester, const Size(500, 1600));
    final store = FakeQuestionnaires();
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      questionnaires: store,
    ));
    await tester.pumpAndSettle();
    await openProgress(tester);

    expect(find.text('Cuéntame de ti para armar tu plan'), findsOneWidget);
    await tester.tap(find.text('Responder'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 1 de 4 · Tu rutina'), findsOneWidget);
    await tapChip(tester, 'Turnos rotativos');
    await next(tester);

    expect(find.text('Paso 2 de 4 · Tu entrenamiento'), findsOneWidget);
    await tapChip(tester, '45 min');
    await tapChip(tester, 'Nunca he entrenado');
    await tapChip(tester, 'Rodillas');
    await next(tester);

    expect(find.text('Paso 3 de 4 · Tu salud'), findsOneWidget);
    await tapChip(tester, 'Presión alta');
    expect(find.textContaining('debe guiarlo un médico'), findsNothing);
    await next(tester);

    expect(find.text('Paso 4 de 4 · Tu alimentación'), findsOneWidget);
    await tapChip(tester, 'Vegetariano');
    await tapChip(tester, 'Lactosa');
    await tapChip(tester, '3');
    await tapChip(tester, 'No quiero ayunar');
    await tester.tap(find.text('Guardar respuestas'));
    await tester.pumpAndSettle();

    final q = store.saved!;
    expect(q.workSchedule, WorkSchedule.shifts);
    expect(q.sessionMinutes, 45);
    expect(q.experience, Experience.none);
    expect(q.injuries, [Injury.knee]);
    expect(q.healthConditions, [HealthCondition.hypertension]);
    expect(q.dietPattern, DietPattern.vegetarian);
    expect(q.allergies, [Allergy.lactose]);
    expect(q.preferredMeals, 3);
    expect(q.fasting, Fasting.no);

    // De vuelta en Progreso.
    expect(find.text('Cuestionario completo'), findsOneWidget);
    expect(find.text('3 días de entrenamiento · 3 comidas al día'),
        findsOneWidget);
  });

  testWidgets('condición que requiere profesional muestra el aviso',
      (tester) async {
    setSize(tester, const Size(500, 1600));
    final store = FakeQuestionnaires();
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      questionnaires: store,
    ));
    await tester.pumpAndSettle();
    await openProgress(tester);
    await tester.tap(find.text('Responder'));
    await tester.pumpAndSettle();
    await next(tester);
    await next(tester);

    await tapChip(tester, 'Embarazo');
    expect(find.textContaining('debe guiarlo un médico'), findsOneWidget);
    await next(tester);
    await tester.tap(find.text('Guardar respuestas'));
    await tester.pumpAndSettle();

    expect(store.saved!.needsProfessionalSupervision, isTrue);
    expect(find.text('Tu plan debe guiarlo un profesional de salud.'),
        findsOneWidget);
  });

  testWidgets('editar carga las respuestas guardadas y Atrás funciona',
      (tester) async {
    setSize(tester, const Size(500, 1600));
    final store = FakeQuestionnaires(Questionnaire.initial.copyWith(
      equipment: Equipment.bodyweight,
      trainingDays: 5,
    ));
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      questionnaires: store,
    ));
    await tester.pumpAndSettle();
    await openProgress(tester);

    expect(find.text('5 días de entrenamiento · comidas: MAGRA decide'),
        findsOneWidget);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await next(tester);
    expect(find.text('5 días'), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Solo peso corporal'));
    expect(chip.selected, isTrue);
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 4 · Tu rutina'), findsOneWidget);
  });

  testWidgets('teléfono de 360 px: los 4 pasos sin desbordes', (tester) async {
    setSize(tester, const Size(360, 2000));
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
    ));
    await tester.pumpAndSettle();
    await openProgress(tester);
    await tester.tap(find.text('Responder'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await next(tester);
    }
    expect(find.text('Guardar respuestas'), findsOneWidget);
  });
}
