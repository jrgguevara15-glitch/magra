import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/features/coach/coach.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';
import 'package:magra/features/today/food_catalog.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

Widget app(FakeCoach coach, {FakeFoodLog? log}) => testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'a', date: today.subtract(const Duration(days: 14)), weightKg: 96, neckCm: 40, waistCm: 101),
        Measurement(id: 'b', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
      ]),
      questionnaires: FakeQuestionnaires(Questionnaire.initial.copyWith(
          healthConditions: [HealthCondition.hypertension], allergies: [Allergy.peanut])),
      foodLog: log,
      coach: coach,
    );

Future<void> openCoach(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
  await tester.pumpAndSettle();
}

void main() {
  group('Modelo', () {
    test('mensajes, revisión sugerida y errores', () {
      final m = CoachMessage.fromRow({'id': 'x', 'role': 'assistant', 'kind': 'review', 'content': 'Hola', 'created_at': '2026-10-19T12:00:00Z'});
      expect(m.fromUser, isFalse);
      expect(m.toApi(), {'role': 'assistant', 'content': 'Hola'});
      expect(const CoachMessage(role: 'user', content: 'q').toRow()['kind'], 'chat');

      final sunday = DateTime(2026, 10, 25, 10);
      final wednesday = DateTime(2026, 10, 21, 10);
      expect(reviewDue(const [], sunday), isTrue);
      expect(reviewDue(const [], wednesday), isFalse);
      final recent = CoachMessage(role: 'assistant', kind: 'review', content: 'r', createdAt: DateTime(2026, 10, 24));
      expect(reviewDue([recent], sunday), isFalse);
      final old = CoachMessage(role: 'assistant', kind: 'review', content: 'r', createdAt: DateTime(2026, 10, 12));
      expect(reviewDue([old], sunday), isTrue);

      expect(coachErrorMessage(403, null), contains('acepta'));
      expect(coachErrorMessage(500, {'error': 'Falla'}), 'Falla (error 500)');
    });
  });

  testWidgets('pide permiso antes de compartir datos', (tester) async {
    setSize(tester, const Size(700, 2000));
    final coach = FakeCoach();
    await tester.pumpWidget(app(coach));
    await tester.pumpAndSettle();
    await openCoach(tester);

    expect(find.text('Qué se comparte'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'Activar coach');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(coach.consent, isTrue);
    expect(find.text('¿Qué ceno hoy con lo que me queda?'), findsOneWidget);
  });

  testWidgets('pregunta con los datos de la persona y guarda la conversación',
      (tester) async {
    setSize(tester, const Size(700, 2000));
    final coach = FakeCoach(consent: true);
    final log = FakeFoodLog();
    await log.add(FoodEntry(date: today, mealIndex: 0, name: 'Avena', kcal: 300, protein: 10));
    await tester.pumpWidget(app(coach, log: log));
    await tester.pumpAndSettle();
    await openCoach(tester);

    await tester.tap(find.text('¿Qué ceno hoy con lo que me queda?'));
    await tester.pumpAndSettle();
    expect(coach.asks, 1);
    expect(coach.lastMode, 'chat');
    expect(coach.lastHistory!.last.content, '¿Qué ceno hoy con lo que me queda?');
    final ctx = coach.lastContext!;
    final json = jsonEncode(ctx);
    expect(json, isNot(contains('Alex'))); // sin nombre
    expect(json, isNot(contains('usuario@example.com')));
    expect((ctx['plan'] as Map)['kcal'], greaterThan(1400));
    expect((ctx['registro_hoy'] as Map)['alimentos'], ['Avena']);
    expect((ctx['cuestionario'] as Map)['salud'], ['Presión alta']);
    expect((ctx['medidas'] as Map)['pesajes_registrados'], 2);
    expect(ctx['proxima_sesion'], 'Cuerpo completo A');
    expect(find.text('Cena pollo con verduras.'), findsOneWidget);
    expect(coach.items.map((m) => m.role), ['user', 'assistant']);

    await tester.enterText(find.byType(TextField), 'Gracias, ¿y mañana?');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();
    expect(coach.asks, 2);
    expect(coach.lastHistory!.length, 3);
    expect(coach.items.length, 4);
  });

  testWidgets('error del servidor: reintentar sin repetir el mensaje',
      (tester) async {
    setSize(tester, const Size(700, 2000));
    final coach = FakeCoach(consent: true)
      ..error = const CoachException('Llegaste al límite de 30 mensajes al coach por hoy.');
    await tester.pumpWidget(app(coach));
    await tester.pumpAndSettle();
    await openCoach(tester);
    await tester.enterText(find.byType(TextField), 'Hola');
    await tester.tap(find.byTooltip('Enviar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('límite de 30'), findsOneWidget);
    expect(coach.items.length, 1);

    coach.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(coach.items.map((m) => m.role), ['user', 'assistant']);
    expect(find.textContaining('límite de 30'), findsNothing);
  });

  testWidgets('revisión semanal, borrar y dejar de compartir', (tester) async {
    setSize(tester, const Size(700, 2000));
    final coach = FakeCoach(consent: true)..reply = 'Semana: bajaste 0,5 kg.';
    await tester.pumpWidget(app(coach));
    await tester.pumpAndSettle();
    await openCoach(tester);

    await tester.tap(find.text('Hacer'));
    await tester.pumpAndSettle();
    expect(coach.lastMode, 'review');
    expect(coach.items.single.kind, 'review');
    expect(find.text('Revisión semanal'), findsWidgets);
    expect(find.text('Semana: bajaste 0,5 kg.'), findsOneWidget);

    await tester.tap(find.byTooltip('Opciones del coach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar conversación'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(coach.items, isEmpty);

    await tester.tap(find.byTooltip('Opciones del coach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dejar de compartir mis datos'));
    await tester.pumpAndSettle();
    expect(coach.consent, isFalse);
    expect(find.text('Qué se comparte'), findsOneWidget);
  });

  testWidgets('teléfono de 360 px sin desbordes', (tester) async {
    setSize(tester, const Size(360, 800));
    final coach = FakeCoach(consent: true);
    await tester.pumpWidget(app(coach));
    await tester.pumpAndSettle();
    await openCoach(tester);
    await tester.tap(find.text('¿Por qué no estoy bajando de peso?'));
    await tester.pumpAndSettle();
    expect(find.text('Cena pollo con verduras.'), findsOneWidget);
  });
}
