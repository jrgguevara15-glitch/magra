import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:magra/core/recommendation/nutrition_plan.dart';
import 'package:magra/core/recommendation/weekly_adjustment.dart';
import 'package:magra/features/menus/weekly_menu.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);
final week = weekStartOf(today);
final todayIndex = today.difference(week).inHours ~/ 24;

const slot = MenuSlot(time: '13:30', role: 'post', kcal: 600, protein: 40, carbs: 70, fat: 15);

Questionnaire get q => Questionnaire.initial.copyWith(
      allergies: [Allergy.peanut],
      dislikedFoods: 'cebolla',
    );

Widget app({FakeMenus? menus, FakeMenuGenerator? generator, FakeFoodLog? log}) => testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
      ]),
      questionnaires: FakeQuestionnaires(q),
      foodLog: log,
      menus: menus,
      menuGenerator: generator,
    );

NutritionPlan currentPlan() => recommendNutrition(
      profile: sampleProfile,
      weightKg: 95,
      questionnaire: q,
      today: today,
    );

WeeklyMenu menuFor(List<MenuSlot> slots) => WeeklyMenu(
      weekStart: week,
      slots: slots,
      days: [
        for (var d = 0; d < 7; d++)
          [for (var i = 0; i < slots.length; i++) FakeMenuGenerator.mealFor(slots[i], 'Plato $d-$i')],
      ],
    );

Future<void> openMenus(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.shopping_basket_outlined));
  await tester.pumpAndSettle();
}

void main() {
  group('Modelo', () {
    test('lista de compras: suma, une sin tildes, ordena por sección', () {
      const a = MenuItem(food: 'Plátano', quantity: 1, unit: 'unidad', kcal: 90, category: 'Verduras y frutas');
      const b = MenuItem(food: 'platano', quantity: 0.5, unit: 'unidad', kcal: 45, category: 'Verduras y frutas');
      const c = MenuItem(food: 'Leche', quantity: 600, unit: 'ml', kcal: 200, category: 'Lácteos y huevos', brand: 'Colun');
      const d = MenuItem(food: 'Pechuga de pollo', quantity: 700, unit: 'g', kcal: 700, category: 'Carnes, pollo y pescados');
      final menu = WeeklyMenu(
        weekStart: week,
        slots: const [slot],
        days: [
          const [MenuMeal(name: 'x', items: [a, c, d])],
          const [MenuMeal(name: 'y', items: [b, c, d])],
          for (var i = 0; i < 5; i++) const [MenuMeal(name: 'z', items: [])],
        ],
      );
      final list = shoppingList(menu);
      expect([for (final i in list) i.food], ['Plátano', 'Pechuga de pollo', 'Leche']);
      expect(list[0].quantityLabel, '2 unidades'); // 1,5 → 2
      expect(list[1].quantityLabel, '1,4 kg');
      expect(list[2].quantityLabel, '1,2 L');
      expect(list[2].brand, 'Colun');
      expect(list[0].key, 'platano|unidad');
    });

    test('guardar y leer el menú, y detectar que el plan cambió', () {
      final menu = menuFor(const [slot, slot, slot]).copyWith(checked: {'arroz|g'});
      final row = menu.toRow();
      expect(row['week_start'], isNotEmpty);
      expect((row['days'] as List).length, 7);
      final back = WeeklyMenu.fromRow({...row, 'id': 'x'});
      expect(back.days[3][2].name, 'Plato 3-2');
      expect(back.days[0][0].items[1].brand, 'Tucapel');
      expect(back.slots[0].role, 'post');
      expect(back.checked, {'arroz|g'});
      expect(back.dateOf(6), week.add(const Duration(days: 6)));

      final plan = currentPlan();
      final same = menuFor([for (final m in plan.meals) MenuSlot.fromPlanned(m)]);
      expect(same.outdatedFor(plan), isFalse);
      expect(menuFor(const [slot, slot]).outdatedFor(plan), isTrue);
    });

    test('preferencias y metas que recibe la IA', () {
      final prefs = menuPrefs(q);
      expect(prefs['allergies'], ['Maní']);
      expect(prefs['dislikes'], 'cebolla');
      expect(prefs['diet'], 'Como de todo');
      final s = MenuSlot.fromPlanned(currentPlan().meals.first);
      expect(s.time, matches(RegExp(r'^\d\d:\d\d$')));
      expect(s.toJson()['kcal'], isA<int>());
    });
  });

  testWidgets('generar el menú con las metas del plan', (tester) async {
    setSize(tester, const Size(700, 4000));
    final menus = FakeMenus();
    final gen = FakeMenuGenerator();
    await tester.pumpWidget(app(menus: menus, generator: gen));
    await tester.pumpAndSettle();
    await openMenus(tester);

    expect(find.text('Aún no tienes menú esta semana'), findsOneWidget);
    await tester.tap(find.text('Generar menú de la semana'));
    await tester.pumpAndSettle();

    final plan = currentPlan();
    expect(gen.lastSlots!.length, plan.meals.length);
    expect(gen.lastPrefs!['allergies'], ['Maní']);
    expect(menus.items[week]!.days.length, 7);
    expect(find.text('Plato $todayIndex-0'), findsOneWidget);
    expect(find.textContaining('120 g Pechuga de pollo'), findsWidgets);
    expect(find.text('Tu plan cambió'), findsNothing);
  });

  testWidgets('lo comí registra en el día; días futuros no', (tester) async {
    setSize(tester, const Size(700, 4000));
    final plan = currentPlan();
    final menus = FakeMenus()
      ..items[week] = menuFor([for (final m in plan.meals) MenuSlot.fromPlanned(m)]);
    final log = FakeFoodLog();
    await tester.pumpWidget(app(menus: menus, log: log));
    await tester.pumpAndSettle();
    await openMenus(tester);

    await tester.tap(find.text('Lo comí').first);
    await tester.pumpAndSettle();
    expect(log.items.length, 3);
    expect(log.items.every((e) => e.source == 'menu' && e.mealIndex == 0), isTrue);
    expect(log.items.first.date, today);
    expect(find.textContaining('Registraste "Plato $todayIndex-0" en Hoy'), findsOneWidget);

    if (todayIndex < 6) {
      await tester.tap(find.textContaining(_short(todayIndex + 1)));
      await tester.pumpAndSettle();
      final button = tester.widget<TextButton>(
          find.ancestor(of: find.text('Lo comí').first, matching: find.byWidgetPredicate((w) => w is TextButton)));
      expect(button.onPressed, isNull);
    }
  });

  testWidgets('cambiar una comida evita repetir platos', (tester) async {
    setSize(tester, const Size(700, 4000));
    final plan = currentPlan();
    final menus = FakeMenus()
      ..items[week] = menuFor([for (final m in plan.meals) MenuSlot.fromPlanned(m)]);
    final gen = FakeMenuGenerator();
    await tester.pumpWidget(app(menus: menus, generator: gen));
    await tester.pumpAndSettle();
    await openMenus(tester);

    await tester.tap(find.text('Cambiar').at(1));
    await tester.pumpAndSettle();
    expect(gen.swaps, 1);
    expect(gen.lastAvoid, contains('Plato 0-0'));
    expect(menus.items[week]!.days[todayIndex][1].name, 'Nuevo plato $todayIndex-1');
    expect(find.text('Nuevo plato $todayIndex-1'), findsOneWidget);
  });

  testWidgets('lista de compras: marcar queda guardado', (tester) async {
    setSize(tester, const Size(700, 4000));
    final plan = currentPlan();
    final menus = FakeMenus()
      ..items[week] = menuFor([for (final m in plan.meals) MenuSlot.fromPlanned(m)]);
    await tester.pumpWidget(app(menus: menus));
    await tester.pumpAndSettle();
    await openMenus(tester);
    await tester.tap(find.text('Compras'));
    await tester.pumpAndSettle();

    expect(find.text('Verduras y frutas'), findsOneWidget);
    expect(find.text('Abarrotes'), findsOneWidget);
    expect(find.textContaining('0 de 3 listos'), findsOneWidget);
    expect(find.textContaining('ej. Tucapel'), findsOneWidget);
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    expect(menus.items[week]!.checked, {'arroz|g'});
    expect(find.textContaining('1 de 3 listos'), findsOneWidget);
  });

  testWidgets('error de la IA y plan desactualizado', (tester) async {
    setSize(tester, const Size(700, 4000));
    final gen = FakeMenuGenerator()
      ..error = const MenuException('Llegaste al límite de 3 menús por hoy.');
    final menus = FakeMenus()..items[week] = menuFor(const [slot, slot]);
    await tester.pumpWidget(app(menus: menus, generator: gen));
    await tester.pumpAndSettle();
    await openMenus(tester);

    expect(find.text('Tu plan cambió'), findsOneWidget);
    await tester.tap(find.byTooltip('Nuevo menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Generar'));
    await tester.pumpAndSettle();
    expect(find.text('Llegaste al límite de 3 menús por hoy.'), findsOneWidget);
    expect(menus.items[week]!.slots.length, 2);
  });

  testWidgets('si no se puede guardar, reintenta sin volver a generar',
      (tester) async {
    setSize(tester, const Size(700, 4000));
    final menus = FakeMenus()
      ..saveError = const PostgrestException(
          message: 'relation "public.menus" does not exist', code: '42P01');
    final gen = FakeMenuGenerator();
    await tester.pumpWidget(app(menus: menus, generator: gen));
    await tester.pumpAndSettle();
    await openMenus(tester);
    await tester.tap(find.text('Generar menú de la semana'));
    await tester.pumpAndSettle();
    expect(find.textContaining('42P01'), findsOneWidget);
    expect(find.textContaining('migración 0008'), findsOneWidget);

    menus.saveError = null;
    await tester.tap(find.text('Reintentar guardar (sin volver a generar)'));
    await tester.pumpAndSettle();
    expect(gen.weeks, 1);
    expect(menus.items[week], isNotNull);
    expect(find.text('Plato $todayIndex-0'), findsOneWidget);
    expect(find.textContaining('42P01'), findsNothing);
  });

  testWidgets('teléfono de 360 px: menú y compras sin desbordes', (tester) async {
    setSize(tester, const Size(360, 4000));
    final plan = currentPlan();
    final menus = FakeMenus()
      ..items[week] = menuFor([for (final m in plan.meals) MenuSlot.fromPlanned(m)]);
    await tester.pumpWidget(app(menus: menus));
    await tester.pumpAndSettle();
    await openMenus(tester);
    expect(find.text('Lo comí'), findsWidgets);
    await tester.tap(find.text('Compras'));
    await tester.pumpAndSettle();
    expect(find.text('Arroz'), findsOneWidget);
  });
}

String _short(int d) => const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][d];
