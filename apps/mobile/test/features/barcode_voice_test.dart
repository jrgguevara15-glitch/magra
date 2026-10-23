import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/today/barcode.dart';
import 'package:magra/features/today/photo_analysis.dart';

import '../support/fakes.dart';
import '../support/sections.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

const yogurt = Product(
  code: '7802900001234',
  name: 'Yogur protein',
  brand: 'Marca',
  unit: 'g',
  kcal100: 60,
  protein100: 10,
  carbs100: 4,
  fat100: 0.5,
  servingQuantity: 155,
);

Widget app({
  required FakeFoodLog log,
  FakePhotoAnalyzer? ai,
  FakeProductLookup? products,
  FakeCustomProducts? customProducts,
  BarcodeScanFn? scan,
}) =>
    testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
      ]),
      questionnaires: FakeQuestionnaires(Questionnaire.initial),
      foodLog: log,
      photoAnalyzer: ai,
      products: products,
      customProducts: customProducts,
      scan: scan,
    );

Future<void> openMode(WidgetTester tester, String mode) async {
  await tester.tap(addFoodButton().first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(mode));
  await tester.pumpAndSettle();
}

void main() {
  group('Open Food Facts', () {
    test('lee el producto; kJ → kcal, líquidos en ml, primera marca', () {
      final p = Product.fromOpenFoodFacts('7801620001234', {
        'product_name': 'Leche descremada',
        'brands': 'Colun, Otra',
        'quantity': '1 L',
        'serving_quantity': '200',
        'nutriments': {
          'energy_100g': 146.4, // kJ
          'proteins_100g': 3.2,
          'carbohydrates_100g': '4,8',
          'fat_100g': 0.1,
        },
      });
      expect(p.name, 'Leche descremada');
      expect(p.brand, 'Colun');
      expect(p.fullName, 'Leche descremada (Colun)');
      expect(p.unit, 'ml');
      expect(p.kcal100, closeTo(35, 0.01));
      expect(p.carbs100, 4.8);
      expect(p.servingQuantity, 200);
      expect(p.nutrientsFor(250).protein, closeTo(8, 1e-9));
    });

    test('prefiere el nombre en español y tolera datos faltantes', () {
      final p = Product.fromOpenFoodFacts('12345678', {
        'product_name': 'Crackers',
        'product_name_es': 'Galletas',
        'serving_quantity': 99999,
      });
      expect(p.name, 'Galletas');
      expect(p.brand, isNull);
      expect(p.unit, 'g');
      expect(p.kcal100, isNull);
      expect(p.servingQuantity, isNull);
      expect(Product.fromOpenFoodFacts('12345678', {}).name, 'Producto 12345678');
    });

    test('código: solo dígitos, entre 8 y 14', () {
      expect(normalizeBarcode(' 780 2900-001234 '), '7802900001234');
      expect(normalizeBarcode('1234567'), isNull);
      expect(normalizeBarcode('123456789012345'), isNull);
      expect(normalizeBarcode('abc'), isNull);
    });

    test('consulta la API y maneja no encontrado y errores', () async {
      Uri? asked;
      Future<http.Response> reply(http.Request r, int status, Object body) async {
        asked = r.url;
        return http.Response.bytes(utf8.encode(jsonEncode(body)), status);
      }

      final found = OpenFoodFactsLookup(MockClient((r) => reply(r, 200, {
            'status': 1,
            'product': {
              'product_name': 'Yogur',
              'nutriments': {'energy-kcal_100g': 60},
            },
          })));
      expect((await found.find('7802900001234'))!.kcal100, 60);
      expect(asked!.path, '/api/v2/product/7802900001234.json');
      expect(asked!.queryParameters['fields'], contains('nutriments'));

      final missing = OpenFoodFactsLookup(
          MockClient((r) => reply(r, 404, {'status': 0})));
      expect(await missing.find('12345678'), isNull);
      final zero = OpenFoodFactsLookup(
          MockClient((r) => reply(r, 200, {'status': 0})));
      expect(await zero.find('12345678'), isNull);

      final down = OpenFoodFactsLookup(MockClient((r) => reply(r, 503, {})));
      expect(() => down.find('12345678'),
          throwsA(isA<ProductLookupException>()
              .having((e) => e.message, 'message', contains('503'))));
      final offline = OpenFoodFactsLookup(
          MockClient((r) async => throw http.ClientException('sin red')));
      expect(() => offline.find('12345678'),
          throwsA(isA<ProductLookupException>()
              .having((e) => e.message, 'message', contains('conexión'))));
    });
  });

  group('Código de barras', () {
    testWidgets('buscar, ajustar la cantidad y agregar', (tester) async {
      setSize(tester, const Size(700, 3000));
      final log = FakeFoodLog();
      final products = FakeProductLookup({yogurt.code: yogurt});
      await tester.pumpWidget(app(log: log, products: products));
      await tester.pumpAndSettle();
      await openMode(tester, 'Código');

      await tester.enterText(
          find.widgetWithText(TextField, 'Código de barras'), '7802900-001234');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(products.asked, ['7802900001234']);
      expect(find.text('Yogur protein (Marca)'), findsOneWidget);
      expect(find.textContaining('Porción del envase: 155 g'), findsOneWidget);
      expect(find.textContaining('93 kcal'), findsOneWidget); // 155 g

      await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '200');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      final e = log.items.single;
      expect(e.source, 'barcode');
      expect(e.name, 'Yogur protein (Marca)');
      expect(e.quantity, 200);
      expect(e.kcal, closeTo(120, 1e-9));
      expect(e.protein, closeTo(20, 1e-9));
      expect(find.text('Yogur protein (Marca)'), findsOneWidget);
    });

    testWidgets('escanear busca el código leído', (tester) async {
      setSize(tester, const Size(700, 3000));
      final products = FakeProductLookup({yogurt.code: yogurt});
      await tester.pumpWidget(app(
        log: FakeFoodLog(),
        products: products,
        scan: (context) async => yogurt.code,
      ));
      await tester.pumpAndSettle();
      await openMode(tester, 'Código');
      await tester.tap(find.text('Escanear con la cámara'));
      await tester.pumpAndSettle();
      expect(products.asked, [yogurt.code]);
      expect(find.text('Yogur protein (Marca)'), findsOneWidget);
    });

    testWidgets('código inválido, no encontrado, sin nutrientes y sin red',
        (tester) async {
      setSize(tester, const Size(700, 3000));
      final products = FakeProductLookup({
        '11111111': const Product(code: '11111111', name: 'Misterio', unit: 'g'),
      });
      await tester.pumpWidget(app(log: FakeFoodLog(), products: products));
      await tester.pumpAndSettle();
      await openMode(tester, 'Código');
      final field = find.widgetWithText(TextField, 'Código de barras');

      await tester.enterText(field, '123');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('entre 8 y 14'), findsOneWidget);
      expect(products.asked, isEmpty);

      await tester.enterText(field, '22222222');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(find.text('El código 22222222 no está en Open Food Facts.'), findsOneWidget);
      expect(find.text('Crear producto'), findsOneWidget);

      await tester.enterText(field, '11111111');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(find.text('Misterio no trae información nutricional.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Agregar'), findsNothing);

      products.error = const ProductLookupException('Sin internet.');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();
      expect(find.text('Sin internet.'), findsOneWidget);
    });
  });

  group('Describir (texto o voz)', () {
    PhotoAnalysis meal() => PhotoAnalysis(
          items: [
            PhotoItem(name: 'Porotos con riendas', quantity: 350, unit: 'g', kcal: 420, protein: 21, carbs: 60, fat: 9),
            PhotoItem(name: 'Marraqueta', quantity: 0.5, unit: 'unidad', kcal: 135, protein: 4.5, carbs: 28, fat: 0.5),
          ],
          confidence: 'media',
          notes: 'Plato contundente; el pan suma bastante.',
        );

    testWidgets('analiza la descripción y agrega lo revisado', (tester) async {
      setSize(tester, const Size(700, 3000));
      final log = FakeFoodLog();
      final ai = FakePhotoAnalyzer(result: meal());
      await tester.pumpWidget(app(log: log, ai: ai));
      await tester.pumpAndSettle();
      await openMode(tester, 'Describir');

      await tester.tap(find.text('Analizar'));
      await tester.pumpAndSettle();
      expect(find.text('Cuéntame qué comiste.'), findsOneWidget);
      expect(ai.calls, 0);

      await tester.enterText(find.widgetWithText(TextField, '¿Qué comiste?'),
          ' almorcé porotos con riendas y media marraqueta ');
      await tester.tap(find.text('Analizar'));
      await tester.pumpAndSettle();
      expect(ai.lastText, 'almorcé porotos con riendas y media marraqueta');
      expect(ai.lastRemaining, isNotNull);
      expect(find.textContaining('Total: 555 kcal'), findsOneWidget);
      expect(find.text('Plato contundente; el pan suma bastante.'), findsOneWidget);

      // Quitar el pan antes de agregar.
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar 1 alimentos'));
      await tester.pumpAndSettle();
      final e = log.items.single;
      expect(e.name, 'Porotos con riendas');
      expect(e.source, 'voice');
      expect(e.kcal, 420);
    });

    testWidgets('error del servidor se muestra', (tester) async {
      setSize(tester, const Size(700, 3000));
      final ai = FakePhotoAnalyzer(
          error: const PhotoException('Llegaste al límite de 50 descripciones por hoy.'));
      await tester.pumpWidget(app(log: FakeFoodLog(), ai: ai));
      await tester.pumpAndSettle();
      await openMode(tester, 'Describir');
      await tester.enterText(find.widgetWithText(TextField, '¿Qué comiste?'), 'una manzana');
      await tester.tap(find.text('Analizar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('50 descripciones'), findsOneWidget);
    });
  });

  group('Producto propio', () {
    testWidgets('crear el que falta, agregarlo y encontrarlo después',
        (tester) async {
      setSize(tester, const Size(700, 3000));
      final log = FakeFoodLog();
      final custom = FakeCustomProducts();
      final off = FakeProductLookup();
      await tester.pumpWidget(app(log: log, products: off, customProducts: custom));
      await tester.pumpAndSettle();
      await openMode(tester, 'Código');
      await search(tester, '7802000017629');
      await tester.tap(find.text('Crear producto'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Código 7802000017629'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Agregar'), findsNothing);

      // Sin nombre no guarda.
      await tester.tap(find.text('Guardar producto'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe el nombre del producto.'), findsOneWidget);

      await fill(tester, 'Nombre', 'Papas fritas corte americano');
      await fill(tester, 'Marca (opcional)', 'Lays');
      await fill(tester, 'Calorías', '540');
      await fill(tester, 'Proteína', '6,5');
      await fill(tester, 'Carbos', '52');
      await fill(tester, 'Grasas', '60'); // 6,5 + 52 + 60 > 100
      await tester.tap(find.text('Guardar producto'));
      await tester.pumpAndSettle();
      expect(find.textContaining('hasta 100 g'), findsOneWidget);
      await fill(tester, 'Grasas', '34');
      await fill(tester, 'Porción del envase (opcional)', '30');
      await tester.tap(find.text('Guardar producto'));
      await tester.pumpAndSettle();

      final saved = custom.items['7802000017629']!;
      expect(saved.custom, isTrue);
      expect(saved.protein100, 6.5);
      expect(saved.toRow()['brand'], 'Lays');
      expect(find.text('Papas fritas corte americano (Lays)'), findsOneWidget);
      expect(find.text('Producto creado por ti'), findsOneWidget);
      expect(find.textContaining('162 kcal'), findsOneWidget); // 30 g

      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();
      expect(log.items.single.kcal, closeTo(162, 1e-9));
      expect(log.items.single.source, 'barcode');

      // La próxima vez lo encuentra sin preguntar a Open Food Facts.
      await openMode(tester, 'Código');
      await search(tester, '7802000017629');
      expect(off.asked, ['7802000017629']);
      // En la hoja y en la comida donde ya se agregó.
      expect(find.text('Papas fritas corte americano (Lays)'), findsNWidgets(2));
      expect(find.text('Producto creado por ti'), findsOneWidget);
    });

    testWidgets('leer la etiqueta con foto llena los valores por 100 g',
        (tester) async {
      setSize(tester, const Size(700, 3000));
      final ai = FakePhotoAnalyzer(result: PhotoAnalysis(items: [
        PhotoItem(name: 'Papas fritas', quantity: 30, unit: 'g', kcal: 162, protein: 2, carbs: 15.6, fat: 10.2),
      ], confidence: 'alta', notes: ''));
      final custom = FakeCustomProducts();
      await tester.pumpWidget(app(log: FakeFoodLog(), ai: ai, customProducts: custom));
      await tester.pumpAndSettle();
      await openMode(tester, 'Código');
      await search(tester, '12345678');
      await tester.tap(find.text('Crear producto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leer la etiqueta con una foto'));
      await tester.pumpAndSettle();
      expect(ai.lastMode, PhotoMode.label);
      expect(find.textContaining('Leí la porción de 30 g'), findsOneWidget);
      await tester.tap(find.text('Guardar producto'));
      await tester.pumpAndSettle();
      final p = custom.items['12345678']!;
      expect(p.name, 'Papas fritas');
      expect(p.kcal100, 540);
      expect(p.carbs100, 52);
      expect(p.fat100, 34);
      expect(p.servingQuantity, 30);
    });

    testWidgets('corregir un producto propio y partir del nombre de OFF',
        (tester) async {
      setSize(tester, const Size(700, 3000));
      final custom = FakeCustomProducts()
        ..items['11112222'] = const Product(
            code: '11112222', name: 'Barra', unit: 'g', kcal100: 400,
            protein100: 20, carbs100: 40, fat100: 15, custom: true);
      final off = FakeProductLookup({
        '33334444': const Product(code: '33334444', name: 'Jugo', brand: 'Marca', unit: 'ml'),
      });
      await tester.pumpWidget(app(log: FakeFoodLog(), products: off, customProducts: custom));
      await tester.pumpAndSettle();
      await openMode(tester, 'Código');

      await search(tester, '11112222');
      await tester.tap(find.text('Corregir'));
      await tester.pumpAndSettle();
      expect(find.text('Corregir producto'), findsOneWidget);
      await fill(tester, 'Calorías', '380');
      await tester.tap(find.text('Guardar producto'));
      await tester.pumpAndSettle();
      expect(custom.items['11112222']!.kcal100, 380);
      expect(custom.items['11112222']!.protein100, 20);

      await search(tester, '33334444');
      expect(find.text('Jugo (Marca) no trae información nutricional.'), findsOneWidget);
      await tester.tap(find.text('Crear producto'));
      await tester.pumpAndSettle();
      await fill(tester, 'Calorías', '45');
      await tester.tap(find.text('Guardar producto'));
      await tester.pumpAndSettle();
      final p = custom.items['33334444']!;
      expect(p.name, 'Jugo');
      expect(p.brand, 'Marca');
      expect(p.unit, 'ml');
      expect(p.carbs100, 0);
    });
  });

  testWidgets('teléfono de 360 px: crear producto sin desbordes', (tester) async {
    setSize(tester, const Size(360, 3000));
    await tester.pumpWidget(app(log: FakeFoodLog()));
    await tester.pumpAndSettle();
    await openMode(tester, 'Código');
    await search(tester, '7802000017629');
    await tester.tap(find.text('Crear producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ml'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar producto'), findsOneWidget);
  });

  testWidgets('teléfono de 360 px: modos, código y descripción sin desbordes',
      (tester) async {
    setSize(tester, const Size(360, 3000));
    final products = FakeProductLookup({yogurt.code: yogurt});
    await tester.pumpWidget(app(
        log: FakeFoodLog(),
        products: products,
        ai: FakePhotoAnalyzer(result: PhotoAnalysis(items: [
          PhotoItem(name: 'Completo italiano con mayo casera', quantity: 1, unit: 'unidad', kcal: 520, protein: 18, carbs: 45, fat: 30),
        ], confidence: 'baja', notes: ''))));
    await tester.pumpAndSettle();
    await openMode(tester, 'Código');
    await tester.enterText(find.widgetWithText(TextField, 'Código de barras'), yogurt.code);
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Yogur protein (Marca)'), findsOneWidget);
    await tester.tap(find.text('Describir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '¿Qué comiste?'), 'un completo');
    await tester.tap(find.text('Analizar'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar 1 alimentos'), findsOneWidget);
  });
}

Future<void> search(WidgetTester tester, String code) async {
  await tester.enterText(find.widgetWithText(TextField, 'Código de barras'), code);
  await tester.tap(find.byTooltip('Buscar'));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String label, String value) async {
  await tester.enterText(find.widgetWithText(TextField, label), value);
  await tester.pumpAndSettle();
}

