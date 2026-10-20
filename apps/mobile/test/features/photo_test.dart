import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/today/photo_analysis.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

PhotoAnalysis plate() => PhotoAnalysis(
      items: [
        PhotoItem(name: 'Arroz', quantity: 150, unit: 'g', kcal: 195, protein: 4, carbs: 42, fat: 0.5),
        PhotoItem(name: 'Pollo a la plancha', quantity: 120, unit: 'g', kcal: 198, protein: 37, carbs: 0, fat: 4.3),
        PhotoItem(name: 'Ensalada', quantity: 80, unit: 'g', kcal: 15, protein: 1, carbs: 3, fat: 0),
      ],
      confidence: 'media',
      notes: 'Buen plato: proteína y verduras.',
    );

Widget app({required FakeFoodLog log, required FakePhotoAnalyzer ai, ImagePickFn? pick}) => testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
      ]),
      questionnaires: FakeQuestionnaires(Questionnaire.initial),
      foodLog: log,
      photoAnalyzer: ai,
      pick: pick,
    );

Future<void> openPhoto(WidgetTester tester) async {
  await tester.tap(find.text('Agregar alimento').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Foto'));
  await tester.pumpAndSettle();
}

void main() {
  group('Modelo', () {
    test('cambiar la cantidad ajusta los nutrientes', () {
      final i = PhotoItem(name: 'Arroz', quantity: 150, unit: 'g', kcal: 195, protein: 4, carbs: 42, fat: 0.5);
      i.scaleTo(300);
      expect(i.kcal, closeTo(390, 1e-9));
      expect(i.carbs, closeTo(84, 1e-9));
      i.scaleTo(0); // ignora cantidades inválidas
      expect(i.quantity, 300);
    });

    test('lee la respuesta del servidor', () {
      final a = PhotoAnalysis.fromJson({
        'items': [
          {'name': 'Pan', 'quantity': 50, 'unit': 'g', 'kcal': 133, 'protein_g': 4.5, 'carbs_g': 28, 'fat_g': 0.5},
        ],
        'confidence': 'alta',
        'notes': 'ok',
      });
      expect(a.items.single.protein, 4.5);
      expect(a.confidence, 'alta');
      expect(PhotoAnalysis.fromJson(const {}).items, isEmpty);
    });

    test('tipo de imagen', () {
      expect(mediaTypeFor('a.PNG', null), 'image/png');
      expect(mediaTypeFor('a.webp', null), 'image/webp');
      expect(mediaTypeFor('foto', null), 'image/jpeg');
      expect(mediaTypeFor('x.png', 'image/heic'), 'image/heic');
    });
  });

  testWidgets('foto → revisar → corregir → agregar', (tester) async {
    setSize(tester, const Size(700, 3000));
    final log = FakeFoodLog();
    final ai = FakePhotoAnalyzer(result: plate());
    await tester.pumpWidget(app(log: log, ai: ai));
    await tester.pumpAndSettle();
    await openPhoto(tester);

    expect(find.textContaining('MAGRA no la guarda'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Aclaración (opcional)'), 'arroz integral');
    await tester.tap(find.text('Elegir foto'));
    await tester.pumpAndSettle();

    expect(ai.calls, 1);
    expect(ai.lastMode, PhotoMode.plate);
    expect(ai.lastNote, 'arroz integral');
    expect(ai.lastMediaType, 'image/png');
    expect(ai.lastRemaining, greaterThan(1000)); // aún no comió nada
    expect(find.textContaining('confianza media'), findsOneWidget);
    expect(find.text('Total: 408 kcal'), findsOneWidget);
    expect(find.text('Buen plato: proteína y verduras.'), findsOneWidget);

    // Duplicar el arroz y quitar la ensalada.
    await tester.enterText(find.widgetWithText(TextField, '150'), '300');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Total: 588 kcal'), findsOneWidget);

    await tester.tap(find.text('Agregar 2 alimentos'));
    await tester.pumpAndSettle();

    expect(log.items, hasLength(2));
    expect(log.items.every((e) => e.source == 'photo'), isTrue);
    expect(log.items.first.quantity, 300);
    expect(log.items.first.kcal, closeTo(390, 1e-9));
    expect(find.text('Arroz'), findsOneWidget); // en el registro del día
  });

  testWidgets('modo etiqueta y cámara en el teléfono', (tester) async {
    setSize(tester, const Size(700, 3000));
    final ai = FakePhotoAnalyzer(result: plate());
    await tester.pumpWidget(app(log: FakeFoodLog(), ai: ai));
    await tester.pumpAndSettle();
    await openPhoto(tester);
    await tester.tap(find.text('Etiqueta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomar foto')); // las pruebas corren como Android
    await tester.pumpAndSettle();
    expect(ai.lastMode, PhotoMode.label);
    expect(ai.lastMediaType, 'image/jpeg');
  });

  testWidgets('errores del servidor se muestran claros', (tester) async {
    setSize(tester, const Size(700, 3000));
    final ai = FakePhotoAnalyzer(error: const PhotoException('Llegaste al límite de 25 fotos por hoy.'));
    await tester.pumpWidget(app(log: FakeFoodLog(), ai: ai));
    await tester.pumpAndSettle();
    await openPhoto(tester);
    await tester.tap(find.text('Elegir foto'));
    await tester.pumpAndSettle();
    expect(find.text('Llegaste al límite de 25 fotos por hoy.'), findsOneWidget);
    expect(find.textContaining(RegExp(r'Agregar \d+ alimentos')), findsNothing);
  });

  testWidgets('sin comida en la foto, explica y no agrega', (tester) async {
    setSize(tester, const Size(700, 3000));
    final ai = FakePhotoAnalyzer(
        result: const PhotoAnalysis(items: [], confidence: 'baja', notes: 'Es una foto de un perro.'));
    await tester.pumpWidget(app(log: FakeFoodLog(), ai: ai));
    await tester.pumpAndSettle();
    await openPhoto(tester);
    await tester.tap(find.text('Elegir foto'));
    await tester.pumpAndSettle();
    expect(find.text('Es una foto de un perro.'), findsOneWidget);
  });

  testWidgets('cancelar la cámara no llama a la IA', (tester) async {
    setSize(tester, const Size(700, 3000));
    final ai = FakePhotoAnalyzer(result: plate());
    Future<PickedImage?> cancel({required bool camera}) async => null;
    await tester.pumpWidget(app(log: FakeFoodLog(), ai: ai, pick: cancel));
    await tester.pumpAndSettle();
    await openPhoto(tester);
    await tester.tap(find.text('Elegir foto'));
    await tester.pumpAndSettle();
    expect(ai.calls, 0);
  });

  testWidgets('teléfono de 360 px: revisión de la foto sin desbordes', (tester) async {
    setSize(tester, const Size(360, 3000));
    await tester.pumpWidget(app(log: FakeFoodLog(), ai: FakePhotoAnalyzer(result: plate())));
    await tester.pumpAndSettle();
    await openPhoto(tester);
    await tester.tap(find.text('Elegir foto'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar 3 alimentos'), findsOneWidget);
  });
}
