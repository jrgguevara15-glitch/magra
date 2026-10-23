import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/recommendation/alt_sessions.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

void main() {
  final q = Questionnaire.initial.copyWith(experience: Experience.intermediate, equipment: Equipment.gym);

  test('catálogo: HYROX, CrossFit, yoga y más, adaptados al equipo', () {
    final ids = altSessionsFor(q).map((s) => s.id).toList();
    expect(ids, containsAll(['hyrox', 'crossfit', 'hiit', 'funcional', 'boxeo', 'cardio_z2', 'yoga', 'pilates', 'movilidad']));
    final gym = altSessionById(q, 'hyrox')!;
    expect(gym.blocks.expand((b) => b.items).join(' '), contains('trineo'));
    final home = altSessionById(q.copyWith(equipment: Equipment.bodyweight), 'hyrox')!;
    expect(home.blocks.expand((b) => b.items).join(' '), isNot(contains('trineo')));
  });

  test('se ocultan las que no convienen: lesiones, bajo impacto, supervisión y principiantes', () {
    final knee = altSessionsFor(q.copyWith(injuries: [Injury.knee])).map((s) => s.id);
    expect(knee, isNot(contains('hyrox')));
    final hiit = altSessionById(q.copyWith(injuries: [Injury.knee]), 'hiit')!;
    expect(hiit.blocks.expand((b) => b.items), isNot(contains('Burpees')));
    expect(altSessionsFor(q, lowImpact: true).map((s) => s.id), isNot(contains('hyrox')));
    final novice = altSessionsFor(q.copyWith(experience: Experience.none));
    expect(novice.map((s) => s.id), isNot(contains('hyrox')));
    expect(novice.firstWhere((s) => s.id == 'crossfit').intensity, Intensity.medium);
    final careful = altSessionsFor(q.copyWith(healthConditions: [HealthCondition.heartDisease]));
    expect(careful.every((s) => s.intensity == Intensity.low), isTrue);
  });

  testWidgets('variar el día con yoga, hacerla, guardarla y volver a la rutina', (tester) async {
    setSize(tester, const Size(700, 4000));
    final choices = FakeTrainingChoices();
    final exercise = FakeExerciseLog();
    final now = DateTime.now();
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([Measurement(id: 'm', date: now, weightKg: 90, neckCm: 40, waistCm: 95)]),
      questionnaires: FakeQuestionnaires(q),
      exerciseLog: exercise,
      choices: choices,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Variar hoy'));
    await tester.pumpAndSettle();
    expect(find.text('HYROX (simulación)'), findsOneWidget);
    await tester.tap(find.text('Yoga vinyasa suave'));
    await tester.pumpAndSettle();
    expect(choices.items.values.single, 'yoga');
    expect(find.text('Hoy variaste tu entreno'), findsOneWidget);
    expect(find.textContaining('Guerrero I y Guerrero II'), findsOneWidget);

    await tester.tap(find.text('2 · Empezar Yoga vinyasa suave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar'));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Terminar y guardar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Minutos'), '40');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final e = exercise.items.single;
    expect(e.activityId, 'alt_yoga');
    expect(e.minutes, 40);
    expect(e.kcalNet, closeTo((3.0 - 1) * 90 * 40 / 60, 1e-9));

    await tester.tap(find.textContaining('Cambiar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver a mi rutina'));
    await tester.pumpAndSettle();
    expect(choices.items, isEmpty);
    expect(find.text('Hoy te toca'), findsOneWidget);
  });
}
