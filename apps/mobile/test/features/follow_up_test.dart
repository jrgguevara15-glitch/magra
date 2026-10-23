import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/platform/device.dart';
import 'package:magra/core/recommendation/follow_up.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

FollowUpState at(int hour, int minute,
        {Set<int> logged = const {},
        bool trainingToday = true,
        bool trained = false,
        double protein = 0,
        int? steps,
        DateTime? lastWeighIn,
        int? since,
        String name = 'Alex',
        int weekday = 3}) =>
    FollowUpState(
      // 21-oct-2026 es miércoles; el 19 es lunes.
      now: DateTime(2026, 10, 18 + weekday, hour, minute),
      name: name,
      mealTimes: const [8 * 60, 13 * 60, 17 * 60, 20 * 60 + 30],
      mealNames: const ['Desayuno', 'Almuerzo', 'Once', 'Cena'],
      loggedMeals: logged,
      proteinEaten: protein,
      proteinTarget: 160,
      sleepMinutes: 23 * 60,
      trainingToday: trainingToday,
      trainingTitle: 'Cuerpo completo A',
      trainingMinutes: 16 * 60,
      trainedToday: trained,
      steps: steps,
      stepsGoal: 7000,
      lastWeighIn: lastWeighIn ?? DateTime(2026, 10, 19),
      daysSinceLog: since,
    );

void main() {
  test('hora de entrenar: avisa 20 min después si no ha empezado', () {
    expect(followUps(at(16, 10)).where((n) => n.kind == NudgeKind.training), isEmpty);
    final n = followUps(at(16, 25, logged: {0, 1})).firstWhere((n) => n.kind == NudgeKind.training);
    expect(n.message, startsWith('Alex, '));
    expect(n.message, contains('Cuerpo completo A'));
    expect(followUps(at(16, 25, trained: true)).where((n) => n.kind == NudgeKind.training), isEmpty);
    expect(followUps(at(16, 25, trainingToday: false)).where((n) => n.kind == NudgeKind.training), isEmpty);
  });

  test('comidas: solo la pendiente más reciente, 90 min después de su hora', () {
    expect(followUps(at(9, 0, logged: {})).where((n) => n.kind == NudgeKind.meal), isEmpty);
    final n = followUps(at(14, 40, logged: {0})).where((n) => n.kind == NudgeKind.meal).toList();
    expect(n.single.mealIndex, 1);
    expect(n.single.title, 'Almuerzo sin anotar');
    // Si la más reciente ya está, no insiste con las anteriores.
    expect(followUps(at(14, 40, logged: {1})).where((n) => n.kind == NudgeKind.meal), isEmpty);
  });

  test('cierre del día: proteína y pasos; nunca cerca de dormir', () {
    final ev = followUps(at(20, 30, logged: {0, 1, 2}, protein: 90, steps: 3000, trained: true));
    expect(ev.map((n) => n.kind), containsAll([NudgeKind.protein, NudgeKind.steps]));
    expect(ev.firstWhere((n) => n.kind == NudgeKind.protein).title, 'Te faltan 70 g de proteína');
    expect(followUps(at(22, 30, logged: {0}, protein: 10, steps: 100)), isEmpty);
  });

  test('pesaje el lunes por la mañana; vuelta tras días sin anotar; sin nombre', () {
    final monday = followUps(at(8, 0, weekday: 1, lastWeighIn: DateTime(2026, 10, 12), trainingToday: false));
    expect(monday.map((n) => n.kind), contains(NudgeKind.weighIn));
    expect(followUps(at(8, 0, weekday: 1, lastWeighIn: DateTime(2026, 10, 19, 7), trainingToday: false))
        .where((n) => n.kind == NudgeKind.weighIn), isEmpty);
    final back = followUps(at(10, 0, since: 3, name: '', trainingToday: false));
    final n = back.firstWhere((n) => n.kind == NudgeKind.comeback);
    expect(n.message, startsWith('Llevas 3 días'));
  });

  testWidgets('Hoy muestra el aviso (teléfono de 360 px), lleva a anotar la comida y se puede descartar', (tester) async {
    setSize(tester, const Size(360, 3000));
    final now = DateTime.now();
    final prefs = MemoryPrefs()..write('magra.followup.enabled', 'meal');
    final q = Questionnaire.initial.copyWith(
      wakeTime: const TimeOfDay(hour: 0, minute: 0),
      sleepTime: const TimeOfDay(hour: 23, minute: 59),
    );
    final log = FakeFoodLog();
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([Measurement(id: 'm', date: now, weightKg: 90)]),
      questionnaires: FakeQuestionnaires(q),
      foodLog: log,
      prefs: prefs,
      clock: () => DateTime(now.year, now.month, now.day, 23, 0),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('sin anotar'), findsOneWidget);
    expect(find.byTooltip('Avisos del coach'), findsOneWidget);
    await tester.tap(find.text('Anotar comida'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Agregar a '), findsOneWidget);
    Navigator.of(tester.element(find.textContaining('Agregar a '))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Descartar aviso'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sin anotar'), findsNothing);
    expect(prefs.read('magra.followup.dismissed'), contains('meal-'));
  });
}
