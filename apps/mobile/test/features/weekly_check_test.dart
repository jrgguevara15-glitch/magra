import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/recommendation/weekly_adjustment.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/progress/weekly_check.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/today/food_catalog.dart';

import '../support/fakes.dart';
import '../support/sections.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);
DateTime ago(int days) => today.subtract(Duration(days: days));

/// Pesajes cada 3 días durante 3 semanas bajando [perWeek] kg por semana.
List<Measurement> series(double perWeek) => [
      for (var d = 21; d >= 0; d -= 3)
        Measurement(
          id: 'm$d',
          date: ago(d),
          weightKg: 100 - perWeek * (21 - d) / 7,
          neckCm: 40,
          waistCm: 100,
        ),
    ];

Widget app(
  List<Measurement> measurements, {
  FakeKcalAdjustments? adjustments,
  FakeFoodLog? foodLog,
  bool questionnaire = true,
}) =>
    testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements(measurements),
      questionnaires:
          FakeQuestionnaires(questionnaire ? Questionnaire.initial : null),
      adjustments: adjustments,
      foodLog: foodLog,
    );

Future<void> openProgress(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
  await tester.pumpAndSettle();
  await openSection(tester, 'Tendencia y ajuste');
}

void main() {
  testWidgets('bajar muy rápido propone subir y el plan lo incluye',
      (tester) async {
    setSize(tester, const Size(700, 4000));
    final adjustments = FakeKcalAdjustments();
    await tester.pumpWidget(app(series(1.5), adjustments: adjustments));
    await tester.pumpAndSettle();
    await openProgress(tester);

    expect(find.text('Tendencia y ajuste semanal'), findsOneWidget);
    expect(find.byType(WeightChart), findsOneWidget);
    expect(find.textContaining('bajas 1,50 kg por semana'), findsOneWidget);
    expect(find.textContaining('Para estimar tu gasto real'), findsOneWidget);

    await tester.tap(find.text('Aplicar +150 kcal'));
    await tester.pumpAndSettle();
    final saved = adjustments.items.single;
    expect(saved.applied, isTrue);
    expect(saved.deltaKcal, 150);
    expect(saved.weekStart, weekStartOf(today));
    expect(saved.reason, 'tooFast');
    expect(find.text('Esta semana aplicaste +150 kcal'), findsOneWidget);
    expect(find.textContaining('Ajuste acumulado: +150 kcal'), findsOneWidget);
    expect(find.text('Aplicar +150 kcal'), findsNothing);

    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();
    await openSection(tester, 'Por qué');
    expect(find.textContaining('ajuste semanal de +150 kcal'), findsOneWidget);
  });

  testWidgets('"Ahora no" deja la meta igual', (tester) async {
    setSize(tester, const Size(700, 4000));
    final adjustments = FakeKcalAdjustments();
    await tester.pumpWidget(app(series(1.5), adjustments: adjustments));
    await tester.pumpAndSettle();
    await openProgress(tester);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(adjustments.items.single.applied, isFalse);
    expect(find.text('Esta semana decidiste mantener tus calorías'), findsOneWidget);
    expect(find.textContaining('Ajuste acumulado'), findsNothing);
  });

  testWidgets('en ritmo no propone cambios', (tester) async {
    setSize(tester, const Size(700, 4000));
    await tester.pumpWidget(app(series(0.5)));
    await tester.pumpAndSettle();
    await openProgress(tester);
    expect(find.textContaining('Vas bien'), findsOneWidget);
    expect(find.textContaining('Aplicar'), findsNothing);
  });

  testWidgets('con registro suficiente estima el gasto real', (tester) async {
    setSize(tester, const Size(700, 4000));
    final log = FakeFoodLog();
    for (var i = 1; i <= 14; i++) {
      await log.add(FoodEntry(date: ago(i), mealIndex: 0, name: 'Almuerzo', kcal: 2000));
    }
    await tester.pumpWidget(app(series(0.5), foodLog: log));
    await tester.pumpAndSettle();
    await openProgress(tester);
    // 2.000 + 0,5 × 7.700 / 7 = 2.550.
    expect(find.textContaining('Gasto real estimado: 2.550 kcal'), findsOneWidget);
    expect(find.textContaining('14 días registrados'), findsOneWidget);
  });

  testWidgets('con un solo pesaje pide pesarse más', (tester) async {
    setSize(tester, const Size(700, 4000));
    await tester.pumpWidget(app([
      Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
    ]));
    await tester.pumpAndSettle();
    await openProgress(tester);
    expect(find.byType(WeightChart), findsNothing);
    expect(find.textContaining('Pésate al menos 3 veces'), findsOneWidget);
  });

  testWidgets('sin cuestionario explica qué falta', (tester) async {
    setSize(tester, const Size(700, 4000));
    await tester.pumpWidget(app(series(1.5), questionnaire: false));
    await tester.pumpAndSettle();
    await openProgress(tester);
    expect(find.textContaining('Responde el cuestionario para recibir'), findsOneWidget);
  });

  testWidgets('teléfono de 360 px sin desbordes', (tester) async {
    setSize(tester, const Size(360, 4000));
    await tester.pumpWidget(app(series(1.5),
        adjustments: FakeKcalAdjustments([
          KcalAdjustment(
              weekStart: weekStartOf(today).subtract(const Duration(days: 7)),
              deltaKcal: -100,
              applied: true,
              reason: 'tooSlow'),
        ])));
    await tester.pumpAndSettle();
    await openProgress(tester);
    expect(find.text('Aplicar +150 kcal'), findsOneWidget);
    expect(find.textContaining('Ajuste acumulado: −100 kcal'), findsOneWidget);
  });
}
