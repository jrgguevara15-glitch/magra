import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/recommendation/exercise_alternatives.dart';
import 'package:magra/core/recommendation/training_plan.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

Widget app(FakeSwaps swaps, {Questionnaire q = Questionnaire.initial}) => testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
      ]),
      questionnaires: FakeQuestionnaires(q),
      swaps: swaps,
    );

const squat = Exercise('Sentadilla con barra o prensa de piernas', '3 × 8–12', pattern: Pattern.squat, loadStep: 2.5);

void main() {
  test('opciones con el equipo del usuario y sin lo que su lesión desaconseja', () {
    final gym = Questionnaire.initial.copyWith(equipment: Equipment.gym, injuries: const []);
    final names = alternativesFor(squat, gym).map((o) => o.name).toList();
    expect(names, containsAll(['Sentadilla con barra', 'Prensa de piernas', 'Sentadilla goblet']));

    final knee = gym.copyWith(injuries: [Injury.knee]);
    final kneeNames = alternativesFor(squat, knee).map((o) => o.name).toList();
    expect(kneeNames, isNot(contains('Sentadilla con barra')));
    expect(kneeNames, contains('Sentadilla a un cajón'));

    final home = Questionnaire.initial.copyWith(equipment: Equipment.bodyweight, injuries: const []);
    for (final o in alternativesFor(squat, home)) {
      expect(o.equipment, contains(Equipment.bodyweight), reason: o.name);
    }
  });

  test('el cambio mantiene series y repeticiones; sin carga no suma kilos', () {
    final plan = TrainingPlan(
      days: const [
        TrainingDay(weekday: 1, title: 'A', exercises: [squat], strengthMinutes: 40, cardioMinutes: 0),
      ],
      cardio: 'Caminar',
      zone2: (110, 130),
      stepsStart: 6000,
      reasons: const [],
      cautions: const [],
    );
    final out = applySwaps(plan, {squat.name: 'Sentadilla a un cajón'}).days.single.exercises.single;
    expect(out.name, 'Sentadilla a un cajón');
    expect(out.original, squat.name);
    expect(out.slot, squat.name);
    expect(out.prescription, squat.prescription);
    expect(out.loadStep, 0);
    final goblet = applySwaps(plan, {squat.name: 'Sentadilla goblet'}).days.single.exercises.single;
    expect(goblet.loadStep, 2.5);
    expect(identical(applySwaps(plan, const {}), plan), isTrue);
  });

  testWidgets('cambiar un ejercicio de la rutina y volver al original', (tester) async {
    setSize(tester, const Size(700, 5000));
    final swaps = FakeSwaps();
    await tester.pumpWidget(app(swaps));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();

    final first = find.byWidgetPredicate((w) => w is IconButton && (w.tooltip ?? '').startsWith('Cambiar '));
    final tooltip = (tester.widget<IconButton>(first.first)).tooltip!;
    final original = tooltip.substring('Cambiar '.length);
    await tester.tap(first.first);
    await tester.pumpAndSettle();
    expect(find.text('Cambiar $original'), findsWidgets);
    final option = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile)).first;
    final chosen = (tester.widget<ListTile>(option).title as Text).data!;
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(swaps.items[original], chosen);
    expect(find.text(chosen), findsWidgets);

    // Volver al original.
    await tester.tap(find.byTooltip('Cambiar $chosen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver a $original'));
    await tester.pumpAndSettle();
    expect(swaps.items, isEmpty);
  });
}
