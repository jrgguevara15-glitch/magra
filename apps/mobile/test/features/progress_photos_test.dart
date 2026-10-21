import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/progress/progress_photos.dart';
import 'package:magra/features/progress/progress_photos_card.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';
import '../support/sections.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);
DateTime ago(int d) => today.subtract(Duration(days: d));

ProgressPhoto photo(DateTime d, PhotoPose p) =>
    ProgressPhoto(id: '${d.day}${p.code}', date: d, pose: p, path: 'u/${d.toIso8601String()}_${p.code}.jpg');

final measurements = [
  Measurement(id: 'a', date: ago(60), weightKg: 100, neckCm: 40, waistCm: 108),
  Measurement(id: 'b', date: ago(32), weightKg: 94.5, neckCm: 40, waistCm: 101),
];

Widget app(FakePhotos photos) => testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements(measurements),
      questionnaires: FakeQuestionnaires(Questionnaire.initial),
      photos: photos,
    );

Future<void> openProgress(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
  await tester.pumpAndSettle();
  await openSection(tester, 'Fotos');
}

void main() {
  group('Modelo', () {
    test('ruta dentro de la carpeta del usuario', () {
      final path = photoPath('uid-1', DateTime(2026, 10, 21), PhotoPose.side, 'image/png', Random(1));
      expect(path, matches(RegExp(r'^uid-1/2026-10-21_side_[a-z0-9]{8}\.png$')));
      expect(photoPath('u', DateTime(2026, 1, 2), PhotoPose.front, 'image/jpeg'), endsWith('.jpg'));
    });

    test('días desde la última, fechas y foto por pose', () {
      expect(daysSinceLastPhoto(const [], today), isNull);
      final list = [photo(ago(40), PhotoPose.front), photo(ago(10), PhotoPose.back), photo(ago(10), PhotoPose.front)];
      expect(daysSinceLastPhoto(list, today), 10);
      expect(photoDates(list), [ago(10), ago(40)]);
      expect(photoFor(list, ago(10), PhotoPose.back), isNotNull);
      expect(photoFor(list, ago(40), PhotoPose.side), isNull);
      expect(ProgressPhoto.fromRow({'id': 'x', 'taken_on': '2026-10-21', 'pose': 'side', 'path': 'u/a.jpg'}).pose,
          PhotoPose.side);
    });

    test('medición más cercana a la foto (prefiere la anterior)', () {
      expect(measurementNear(measurements, ago(59))!.id, 'a');
      expect(measurementNear(measurements, ago(1))!.id, 'b');
      expect(measurementNear(measurements, today)!.id, 'b');
      // 15 días después de 'a' vs 13 antes de 'b' (doble peso): gana 'a'.
      expect(measurementNear(measurements, ago(45))!.id, 'a');
      expect(measurementNear(measurements, ago(40))!.id, 'b');
      expect(measurementNear(const [], today), isNull);
    });
  });

  testWidgets('sin fotos: invita a tomarlas y sube frente, perfil y espalda',
      (tester) async {
    setSize(tester, const Size(700, 5000));
    final photos = FakePhotos();
    await tester.pumpWidget(app(photos));
    await tester.pumpAndSettle();
    await openProgress(tester);

    expect(find.textContaining('Toma tus primeras fotos'), findsOneWidget);
    expect(find.text('Comparar'), findsNothing);
    await tester.tap(find.text('Agregar fotos'));
    await tester.pumpAndSettle();
    // En pruebas la plataforma es Android: hay "Tomar foto" y "Elegir foto".
    for (final pose in ['Frente', 'Perfil', 'Espalda']) {
      expect(find.text('Tomar foto · $pose'), findsOneWidget);
      await tester.tap(find.text('Elegir foto'));
      await tester.pumpAndSettle();
    }
    expect(photos.items.map((p) => p.pose), PhotoPose.values);
    expect(photos.items.every((p) => p.date == today), isTrue);
    expect(photos.mediaTypes.first, 'image/png');
    expect(find.textContaining('Subidas el'), findsOneWidget);
    expect(find.textContaining('Frente, Perfil, Espalda'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.textContaining('Próximas fotos en 30 días'), findsOneWidget);
    expect(find.byType(PhotoView), findsNWidgets(3));
  });

  testWidgets('recordatorio a los 30 días, comparar y borrar', (tester) async {
    setSize(tester, const Size(900, 5000));
    final photos = FakePhotos([
      photo(ago(60), PhotoPose.front),
      photo(ago(31), PhotoPose.front),
      photo(ago(31), PhotoPose.side),
    ]);
    await tester.pumpWidget(app(photos));
    await tester.pumpAndSettle();
    await openProgress(tester);
    expect(find.textContaining('Ya pasaron 31 días'), findsOneWidget);

    await tester.tap(find.text('Comparar'));
    await tester.pumpAndSettle();
    expect(find.text('Antes'), findsOneWidget);
    expect(find.text('Después'), findsOneWidget);
    Finder inCompare(Finder f) =>
        find.descendant(of: find.byType(ComparePhotosPage), matching: f);
    expect(inCompare(find.textContaining('100,0 kg')), findsOneWidget);
    expect(inCompare(find.textContaining('94,5 kg')), findsOneWidget);
    expect(find.text('Cambio: −5,5 kg · −7,0 cm de cintura'), findsOneWidget);
    await tester.tap(find.text('Espalda'));
    await tester.pumpAndSettle();
    expect(find.text('Sin foto de espalda'), findsNWidgets(2));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PhotoView).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    expect(photos.items.length, 2);
    expect(find.text('Foto borrada.'), findsOneWidget);
  });

  testWidgets('error al subir se muestra', (tester) async {
    setSize(tester, const Size(700, 5000));
    final photos = FakePhotos()..fail = true;
    await tester.pumpWidget(app(photos));
    await tester.pumpAndSettle();
    await openProgress(tester);
    await tester.tap(find.text('Agregar fotos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir foto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo subir la foto'), findsOneWidget);
  });

  testWidgets('teléfono de 360 px sin desbordes', (tester) async {
    setSize(tester, const Size(360, 5000));
    final photos = FakePhotos([photo(ago(40), PhotoPose.front), photo(ago(2), PhotoPose.front)]);
    await tester.pumpWidget(app(photos));
    await tester.pumpAndSettle();
    await openProgress(tester);
    await tester.tap(find.text('Agregar fotos'));
    await tester.pumpAndSettle();
    expect(find.text('Tomar foto · Frente'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comparar'));
    await tester.pumpAndSettle();
    expect(find.text('Antes'), findsOneWidget);
  });
}
