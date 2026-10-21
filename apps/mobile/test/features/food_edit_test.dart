import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

Widget app({FakeFoodLog? log, FakeMenus? menus}) => testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
      ]),
      questionnaires: FakeQuestionnaires(Questionnaire.initial),
      foodLog: log,
      menus: menus,
    );

void main() {
  testWidgets('corregir la cantidad de lo registrado recalcula las calorías', (tester) async {
    setSize(tester, const Size(700, 3000));
    final log = FakeFoodLog();
    await tester.pumpWidget(app(log: log));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar alimento').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Buscar alimento'), 'arroz');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arroz cocido'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '100');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();
    expect(log.items.single.kcal, closeTo(130, 1e-9));

    await tester.tap(find.text('Arroz cocido'));
    await tester.pumpAndSettle();
    expect(find.text('Editar alimento'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '200');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Calorías')).controller!.text, '260');
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Arroz integral');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    final e = log.items.single;
    expect(e.quantity, 200);
    expect(e.kcal, closeTo(260, 1e-9));
    expect(e.name, 'Arroz integral');
    expect(find.text('Arroz integral'), findsOneWidget);
    expect(find.text('Corregiste Arroz cocido.'), findsOneWidget);
  });

  testWidgets('editar ingredientes de una comida del menú', (tester) async {
    setSize(tester, const Size(700, 4000));
    final plan = recommendNutrition(
      profile: sampleProfile,
      weightKg: 95,
      questionnaire: Questionnaire.initial,
      today: today,
    );
    final slots = [for (final m in plan.meals) MenuSlot.fromPlanned(m)];
    final menus = FakeMenus()
      ..items[week] = WeeklyMenu(
        weekStart: week,
        slots: slots,
        days: [
          for (var d = 0; d < 7; d++)
            [for (var i = 0; i < slots.length; i++) FakeMenuGenerator.mealFor(slots[i], 'Plato $d-$i')],
        ],
      );
    final log = FakeFoodLog();
    await tester.pumpWidget(app(log: log, menus: menus));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shopping_basket_outlined));
    await tester.pumpAndSettle();

    final before = menus.items[week]!.days[todayIndex][0];
    await tester.tap(find.text('Editar').first);
    await tester.pumpAndSettle();
    // Doble de pollo, sin arroz y con palta de la base.
    await tester.enterText(find.widgetWithText(TextField, 'Cantidad').first, '240');
    await tester.tap(find.byTooltip('Quitar Arroz'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Agregar o reemplazar ingrediente'), 'papa');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Papa cocida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar comida'));
    await tester.pumpAndSettle();

    final after = menus.items[week]!.days[todayIndex][0];
    expect(after.name, before.name);
    expect(after.items.map((i) => i.food), ['Pechuga de pollo', 'Palta', 'Papa cocida']);
    expect(after.items.first.quantity, 240);
    expect(after.items.first.kcal, closeTo(before.items.first.kcal * 2, 1e-9));
    expect(after.items.last.kcal, closeTo(87, 1e-9));

    // "Lo comí" registra la versión editada.
    await tester.tap(find.text('Lo comí').first);
    await tester.pumpAndSettle();
    expect(log.items.map((e) => e.name), ['Pechuga de pollo', 'Palta', 'Papa cocida']);
  });
}
