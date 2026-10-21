import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/today/food_catalog.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

Widget app(FakeFoodLog log, {Questionnaire? q, bool complete = true}) => testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
      ]),
      questionnaires: FakeQuestionnaires(complete ? (q ?? Questionnaire.initial) : null),
      foodLog: log,
    );

CatalogFood food(String name) => foodCatalog.firstWhere((f) => f.name == name);

Future<void> addFromCatalog(WidgetTester tester, String search, String name,
    {String? qty, int addButton = 0}) async {
  await tester.tap(find.text('Agregar alimento').at(addButton));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Buscar alimento'), search);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  if (qty != null) {
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), qty);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
  await tester.pumpAndSettle();
}

void main() {
  group('Catálogo', () {
    test('nutrientes por cantidad', () {
      final n = food('Pechuga de pollo cocida').nutrientsFor(150);
      expect(n.kcal, closeTo(247.5, 1e-9));
      expect(n.protein, closeTo(46.5, 1e-9));
    });

    test('cantidad sugerida según lo que le toca a la comida', () {
      double s(String name) => suggestedGrams(food(name),
          mealProtein: 34, mealCarbs: 43, mealFat: 15);
      expect(s('Pechuga de pollo cocida'), 110); // 34 / 31 × 100
      expect(s('Arroz cocido'), 155); // 43 / 28 × 100
      expect(s('Palta'), 70); // 15 / 15 × 100 = 100 g ≈ media palta (140 g)
      // 34 g de proteína serían 5,4 huevos: tope razonable de 4 (200 g).
      expect(s('Huevo'), 200);
      expect(s('Lechuga'), 100);
    });

    test('búsqueda sin tildes y respetando dieta y alergias', () {
      final vegan = Questionnaire.initial.copyWith(
          dietPattern: DietPattern.vegan, allergies: [Allergy.soy]);
      final names = searchCatalog(vegan, '').map((f) => f.name).toList();
      expect(names, isNot(contains('Huevo')));
      expect(names, isNot(contains('Tofu firme')));
      expect(names, contains('Arroz cocido'));
      expect(searchCatalog(Questionnaire.initial, 'platano').single.name, 'Plátano');
      expect(searchCatalog(Questionnaire.initial, 'pollo coc').single.name,
          'Pechuga de pollo cocida');
    });

    test('ida y vuelta con la fila de Supabase', () {
      final e = FoodEntry.fromCatalog(food('Arroz cocido'), 155,
          date: DateTime(2026, 10, 20), mealIndex: 1);
      final row = e.toRow();
      expect(row['eaten_on'], '2026-10-20');
      expect(row['kcal'], 201.5);
      expect(row['source'], 'catalog');
      final back = FoodEntry.fromRow({...row, 'id': 'x'});
      expect(back.name, 'Arroz cocido');
      expect(back.quantityLabel, '155 g');
      expect(back.carbs, closeTo(43.4, 1e-9));
    });
  });

  testWidgets('sin cuestionario, Hoy indica qué falta', (tester) async {
    setSize(tester, const Size(500, 1400));
    await tester.pumpWidget(app(FakeFoodLog(), complete: false));
    await tester.pumpAndSettle();
    expect(find.text('Para armar tu registro diario me falta:'), findsOneWidget);
  });

  testWidgets('agregar del catálogo actualiza el día', (tester) async {
    setSize(tester, const Size(700, 3000));
    final log = FakeFoodLog();
    await tester.pumpWidget(app(log));
    await tester.pumpAndSettle();

    expect(find.text('Hoy'), findsNWidgets(2)); // título del día y pestaña
    expect(find.textContaining('0 / '), findsWidgets);
    await addFromCatalog(tester, 'pollo', 'Pechuga de pollo cocida', qty: '200');

    expect(log.items, hasLength(1));
    expect(log.items.single.mealIndex, 0);
    expect(log.items.single.kcal, closeTo(330, 1e-9));
    expect(find.text('Pechuga de pollo cocida'), findsOneWidget);
    expect(find.textContaining('330 / '), findsNWidgets(2)); // resumen y comida
    expect(find.textContaining('Te quedan'), findsOneWidget);
  });

  testWidgets('cantidad sugerida y vista previa en la hoja', (tester) async {
    setSize(tester, const Size(700, 3000));
    await tester.pumpWidget(app(FakeFoodLog()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar alimento').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Buscar alimento'), 'huevo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Huevo'));
    await tester.pumpAndSettle();
    expect(find.text('1 huevo ≈ 50 g'), findsOneWidget);
    expect(find.text('Sugerida para esta comida según tu plan'), findsOneWidget);
    expect(find.textContaining(' kcal · P '), findsOneWidget);
  });

  testWidgets('agregar a mano, fuera del plan, y quitar', (tester) async {
    setSize(tester, const Size(700, 3000));
    final log = FakeFoodLog();
    await tester.pumpWidget(app(log));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar alimento').last); // Fuera del plan
    await tester.pumpAndSettle();
    await tester.tap(find.text('A mano'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un nombre y las calorías (0–5.000).'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Qué comiste'), 'Completo italiano');
    await tester.enterText(find.widgetWithText(TextField, 'Calorías'), '520');
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();

    expect(log.items.single.source, 'manual');
    expect(log.items.single.mealIndex, greaterThanOrEqualTo(3));
    expect(find.text('Completo italiano'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar Completo italiano'));
    await tester.pumpAndSettle();
    expect(log.items, isEmpty);
    expect(find.text('Quitaste Completo italiano.'), findsOneWidget);
  });

  testWidgets('cada día tiene su registro', (tester) async {
    setSize(tester, const Size(700, 3000));
    final log = FakeFoodLog();
    await tester.pumpWidget(app(log));
    await tester.pumpAndSettle();
    await addFromCatalog(tester, 'arroz', 'Arroz cocido', qty: '100');

    await tester.tap(find.byTooltip('Día anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Ayer'), findsOneWidget);
    expect(find.text('Arroz cocido'), findsNothing);
    await addFromCatalog(tester, 'papa', 'Papa cocida', qty: '100');
    expect(log.items.last.date, today.subtract(const Duration(days: 1)));

    await tester.tap(find.byTooltip('Día siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Arroz cocido'), findsOneWidget);
    expect(find.text('Papa cocida'), findsNothing);
  });

  testWidgets('pasarse de la meta se avisa', (tester) async {
    setSize(tester, const Size(700, 3000));
    final log = FakeFoodLog();
    await tester.pumpWidget(app(log));
    await tester.pumpAndSettle();
    await addFromCatalog(tester, 'aceite', 'Aceite de oliva', qty: '400');
    expect(find.textContaining('Te pasaste'), findsOneWidget);
  });

  testWidgets('teléfono de 360 px: Hoy y la hoja sin desbordes', (tester) async {
    setSize(tester, const Size(360, 3000));
    await tester.pumpWidget(app(FakeFoodLog()));
    await tester.pumpAndSettle();
    await addFromCatalog(tester, 'legumbres', 'Legumbres cocidas (lentejas, porotos, garbanzos)');
    await tester.tap(find.text('Agregar alimento').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A mano'));
    await tester.pumpAndSettle();
    expect(find.text('Qué comiste'), findsOneWidget);
  });
}
