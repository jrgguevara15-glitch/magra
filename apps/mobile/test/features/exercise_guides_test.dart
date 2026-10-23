import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/core/recommendation/exercise_guides.dart';
import 'package:magra/core/recommendation/training_plan.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/training/body_map.dart';
import 'package:magra/features/training/demo_player.dart';
import 'package:magra/features/training/exercise_guide_page.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

void main() {
  test('todo ejercicio que propone el motor tiene ficha y sus fotos existen', () {
    final comp = BodyComposition.from(sex: Sex.male, weightKg: 90, heightCm: 180, neckCm: 40, waistCm: 95);
    final names = <String>{};
    for (final eq in Equipment.values) {
      for (final injuries in [<Injury>[], for (final i in Injury.values) [i]]) {
        for (final days in [3, 4]) {
          final plan = recommendTraining(
            questionnaire: Questionnaire.initial
                .copyWith(equipment: eq, injuries: injuries, trainingDays: days),
            composition: comp,
            age: 40,
          );
          for (final d in plan.days) {
            for (final e in d.exercises) {
              names.add(e.name);
            }
          }
        }
      }
    }
    final missing = [for (final n in names) if (guideFor(n).isEmpty) n];
    expect(missing, isEmpty);
    for (final moves in exerciseGuides.values) {
      for (final m in moves) {
        expect(m.steps.length, greaterThanOrEqualTo(3), reason: m.name);
        expect(m.mistakes, isNotEmpty, reason: m.name);
        for (final img in m.images) {
          expect(File(img).existsSync(), isTrue, reason: img);
        }
      }
    }
    expect(guideFor('No existe'), isEmpty);
  });

  Widget app() => testApp(
        auth: FakeAuth(signedIn: true),
        profiles: FakeProfiles(sampleProfile),
        measurements: FakeMeasurements([
          Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
        ]),
        questionnaires: FakeQuestionnaires(Questionnaire.initial),
      );

  testWidgets('tocar un ejercicio abre su ficha con fotos animadas', (tester) async {
    setSize(tester, const Size(700, 5000));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sentadilla con barra o prensa de piernas').first);
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseGuidePage), findsOneWidget);
    expect(find.text('Sentadilla con barra'), findsOneWidget);
    expect(find.text('Prensa de piernas'), findsOneWidget);
    expect(find.text('Barra olímpica, rack de sentadillas y discos'), findsOneWidget);
    expect(find.text('Cómo hacerlo'), findsNWidgets(2));
    expect(find.textContaining('Rodillas que se van hacia adentro'), findsOneWidget);
    expect(find.text(imageCredit), findsOneWidget);
    // Maniquí 3D primero; las fotos reales, solo si se piden.
    expect(find.byType(DemoPlayer), findsNWidgets(2));
    expect(find.byType(BodyMap), findsNothing);
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.text('Ver fotos del movimiento').first);
    await tester.pumpAndSettle();
    // Las fotos de inicio y fin se alternan solas.
    final seen = <String>{};
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      for (final w in tester.widgetList<Image>(find.byType(Image))) {
        seen.add((w.image as AssetImage).assetName);
      }
    }
    expect(seen, containsAll(['assets/exercises/Barbell_Squat__0.jpg', 'assets/exercises/Barbell_Squat__1.jpg']));
  });

  testWidgets('en la sesión, el ejercicio también abre la ficha', (tester) async {
    setSize(tester, const Size(700, 5000));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar entreno'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseGuidePage), findsOneWidget);
    expect(find.text('Errores comunes'), findsWidgets);
  });
}
