import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/recommendation/weekly_basis.dart';
import 'package:magra/features/progress/body_assessment.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';
import '../support/sections.dart';
import '../widget_test.dart' show setSize;

void main() {
  test('el % final combina foto y medidas según la precisión de cada una', () {
    expect(combinedFat(photo: 24, low: 21, high: 27), 24);
    final c = combinedFat(photo: 24, low: 21, high: 27, tape: 26);
    // Foto ±3 (peso 1/9), medidas ±3,5 (peso 1/12,25): queda más cerca de la foto.
    expect(c, closeTo((24 / 9 + 26 / 12.25) / (1 / 9 + 1 / 12.25), 1e-9));
    expect(c, greaterThan(24));
    expect(c, lessThan(25));
    // Una foto poco segura (rango amplio) pesa menos.
    expect(combinedFat(photo: 24, low: 16, high: 32, tape: 26), greaterThan(c));
  });

  test('la evaluación con foto entra al plan; un % de profesional en la misma fecha gana', () {
    final today = DateTime(2026, 10, 21);
    final ms = [Measurement(date: DateTime(2026, 10, 14), weightKg: 95, neckCm: 42, waistCm: 98)];
    final photo = BodyAssessment(date: DateTime(2026, 10, 16), weightKg: 95, finalFatPct: 22.4);
    final b = planBasis(ms, sampleProfile, today, assessments: [photo]);
    expect(b.fatSource, FatSource.photo);
    expect(b.fatPct, 22.4);
    final plan = weeklyNutrition(
        profile: sampleProfile, measurements: ms, questionnaire: Questionnaire.initial, today: today, assessments: [photo]);
    expect(plan.reasons.join(' '), contains('evaluación con foto'));
    // Esta semana no cambia el plan hasta el lunes.
    final later = BodyAssessment(date: DateTime(2026, 10, 20), weightKg: 95, finalFatPct: 30);
    expect(planBasis(ms, sampleProfile, today, assessments: [photo, later]).fatPct, 22.4);
    final pro = [...ms, Measurement(date: DateTime(2026, 10, 16), weightKg: 95, reportedFatPct: 21)];
    expect(planBasis(pro, sampleProfile, today, assessments: [photo]).fatSource, FatSource.professional);
  });

  testWidgets('evaluación con foto: pide permiso y foto de frente, evalúa y guarda', (tester) async {
    setSize(tester, const Size(700, 3200));
    final body = FakeBody();
    final now = DateTime.now();
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([Measurement(id: 'm', date: now, weightKg: 95, neckCm: 42, waistCm: 98)]),
      questionnaires: FakeQuestionnaires(Questionnaire.initial),
      body: body,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
    await tester.pumpAndSettle();
    await openSection(tester, 'Evaluación con foto');
    await tester.tap(find.text('Hacer evaluación con foto'));
    await tester.pumpAndSettle();

    FilledButton evaluar() => tester.widget<FilledButton>(find.ancestor(of: find.text('Evaluar'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
    expect(evaluar().onPressed, isNull); // sin foto ni permiso
    await tester.tap(find.byTooltip('Elegir foto de frente'));
    await tester.pumpAndSettle();
    expect(find.text('Lista'), findsOneWidget);
    expect(evaluar().onPressed, isNull); // falta el permiso
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evaluar'));
    await tester.pumpAndSettle();

    expect(body.consent, isTrue);
    expect(body.sentPhotos!.single.view, 'front');
    expect(body.sentContext!['tape_fat_pct'], isNotNull);
    expect(body.sentContext!['sex'], 'male');
    expect(body.items, hasLength(1));
    final a = body.items.single;
    expect(a.photoFatPct, 24);
    expect(a.finalFatPct, isNot(24)); // combinado con las medidas
    expect(find.text('Tus fortalezas'), findsOneWidget);
    expect(find.textContaining('Tu plan usa este %'), findsOneWidget);
  });

  testWidgets('fotos que no sirven (teléfono de 360 px): explica el motivo y no guarda', (tester) async {
    setSize(tester, const Size(360, 3200));
    final body = FakeBody(consent: true, reply: const BodyAiResult(valid: false, invalidReason: 'La foto no muestra el cuerpo completo.'));
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([Measurement(id: 'm', date: DateTime.now(), weightKg: 95)]),
      questionnaires: FakeQuestionnaires(Questionnaire.initial),
      body: body,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
    await tester.pumpAndSettle();
    await openSection(tester, 'Evaluación con foto');
    await tester.tap(find.text('Hacer evaluación con foto'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing); // ya aceptó antes
    await tester.tap(find.byTooltip('Tomar foto de frente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evaluar'));
    await tester.pumpAndSettle();
    expect(find.text('La foto no muestra el cuerpo completo.'), findsOneWidget);
    expect(body.items, isEmpty);
  });
}
