import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/today/food_catalog.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

Widget app(FakeFoodLog log) => testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
      ]),
      questionnaires: FakeQuestionnaires(Questionnaire.initial),
      foodLog: log,
    );

CatalogFood food(String name) => foodCatalog.firstWhere((f) => f.name == name);

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Agregar alimento').first);
  await tester.pumpAndSettle();
}

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.widgetWithText(TextField, 'Buscar alimento'), text);
  await tester.pumpAndSettle();
}

void main() {
  test('la base trae café, bebidas, alcohol, snacks y golosinas con su porción', () {
    final q = Questionnaire.initial;
    for (final w in ['cafe', 'cerveza', 'vino', 'pisco', 'piscola', 'coca', 'papas fritas', 'chocolate',
        'gomitas', 'alfajor', 'helado', 'completo', 'mayonesa', 'azucar', 'te o infusion']) {
      expect(searchCatalog(q, w), isNotEmpty, reason: w);
    }
    final beer = food('Cerveza');
    expect(beer.group, FoodGroup.alcohol);
    expect(beer.unitName, 'lata');
    expect(beer.nutrientsFor(350).kcal, closeTo(150.5, 1e-9));
    // Las porciones caseras se sugieren de a una.
    expect(suggestedGrams(beer, mealProtein: 30, mealCarbs: 40, mealFat: 10), 350);
    expect(suggestedGrams(food('Café negro (americano o de filtro)'), mealProtein: 30, mealCarbs: 40, mealFat: 10), 240);
    // Nombres únicos.
    final names = foodCatalog.map((f) => f.name).toList();
    expect(names.toSet().length, names.length);
  });

  test('lo anotado se reutiliza: por gramos o por porción', () {
    final grams = CatalogFood.fromEntry(FoodEntry(
        date: today, mealIndex: 0, name: 'Arroz con leche', quantity: 150, kcal: 300, protein: 6));
    expect(grams.mine, isTrue);
    expect(grams.lastQuantity, 150);
    expect(grams.nutrientsFor(100).kcal, closeTo(200, 1e-9));
    final portion = CatalogFood.fromEntry(FoodEntry(
        date: today, mealIndex: 0, name: 'Café de grano', quantity: 1, unit: 'porción', kcal: 40));
    expect(portion.servingOnly, isTrue);
    expect(portion.nutrientsFor(2).kcal, closeTo(80, 1e-9));
  });

  testWidgets('cerveza por lata o por ml', (tester) async {
    setSize(tester, const Size(700, 3000));
    final log = FakeFoodLog();
    await tester.pumpWidget(app(log));
    await tester.pumpAndSettle();
    await openSheet(tester);
    await search(tester, 'cerveza');
    await tester.tap(find.text('Cerveza'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Cantidad')).controller!.text, '1');
    expect(find.textContaining('151 kcal'), findsOneWidget);
    expect(find.textContaining('El alcohol aporta calorías'), findsOneWidget);
    await tester.tap(find.text('ml').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Cantidad')).controller!.text, '350');
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();
    expect(log.items.single.quantity, 350);
    expect(log.items.single.unit, 'ml');
    expect(log.items.single.kcal, closeTo(150.5, 1e-9));
  });

  testWidgets('lo creado a mano queda en "Tus alimentos" para la próxima vez', (tester) async {
    setSize(tester, const Size(700, 3000));
    final log = FakeFoodLog();
    await tester.pumpWidget(app(log));
    await tester.pumpAndSettle();
    await openSheet(tester);
    await search(tester, 'cafe de grano con leche de avena');
    expect(find.text('No encontré «cafe de grano con leche de avena».'), findsOneWidget);
    await tester.tap(find.text('Crear «cafe de grano con leche de avena»'));
    await tester.pumpAndSettle();
    // Pasa a "A mano" con el nombre ya escrito.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Qué comiste')).controller!.text,
        'cafe de grano con leche de avena');
    await tester.enterText(find.widgetWithText(TextField, 'Calorías'), '65');
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();
    expect(log.items.single.quantity, 1);
    expect(log.items.single.unit, 'porción');

    await openSheet(tester);
    expect(find.text('Tus alimentos'), findsOneWidget);
    await search(tester, 'avena');
    await tester.tap(find.text('cafe de grano con leche de avena').last);
    await tester.pumpAndSettle();
    expect(find.text('De tus alimentos'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '2');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();
    expect(log.items, hasLength(2));
    expect(log.items.last.kcal, closeTo(130, 1e-9));
    expect(log.items.last.quantity, 2);
    expect(log.items.last.source, 'manual');
  });

  testWidgets('a mano con cantidad y unidad', (tester) async {
    setSize(tester, const Size(700, 3000));
    final log = FakeFoodLog();
    await tester.pumpWidget(app(log));
    await tester.pumpAndSettle();
    await openSheet(tester);
    await tester.tap(find.text('A mano'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Qué comiste'), 'Kuchen de nuez');
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '120');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('g').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Calorías'), '420');
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();
    expect(log.items.single.quantity, 120);
    expect(log.items.single.unit, 'g');
    expect(find.text('Kuchen de nuez'), findsOneWidget);
  });

  testWidgets('filtrar por categoría', (tester) async {
    setSize(tester, const Size(700, 3000));
    await tester.pumpWidget(app(FakeFoodLog()));
    await tester.pumpAndSettle();
    await openSheet(tester);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Alcohol'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Alcohol'));
    await tester.pumpAndSettle();
    expect(find.text('Vino tinto'), findsOneWidget);
    expect(find.text('Arroz cocido'), findsNothing);
  });
}
