import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/formulas/formulas.dart' show Sex;
import 'package:magra/core/recommendation/exercise_guides.dart';
import 'package:magra/core/recommendation/warmup.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/training/body_map.dart';
import 'package:magra/features/training/mannequin.dart';
import 'package:magra/features/training/mannequin_poses.dart';

const q = Questionnaire.initial;

/// Todos los pasos de calentamiento y estiramiento que puede ver alguien.
Set<String> allDrillNames() {
  final out = <String>{};
  for (final eq in Equipment.values) {
    for (final injuries in [const <Injury>[], Injury.values]) {
      final qq = q.copyWith(equipment: eq, injuries: injuries);
      for (final f in SessionFocus.values) {
        for (final low in [false, true]) {
          for (final d in [
            ...warmUp(focus: f, questionnaire: qq, lowImpact: low),
            ...coolDown(focus: f, questionnaire: qq),
          ]) {
            if (d.muscles.isNotEmpty) out.add(d.name);
          }
        }
      }
    }
  }
  return out;
}

MannequinPainter painterOf(WidgetTester tester) => tester
    .widget<CustomPaint>(find.descendant(of: find.byType(MannequinView), matching: find.byType(CustomPaint)).first)
    .painter! as MannequinPainter;

Pose poseOf(WidgetTester tester) => painterOf(tester).pose;
double yawOf(WidgetTester tester) => painterOf(tester).yaw;

Widget app({bool animate = true, Sex sex = Sex.female}) => ProviderScope(
      overrides: [figureAnimationProvider.overrideWithValue(animate)],
      child: MaterialApp(
        home: Scaffold(
          body: MannequinView(
            anim: animFor('Sentadilla con peso corporal')!,
            sex: sex,
            primary: const {Muscle.quads},
            secondary: const {Muscle.glutes},
          ),
        ),
      ),
    );

void main() {
  test('cada ejercicio y cada paso con músculos tiene su animación', () {
    final moves = {for (final l in exerciseGuides.values) for (final m in l) m.name};
    expect(moves, isNotEmpty);
    for (final n in [...moves, ...allDrillNames()]) {
      expect(animFor(n), isNotNull, reason: n);
    }
  });

  test('las poses quedan apoyadas en el suelo y dentro del encuadre', () {
    for (final n in animatedNames) {
      final a = animFor(n)!;
      for (final female in [false, true]) {
        final frame = Framing.ofAnim(a, female);
        expect(frame.radius, inInclusiveRange(20, 160), reason: n);
        expect(frame.top, inInclusiveRange(30, 260), reason: n);
        for (var i = 0; i <= 10; i++) {
          final pose = a.at(i / 10);
          final sk = solve(pose, female);
          final low = sk.points.values.map((p) => p.y).reduce((x, y) => x < y ? x : y);
          // Nada se hunde en el suelo (salvo sentado o en banco).
          if (pose.rootY == null) expect(low, greaterThan(-1), reason: '$n $i');
          for (final p in sk.points.values) {
            expect(p.x.isFinite && p.y.isFinite && p.z.isFinite, isTrue, reason: n);
          }
        }
      }
    }
  });

  test('la animación va y vuelve entre la primera y la última pose', () {
    final a = animFor('Sentadilla con peso corporal')!;
    expect(a.at(0).trunk, a.keys.first.trunk);
    expect(a.at(0.5).trunk, closeTo(a.keys.last.trunk, 1e-9));
    expect(a.at(1).trunk, closeTo(a.keys.first.trunk, 1e-9));
    expect(a.at(0.25).trunk, inExclusiveRange(a.keys.first.trunk, a.keys.last.trunk));
  });

  testWidgets('el maniquí se mueve solo y se puede pausar', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    final first = poseOf(tester).trunk;
    await tester.pump(const Duration(milliseconds: 600));
    expect(poseOf(tester).trunk, isNot(first));
    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    final paused = poseOf(tester).trunk;
    await tester.pump(const Duration(milliseconds: 600));
    expect(poseOf(tester).trunk, paused);
    expect(find.byTooltip('Reproducir'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('gira con el dedo y con Frente, Lado y Espalda', (tester) async {
    await tester.pumpWidget(app(animate: false));
    await tester.pump();
    expect(find.text('Trabaja más'), findsOneWidget);
    expect(find.text('Ayuda'), findsOneWidget);
    expect(find.byTooltip('Pausar'), findsNothing);
    final start = yawOf(tester);
    await tester.drag(find.bySemanticsLabel(RegExp('Maniquí')), const Offset(-100, 0));
    await tester.pump();
    expect(yawOf(tester), greaterThan(start));
    await tester.tap(find.text('Espalda'));
    await tester.pump();
    expect(yawOf(tester), 180);
    await tester.tap(find.text('Lado'));
    await tester.pump();
    expect(yawOf(tester), 90);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Lado')).selected, isTrue);
  });

  testWidgets('figura de mujer o de hombre según el perfil', (tester) async {
    await tester.pumpWidget(app(animate: false, sex: Sex.male));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Maniquí de hombre')), findsOneWidget);
    await tester.pumpWidget(app(animate: false, sex: Sex.female));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Maniquí de mujer')), findsOneWidget);
  });
}
