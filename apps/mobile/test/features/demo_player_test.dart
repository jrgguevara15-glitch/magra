import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/formulas/formulas.dart' show Sex;
import 'package:magra/features/training/body_map.dart';
import 'package:magra/features/training/demo_assets.dart';
import 'package:magra/features/training/demo_player.dart';
import 'package:magra/features/training/mannequin.dart';
import 'package:magra/features/training/mannequin_poses.dart';

/// Ancho y alto de un WebP (VP8X, VP8 o VP8L) leyendo su cabecera.
(int, int) webpSize(Uint8List b) {
  String tag(int o) => String.fromCharCodes(b.sublist(o, o + 4));
  expect(tag(0), 'RIFF');
  expect(tag(8), 'WEBP');
  switch (tag(12)) {
    case 'VP8X':
      return (1 + (b[24] | b[25] << 8 | b[26] << 16), 1 + (b[27] | b[28] << 8 | b[29] << 16));
    case 'VP8L':
      final bits = b[21] | b[22] << 8 | b[23] << 16 | b[24] << 24;
      return (1 + (bits & 0x3FFF), 1 + ((bits >> 14) & 0x3FFF));
    default:
      return ((b[26] | b[27] << 8) & 0x3FFF, (b[28] | b[29] << 8) & 0x3FFF);
  }
}

Widget app(String name, {Sex sex = Sex.female, bool animate = false, bool reduceMotion = false}) => ProviderScope(
      overrides: [figureAnimationProvider.overrideWithValue(animate)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: Scaffold(
              body: SingleChildScrollView(
                child: DemoPlayer(
                  name: name,
                  anim: animFor('Sentadilla con peso corporal')!,
                  sex: sex,
                  primary: const {Muscle.quads},
                ),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  test('cada ejercicio tiene sus 6 hojas (mujer/hombre × 3 vistas) y su miniatura', () {
    final slugs = <String>{};
    for (final name in animatedNames) {
      final a = animFor(name)!;
      expect(slugs.add(demoSlug(name)), isTrue, reason: 'slug repetido: $name');
      final rows = (demoFrameCount(a) + demoColumns - 1) ~/ demoColumns;
      for (final female in [true, false]) {
        for (final v in DemoView.values) {
          final f = File(demoSheet(name, female: female, view: v));
          expect(f.existsSync(), isTrue, reason: f.path);
          final (w, h) = webpSize(f.readAsBytesSync());
          expect((w, h), (demoColumns * demoFrameSize, rows * demoFrameSize), reason: f.path);
        }
        expect(File(demoThumb(name, female: female)).existsSync(), isTrue, reason: name);
      }
    }
  });

  test('el instante del ciclo elige el cuadro (ida, pausa, vuelta y bucle)', () {
    final squat = animFor('Sentadilla con peso corporal')!;
    final n = demoFrameCount(squat);
    expect(demoFrameAt(squat, 0), 0);
    expect(demoFrameAt(squat, 0.55), n - 1); // transición: abajo
    expect(demoFrameAt(squat, 0.3), inExclusiveRange(0, n - 1));
    expect(demoFrameAt(squat, 0.99), lessThan(1));
    for (var k = 0; k < n; k++) {
      expect(demoFrameAt(squat, demoFramePhase(squat, k)), closeTo(k, 1e-6));
    }
    final circles = animFor('Círculos de brazos')!;
    final m = demoFrameCount(circles);
    expect(demoFrameAt(circles, 0.5), m / 2);
    expect(demoFrameAt(circles, 1.0), 0);
  });

  test('vista inicial según el ángulo preferido del ejercicio', () {
    expect(DemoView.closestTo(0), DemoView.front);
    expect(DemoView.closestTo(35), DemoView.front);
    expect(DemoView.closestTo(75), DemoView.side);
    expect(DemoView.closestTo(180), DemoView.back);
    expect(demoSlug('Jalón al pecho'), 'jalon-al-pecho');
    expect(demoSlug('Apertura de brazos (sin banda)'), 'apertura-de-brazos-sin-banda');
  });

  testWidgets('sin imagen, cae al maniquí simple sin romper la pantalla', (tester) async {
    await tester.pumpWidget(app('Ejercicio que no existe'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.byType(MannequinView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controles: vistas, figura, pausa, reinicio y barra', (tester) async {
    await tester.pumpWidget(app('Sentadilla con peso corporal', animate: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Frente'), findsOneWidget);
    expect(find.text('Lado'), findsOneWidget);
    expect(find.text('Espalda'), findsOneWidget);
    // Frente por ser 45° → la vista más cercana es lado o frente.
    await tester.tap(find.text('Espalda'));
    await tester.pump();
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Espalda')).selected, isTrue);
    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    expect(find.byTooltip('Reproducir'), findsOneWidget);
    await tester.tap(find.byTooltip('Reiniciar'));
    await tester.pump();
    expect(find.text('Inicio'), findsOneWidget);
    await tester.tap(find.text('Figura hombre'));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('maniquí de hombre', caseSensitive: false)), findsOneWidget);
    expect(find.text('Trabaja más'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reducir movimiento: parte en pausa, pero se puede reproducir', (tester) async {
    await tester.pumpWidget(app('Sentadilla con peso corporal', animate: true, reduceMotion: true));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Pausar'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.textContaining('reducir movimiento'), findsOneWidget);
    await tester.tap(find.byTooltip('Reproducir'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byTooltip('Pausar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
