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

Widget app({bool animate = true, Sex sex = Sex.female, bool reduceMotion = false, String name = 'Sentadilla con peso corporal'}) =>
    ProviderScope(
      overrides: [figureAnimationProvider.overrideWithValue(animate)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: Scaffold(
              body: SingleChildScrollView(
                child: MannequinView(
                  anim: animFor(name)!,
                  sex: sex,
                  primary: const {Muscle.quads},
                  secondary: const {Muscle.glutes},
                ),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  test('cada ejercicio y cada paso con músculos resuelve su animación', () {
    final moves = {for (final l in exerciseGuides.values) for (final m in l) m.name};
    expect(moves, isNotEmpty);
    for (final n in [...moves, ...allDrillNames()]) {
      final demo = demoFor(n);
      expect(demo, isA<AnimatedDemo>(), reason: n);
      expect((demo as AnimatedDemo).anim, same(animFor(n)), reason: n);
    }
    // Una clave desconocida (o ninguna) cae en la figura estática.
    expect(demoFor('Ejercicio inventado'), isA<StaticDemo>());
    expect(demoFor(null), isA<StaticDemo>());
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

  test('mujer y hombre: misma técnica, mismo equipo y mismo tiempo', () {
    for (final n in animatedNames) {
      final a = animFor(n)!;
      final pf = MannequinPainter(pose: a.at(0.3), female: true, yaw: a.yaw, primary: {}, secondary: {}, props: a.props);
      final pm = MannequinPainter(pose: a.at(0.3), female: false, yaw: a.yaw, primary: {}, secondary: {}, props: a.props);
      // La misma pose y los mismos implementos; solo cambia la figura.
      expect(identical(pf.pose, pm.pose) || pf.pose.trunk == pm.pose.trunk, isTrue, reason: n);
      expect(pf.props, pm.props, reason: n);
      expect(pf.accent, isNot(pm.accent));
    }
  });

  test('cada animación se dibuja (píxeles visibles) en las dos figuras', () {
    for (final n in animatedNames) {
      final a = animFor(n)!;
      for (final female in [false, true]) {
        final px = MannequinPainter(
          pose: a.at(0.5), female: female, yaw: a.yaw, primary: const {Muscle.quads}, secondary: const {},
          props: a.props, framing: Framing.ofAnim(a, female),
        ).rasterize(const Size(90, 110), ss: 1);
        var visible = 0;
        for (var i = 3; i < px.rgba.length; i += 4) {
          if (px.rgba[i] != 0) visible++;
        }
        expect(visible, greaterThan(150), reason: '$n ${female ? 'mujer' : 'hombre'}');
      }
    }
  });

  test('fases: inicio, excéntrica, transición, concéntrica', () {
    final squat = animFor('Sentadilla con peso corporal')!;
    expect(squat.phaseLabel(0.02), 'Inicio');
    expect(squat.phaseLabel(0.3), contains('excéntrica'));
    expect(squat.phaseLabel(0.55), 'Transición');
    expect(squat.phaseLabel(0.8), contains('concéntrica'));
    // En el press se empuja primero.
    expect(animFor('Press de banca con mancuernas')!.phaseLabel(0.3), contains('concéntrica'));
    expect(animFor('Plancha')!.phaseLabel(0.4), contains('Mantén'));
    expect(animFor('Estiramiento de cuádriceps')!.phaseLabel(0.5), 'Mantén y respira');
    expect(animFor('Círculos de brazos')!.phaseLabel(0.5), contains('continuo'));
    // Pausas en el inicio y en la transición; el ciclo cierra donde empezó.
    expect(squat.at(0.05).trunk, squat.keys.first.trunk);
    expect(squat.at(0.55).trunk, closeTo(squat.keys.last.trunk, 1e-9));
    expect(squat.at(1).trunk, closeTo(squat.keys.first.trunk, 1e-9));
    expect(squat.at(0.3).trunk, inExclusiveRange(squat.keys.first.trunk, squat.keys.last.trunk));
  });

  testWidgets('se mueve solo; se pausa, se reanuda y se reinicia', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 800));
    final first = poseOf(tester).trunk;
    await tester.pump(const Duration(milliseconds: 400));
    expect(poseOf(tester).trunk, isNot(first));
    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    final paused = poseOf(tester).trunk;
    await tester.pump(const Duration(milliseconds: 600));
    expect(poseOf(tester).trunk, paused);
    await tester.tap(find.byTooltip('Reproducir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byTooltip('Pausar'), findsOneWidget);
    await tester.tap(find.byTooltip('Reiniciar'));
    await tester.pump();
    expect(find.text('Inicio'), findsOneWidget);
    expect(poseOf(tester).trunk, animFor('Sentadilla con peso corporal')!.keys.first.trunk);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('la barra recorre el movimiento paso a paso', (tester) async {
    await tester.pumpWidget(app(animate: false));
    await tester.pump();
    final slider = find.byType(Slider);
    await tester.tapAt(tester.getTopLeft(slider) + Offset(tester.getSize(slider).width * 0.3, 10));
    await tester.pump();
    expect(find.textContaining('excéntrica'), findsOneWidget);
  });

  testWidgets('reducir movimiento: sin animación y con la barra paso a paso', (tester) async {
    await tester.pumpWidget(app(reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 500));
    final still = poseOf(tester).trunk;
    await tester.pump(const Duration(seconds: 1));
    expect(poseOf(tester).trunk, still);
    expect(find.textContaining('Reducir movimiento está activado'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byTooltip('Pausar'), findsNothing);
  });

  testWidgets('gira con el dedo y con Frente, Lado y Espalda', (tester) async {
    await tester.pumpWidget(app(animate: false));
    await tester.pump();
    expect(find.text('Trabaja más'), findsOneWidget);
    expect(find.text('Ayuda'), findsOneWidget);
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
    // Quitar los colores de músculos deja el maniquí limpio.
    await tester.tap(find.text('Músculos'));
    await tester.pump();
    expect(painterOf(tester).showMuscles, isFalse);
    expect(find.text('Trabaja más'), findsNothing);
  });

  testWidgets('figura según el perfil y elección explícita en el visor', (tester) async {
    await tester.pumpWidget(app(animate: false, sex: Sex.male));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Maniquí de hombre')), findsOneWidget);
    expect(painterOf(tester).female, isFalse);
    await tester.tap(find.text('Figura mujer'));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Maniquí de mujer')), findsOneWidget);
    expect(painterOf(tester).female, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(animate: false, sex: Sex.female));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Maniquí de mujer')), findsOneWidget);
  });

  testWidgets('teléfono de 360 px sin desbordes', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(animate: false, name: 'Press de banca con mancuernas'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
