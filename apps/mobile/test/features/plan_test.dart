import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';
import '../support/sections.dart';
import '../widget_test.dart' show setSize;

final today = DateTime.now();

/// Usuario de 123 kg con cuello y cintura de hoy.
final bigToday = [
  Measurement(id: 'x', date: DateTime(today.year, today.month, today.day),
      weightKg: 123, neckCm: 42, waistCm: 135),
];

Future<void> openTab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

Widget app({
  List<Measurement>? measurements,
  Questionnaire? questionnaire,
  bool withProfile = true,
}) =>
    testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(withProfile ? sampleProfile : null),
      measurements: FakeMeasurements(measurements ?? bigToday),
      questionnaires: FakeQuestionnaires(questionnaire),
    );

void main() {
  testWidgets('sin cuestionario, Plan dice qué falta y lleva a Progreso',
      (tester) async {
    setSize(tester, const Size(500, 1400));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openTab(tester, Icons.restaurant_menu_outlined);

    expect(find.text('Para armar tu plan nutricional me falta:'), findsOneWidget);
    expect(find.text('Responde el cuestionario'), findsOneWidget);
    expect(find.text('Completa tu perfil'), findsNothing);

    await tester.tap(find.text('Ir a Progreso'));
    await tester.pumpAndSettle();
    expect(find.text('Cuéntame de ti para armar tu plan'), findsOneWidget);
  });

  testWidgets('Plan: comidas, horarios, porqué, alerta y ejemplos', (tester) async {
    setSize(tester, const Size(800, 4000));
    await tester.pumpWidget(app(
      questionnaire: Questionnaire.initial.copyWith(
          dietPattern: DietPattern.vegetarian, allergies: [Allergy.lactose]),
    ));
    await tester.pumpAndSettle();
    await openTab(tester, Icons.restaurant_menu_outlined);

    expect(find.text('Tu plan nutricional'), findsOneWidget);
    expect(find.text('Recomendamos un control médico'), findsOneWidget);
    for (final s in ['Por qué', 'Grasas saludables', 'Condimentos']) {
      await openSection(tester, s);
    }
    expect(find.text('Por qué este plan'), findsOneWidget);
    expect(find.textContaining('· Comida 1'), findsOneWidget);
    expect(find.text('Después de entrenar'), findsOneWidget);
    // Vegetariano y sin lactosa: no aparece pollo ni yogur.
    expect(find.textContaining('pollo'), findsNothing);
    expect(find.textContaining('yogur'), findsNothing);
    expect(find.textContaining('huevo'), findsWidgets);
  });

  testWidgets('condición supervisada: plan de mantención con aviso',
      (tester) async {
    setSize(tester, const Size(800, 3000));
    await tester.pumpWidget(app(
      questionnaire: Questionnaire.initial
          .copyWith(healthConditions: [HealthCondition.pregnancy]),
    ));
    await tester.pumpAndSettle();
    await openTab(tester, Icons.restaurant_menu_outlined);

    expect(find.text('Tu plan debe guiarlo un profesional'), findsOneWidget);
    expect(find.text('mantención'), findsOneWidget);
  });

  testWidgets('Entreno: días, ejercicios adaptados y cuidados', (tester) async {
    setSize(tester, const Size(800, 4000));
    await tester.pumpWidget(app(
      questionnaire: Questionnaire.initial
          .copyWith(trainingDays: 4, injuries: [Injury.knee]),
    ));
    await tester.pumpAndSettle();
    await openTab(tester, Icons.fitness_center_outlined);

    expect(find.text('Tu plan de entrenamiento'), findsOneWidget);
    expect(find.text('Lunes · Tren superior'), findsOneWidget);
    expect(find.text('Martes · Tren inferior'), findsOneWidget);
    expect(find.text('Sentadilla a un cajón alto (rango sin dolor)'),
        findsNWidgets(2));
    expect(find.byKey(const ValueKey('section-closed-Cuidados')), findsOneWidget);
    await openSection(tester, 'Por qué');
    expect(find.textContaining('Cardio de bajo impacto'), findsWidgets);
  });

  testWidgets('Progreso muestra la meta por etapas', (tester) async {
    setSize(tester, const Size(900, 2400));
    await tester.pumpWidget(app(questionnaire: Questionnaire.initial));
    await tester.pumpAndSettle();
    await openTab(tester, Icons.monitor_weight_outlined);

    expect(find.text('Tu meta, por etapas'), findsOneWidget);
    expect(find.text('ETAPA 1'), findsOneWidget);
    expect(find.text('META FINAL'), findsOneWidget);
  });

  testWidgets('teléfono de 360 px: Plan y Entreno sin desbordes', (tester) async {
    setSize(tester, const Size(360, 5000));
    await tester.pumpWidget(app(
      questionnaire: Questionnaire.initial.copyWith(
          preferredMeals: () => 6, injuries: [Injury.shoulder, Injury.knee]),
    ));
    await tester.pumpAndSettle();
    await openTab(tester, Icons.restaurant_menu_outlined);
    expect(find.text('Tu plan nutricional'), findsOneWidget);
    await openTab(tester, Icons.fitness_center_outlined);
    expect(find.text('Tu plan de entrenamiento'), findsOneWidget);
  });
}
