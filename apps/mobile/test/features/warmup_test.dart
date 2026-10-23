import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/recommendation/warmup.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/training/demo_player.dart';
import 'package:magra/features/training/guided_routine_page.dart';
import 'package:magra/features/training/mannequin.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);
const q = Questionnaire.initial;

List<String> names(List<Drill> d) => [for (final x in d) x.name];

void main() {
  group('Rutinas', () {
    test('calentamiento por foco, de 5 a 9 minutos, con fotos existentes', () {
      for (final f in SessionFocus.values) {
        final w = warmUp(focus: f, questionnaire: q, lowImpact: false);
        expect(routineMinutes(w), inInclusiveRange(4, 9), reason: '$f');
        expect(w.first.seconds, 150);
        expect(w.last.name, 'Series de aproximación');
        for (final d in w) {
          for (final img in d.images) {
            expect(File(img).existsSync(), isTrue, reason: img);
          }
        }
      }
      final upper = names(warmUp(focus: SessionFocus.upper, questionnaire: q, lowImpact: false));
      expect(upper, contains('Círculos de hombros'));
      expect(upper, isNot(contains('Sentadillas sin peso')));
      final lower = names(warmUp(focus: SessionFocus.lower, questionnaire: q, lowImpact: false));
      expect(lower, contains('Sentadillas sin peso'));
      expect(lower, isNot(contains('Círculos de hombros')));
    });

    test('se adapta a lesiones, impacto y equipo', () {
      final knee = q.copyWith(injuries: [Injury.knee]);
      final k = names(warmUp(focus: SessionFocus.lower, questionnaire: knee, lowImpact: false));
      expect(k, isNot(contains('Sentadillas sin peso')));
      expect(k, isNot(contains('El mejor estiramiento del mundo')));
      expect(k, contains('Puente de glúteo'));
      expect(k.first, contains('Bicicleta o elíptica suave'));
      final soft = names(warmUp(focus: SessionFocus.full,
          questionnaire: q.copyWith(equipment: Equipment.bodyweight), lowImpact: true));
      expect(soft.first, 'Caminata rápida o marcha en el lugar');
      expect(soft, contains('Apertura de brazos (sin banda)'));
      final wrist = names(warmUp(focus: SessionFocus.full,
          questionnaire: q.copyWith(injuries: [Injury.wrist]), lowImpact: false));
      expect(wrist, isNot(contains('Gato-vaca')));
      expect(wrist, isNot(contains('Flexiones inclinadas')));
    });

    test('estiramiento de lo entrenado, 30 s por lado y respiración', () {
      for (final f in SessionFocus.values) {
        final c = coolDown(focus: f, questionnaire: q);
        expect(routineMinutes(c), inInclusiveRange(3, 9), reason: '$f');
        expect(c.last.name, 'Respiración para bajar pulsaciones');
        for (final d in c) {
          for (final img in d.images) {
            expect(File(img).existsSync(), isTrue, reason: img);
          }
        }
      }
      expect(names(coolDown(focus: SessionFocus.lower, questionnaire: q)),
          contains('Pantorrillas en la pared'));
      expect(names(coolDown(focus: SessionFocus.full, questionnaire: q)),
          isNot(contains('Pantorrillas en la pared')));
      final knee = names(coolDown(focus: SessionFocus.full, questionnaire: q.copyWith(injuries: [Injury.knee])));
      expect(knee, contains('Rodilla al pecho'));
      expect(knee, isNot(contains('Estiramiento de cuádriceps')));
      expect(knee, isNot(contains('Postura del niño')));
      const d = Drill('x', seconds: 30, perSide: true, cue: '');
      expect(d.totalSeconds, 60);
      expect(d.dose, '30 s por lado');
      expect(const Drill('y', reps: 10, cue: '').dose, '10 repeticiones');
    });
  });

  Widget app() => testApp(
        auth: FakeAuth(signedIn: true),
        profiles: FakeProfiles(sampleProfile),
        measurements: FakeMeasurements([
          Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
        ]),
        questionnaires: FakeQuestionnaires(q),
      );

  testWidgets('calentamiento guiado: temporizador, repeticiones y final', (tester) async {
    setSize(tester, const Size(700, 4000));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Calentar · ').first);
    await tester.pumpAndSettle();

    expect(find.byType(GuidedRoutinePage), findsOneWidget);
    expect(find.text('1 de ${tester.widget<GuidedRoutinePage>(find.byType(GuidedRoutinePage)).drills.length}'), findsOneWidget);
    expect(find.text('2:30'), findsOneWidget);
    await tester.tap(find.byTooltip('Comenzar'));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('2:20'), findsOneWidget);
    // 2:20 → 0:01 son 139 s; el siguiente tic pasa solo al próximo ejercicio.
    await tester.pump(const Duration(seconds: 139));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Círculos de brazos'), findsWidgets);
    expect(find.text('0:30'), findsOneWidget);

    await tester.tap(find.byTooltip('Pausa'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'Gato-vaca'));
    await tester.pumpAndSettle();
    expect(find.text('8 repeticiones'), findsWidgets);
    await tester.tap(find.text('Listo'));
    await tester.pump(const Duration(milliseconds: 500));

    final drills = tester.widget<GuidedRoutinePage>(find.byType(GuidedRoutinePage)).drills;
    await tester.tap(find.widgetWithText(ListTile, drills.last.name));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('¡Calentamiento completo!'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(GuidedRoutinePage), findsNothing);
  });

  testWidgets('cada día tiene calentar y estirar; tras la sesión ofrece estirar',
      (tester) async {
    setSize(tester, const Size(700, 5000));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Calentar · '), findsWidgets);
    await tester.tap(find.text('Semana'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Estirar · ').first);
    await tester.pumpAndSettle();
    expect(find.text('Estiramiento'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Hoy'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Empezar entreno'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Reps').first, '10');
    await tester.tap(find.text('Terminar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estirar'));
    await tester.pumpAndSettle();
    expect(find.byType(GuidedRoutinePage), findsOneWidget);
    expect(find.text('Estiramiento'), findsOneWidget);
  });

  testWidgets('teléfono de 360 px sin desbordes', (tester) async {
    setSize(tester, const Size(360, 2000));
    await tester.pumpWidget(ProviderScope(
      overrides: [figureAnimationProvider.overrideWithValue(false)],
      child: MaterialApp(
        home: GuidedRoutinePage(
          title: 'Estiramiento',
          drills: coolDown(focus: SessionFocus.full, questionnaire: q),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Estiramiento de cuádriceps'), findsWidgets);
    expect(find.byType(DemoPlayer), findsOneWidget);
    await tester.tap(find.text('Ver fotos del movimiento'));
    await tester.pump();
    expect(find.byType(Image), findsWidgets);
  });
}

