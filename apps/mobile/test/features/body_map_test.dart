import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/core/recommendation/exercise_guides.dart';
import 'package:magra/core/recommendation/warmup.dart';
import 'package:magra/core/theme.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/training/body_map.dart';

String label(WidgetTester tester) => tester
    .widget<Semantics>(find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label ?? '').contains('vista de')))
    .properties
    .label!;

void main() {
  test('nombres de músculos → zonas de la figura', () {
    expect(musclesFromNames(['Cuádriceps', 'Glúteos']), {Muscle.quads, Muscle.glutes});
    expect(musclesFromNames(['Core']), {Muscle.abs, Muscle.obliques});
    expect(musclesFromNames(['Core (oblicuos)']), {Muscle.obliques});
    expect(musclesFromNames(['Hombros (deltoides lateral)']), {Muscle.shoulders});
    expect(musclesFromNames(['Dorsales', 'Romboides', 'Bíceps']),
        {Muscle.lats, Muscle.midBack, Muscle.biceps});
    expect(musclesFromNames(['Espalda baja', 'Pantorrillas', 'Trapecio']),
        {Muscle.lowerBack, Muscle.calves, Muscle.traps});
    final split = splitMuscles(['Cuádriceps', 'Glúteos', 'Aductores', 'Core']);
    expect(split.primary, {Muscle.quads, Muscle.glutes});
    expect(split.secondary, {Muscle.adductors, Muscle.abs, Muscle.obliques});
    expect(splitMuscles(['Core', 'Hombros']).primary, {Muscle.abs, Muscle.obliques});
  });

  test('toda ficha y todo ejercicio de calentamiento marca al menos un músculo', () {
    for (final moves in exerciseGuides.values) {
      for (final m in moves) {
        expect(musclesFromNames(m.muscles), isNotEmpty, reason: m.name);
      }
    }
    for (final f in SessionFocus.values) {
      for (final d in [
        ...warmUp(focus: f, questionnaire: Questionnaire.initial, lowImpact: false),
        ...coolDown(focus: f, questionnaire: Questionnaire.initial),
      ]) {
        if (d.muscles.isEmpty) continue; // aproximación y respiración
        expect(musclesFromNames(d.muscles), isNotEmpty, reason: d.name);
      }
    }
  });

  Widget app(Sex sex, Set<Muscle> primary) => ProviderScope(
        child: MaterialApp(
          theme: MagraTheme.neon(),
          home: Scaffold(body: SingleChildScrollView(
              child: BodyMap(sex: sex, primary: primary))),
        ),
      );

  testWidgets('empieza mirando lo trabajado y gira con botón, toque y arrastre',
      (tester) async {
    await tester.pumpWidget(app(Sex.female, {Muscle.glutes, Muscle.hamstrings}));
    await tester.pumpAndSettle();
    expect(label(tester), matches(RegExp('mujer, vista de espalda')));

    await tester.tap(find.text('Frente'));
    await tester.pumpAndSettle();
    expect(label(tester), matches(RegExp('vista de frente')));

    await tester.tap(find.byTooltip('Girar'));
    await tester.pumpAndSettle();
    expect(label(tester), matches(RegExp('vista de espalda')));

    await tester.drag(find.byType(CustomPaint).first, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(label(tester), matches(RegExp('vista de (frente|espalda)')));

    await tester.pumpWidget(app(Sex.male, {Muscle.chest}));
    await tester.pumpAndSettle();
    expect(label(tester), matches(RegExp('hombre, vista de frente')));
  });
}
