import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/training/gps_location.dart';
import 'package:magra/features/training/gps_track.dart';

import '../support/fakes.dart';
import '../support/sections.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

/// Punto a [meters] al norte de Santiago centro.
GeoPoint north(double meters, int second, {double accuracy = 5}) => GeoPoint(
      -33.4489 + meters / 111195,
      -70.6693,
      accuracy: accuracy,
      time: DateTime(2026, 10, 21, 8).add(Duration(seconds: second)),
    );

Widget app({FakeExerciseLog? exercise, FakeSteps? steps, StreamController<GeoPoint>? gps}) => testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'm', date: today, weightKg: 80, neckCm: 40, waistCm: 90),
      ]),
      questionnaires: FakeQuestionnaires(Questionnaire.initial),
      foodLog: FakeFoodLog(),
      exerciseLog: exercise,
      steps: steps,
      locations: gps == null ? null : () => gps.stream,
    );

void main() {
  test('distancia entre puntos y filtros del recorrido', () {
    expect(metersBetween(north(0, 0), north(1000, 0)), closeTo(1000, 1));
    final t = GpsTrack(OutdoorMode.run);
    expect(t.add(north(0, 0)), isTrue);
    expect(t.add(north(10, 4)), isTrue); // 2,5 m/s
    expect(t.add(north(20, 8, accuracy: 80)), isFalse); // señal mala
    expect(t.add(north(400, 10)), isFalse); // salto imposible corriendo
    expect(t.add(north(11, 12)), isFalse); // temblor: 1 m
    expect(t.add(north(20, 12)), isTrue);
    expect(t.meters, closeTo(20, 0.5));
    // En pausa se corta el tramo: lo recorrido en pausa no suma.
    t.breakSegment();
    expect(t.add(north(500, 400)), isTrue);
    expect(t.meters, closeTo(20, 0.5));
    expect(t.add(north(510, 404)), isTrue);
    expect(t.meters, closeTo(30, 0.5));
    expect(t.segments, hasLength(2));
  });

  test('MET por velocidad y ritmo', () {
    expect(metFor(OutdoorMode.run, 9.7), closeTo(9.8, 1e-9));
    expect(metFor(OutdoorMode.run, 8.85), closeTo(9.05, 0.01));
    expect(metFor(OutdoorMode.walk, 4.8), closeTo(3.5, 1e-9));
    expect(metFor(OutdoorMode.bike, 40), 12);
    expect(paceLabel(5000, const Duration(minutes: 27, seconds: 30)), '5:30');
    expect(paceLabel(10, const Duration(seconds: 30)), '–');
  });

  testWidgets('GPS: señal débil, corte pasajero y falta de permiso', (tester) async {
    setSize(tester, const Size(700, 3000));
    final gps = StreamController<GeoPoint>.broadcast();
    await tester.pumpWidget(app(gps: gps));
    await tester.pumpAndSettle();
    await openSection(tester, 'Ejercicio');
    await tester.tap(find.text('Correr, caminar o bici con GPS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empezar correr'));
    await tester.pump();
    expect(find.text('Buscando señal GPS…'), findsOneWidget);
    gps.add(north(0, 0, accuracy: 120));
    await tester.pump();
    expect(find.textContaining('Señal débil (±120 m)'), findsOneWidget);
    gps.addError(const GpsException(gpsNoSignalMessage));
    await tester.pump();
    await tester.pump();
    expect(find.text(gpsNoSignalMessage), findsOneWidget);
    gps.add(north(0, 2, accuracy: 8));
    await tester.pump();
    await tester.pump();
    expect(find.text(gpsNoSignalMessage), findsNothing); // se recupera solo
    expect(find.textContaining('Señal GPS lista (±8 m)'), findsOneWidget);
    gps.addError(const GpsException(gpsDeniedMessage, fatal: true));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Sitios web de Safari'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('carrera con GPS: distancia, pausa y se guarda con los km', (tester) async {
    setSize(tester, const Size(700, 3000));
    final log = FakeExerciseLog();
    final gps = StreamController<GeoPoint>.broadcast();
    await tester.pumpWidget(app(exercise: log, gps: gps));
    await tester.pumpAndSettle();
    await openSection(tester, 'Ejercicio');
    await tester.tap(find.text('Correr, caminar o bici con GPS'));
    await tester.pumpAndSettle();
    expect(find.text('Tu recorrido aparecerá aquí.'), findsOneWidget);

    await tester.tap(find.text('Empezar correr'));
    await tester.pump();
    for (var i = 0; i <= 40; i++) {
      gps.add(north(i * 10.0, i * 4));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0,40'), findsOneWidget); // 400 m
    await tester.tap(find.text('Pausar'));
    await tester.pump();
    gps.add(north(2000, 400)); // en pausa: no suma
    await tester.pump();
    expect(find.text('0,40'), findsOneWidget);
    await tester.tap(find.text('Reanudar'));
    await tester.pump();

    await tester.tap(find.text('Terminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminar y guardar'));
    await tester.pumpAndSettle();
    final e = log.items.single;
    expect(e.activityId, 'gps_correr');
    expect(e.distanceKm, closeTo(0.4, 0.01));
    expect(e.name, contains('0,40 km'));
    expect(find.textContaining('0,40 km'), findsWidgets);
    await gps.close();
  });

  testWidgets('pasos: meta del plan y anotarlos', (tester) async {
    setSize(tester, const Size(700, 3000));
    final steps = FakeSteps();
    await tester.pumpWidget(app(steps: steps));
    await tester.pumpAndSettle();
    await openSection(tester, 'Pasos');
    expect(find.textContaining('tu meta de hoy es'), findsOneWidget);
    await tester.tap(find.text('Anotar pasos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Pasos'), '1200');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(steps.items[today], 1200);
    expect(find.textContaining('Te faltan'), findsOneWidget);
    expect(find.textContaining('1.200 / '), findsOneWidget);
  });
}
