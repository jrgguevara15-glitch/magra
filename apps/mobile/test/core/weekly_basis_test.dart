import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/format.dart';
import 'package:magra/core/recommendation/weekly_adjustment.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/core/recommendation/weekly_basis.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

void main() {
  // Miércoles 21-oct-2026; la semana empieza el lunes 19.
  final today = DateTime(2026, 10, 21);
  Measurement w(int day, double kg, {double? neck, double? waist, double? pro}) => Measurement(
      date: DateTime(2026, 10, day), weightKg: kg, neckCm: neck, waistCm: waist, reportedFatPct: pro);

  test('promedio de los pesajes de la semana pasada; los de esta semana no cambian la meta', () {
    final ms = [w(5, 99), w(13, 96), w(15, 95), w(18, 94.5), w(20, 93)];
    final b = planBasis(ms, sampleProfile, today);
    expect(b.weekStart, DateTime(2026, 10, 19));
    expect(b.fromLastWeek, isTrue);
    expect(b.weighIns, 3); // 12..18 de octubre
    expect(b.weightKg, closeTo((96 + 95 + 94.5) / 3, 1e-9));
    // Un pesaje nuevo esta semana no mueve la meta.
    final again = planBasis([...ms, w(21, 91)], sampleProfile, today);
    expect(again.weightKg, b.weightKg);
    final q = Questionnaire.initial;
    expect(
      weeklyNutrition(profile: sampleProfile, measurements: [...ms, w(21, 91)], questionnaire: q, today: today).kcal,
      weeklyNutrition(profile: sampleProfile, measurements: ms, questionnaire: q, today: today).kcal,
    );
  });

  test('primera semana: el primer registro, fijo hasta el lunes', () {
    final b = planBasis([w(20, 100), w(21, 99)], sampleProfile, today);
    expect(b.fromLastWeek, isFalse);
    expect(b.weightKg, 100);
    expect(b.note, contains('primer registro'));
  });

  test('% de grasa: el de un profesional gana; si no, el de las medidas', () {
    final tape = planBasis([w(15, 95, neck: 42, waist: 98)], sampleProfile, today);
    expect(tape.fatSource, FatSource.tape);
    expect(tape.fatPct, isNotNull);
    final pro = planBasis([w(15, 95, neck: 42, waist: 98, pro: 24)], sampleProfile, today);
    expect(pro.fatSource, FatSource.professional);
    expect(pro.fatPct, 24);
    final plan = weeklyNutrition(
        profile: sampleProfile, measurements: [w(15, 95, pro: 24)], questionnaire: Questionnaire.initial, today: today);
    expect(plan.formula, BmrFormula.katch);
    expect(plan.reasons.join(' '), contains('informado por un profesional'));
    expect(plan.reasons.join(' '), contains('fija hasta el próximo lunes'));
  });

  testWidgets('la meta es la misma en Hoy y en Progreso (con el ajuste semanal)', (tester) async {
    setSize(tester, const Size(900, 3000));
    final now = DateTime.now();
    final ms = [
      Measurement(id: 'a', date: now.subtract(const Duration(days: 20)), weightKg: 98, neckCm: 42, waistCm: 100),
      Measurement(id: 'b', date: now.subtract(const Duration(days: 9)), weightKg: 96.4),
      Measurement(id: 'c', date: now, weightKg: 95.1),
    ];
    final adj = [
      KcalAdjustment(weekStart: weekStartOf(now).subtract(const Duration(days: 7)), deltaKcal: -150, applied: true, reason: 'x'),
    ];
    final plan = weeklyNutrition(
        profile: sampleProfile, measurements: ms, questionnaire: Questionnaire.initial, today: now, kcalAdjustment: -150);
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements(ms),
      questionnaires: FakeQuestionnaires(Questionnaire.initial),
      adjustments: FakeKcalAdjustments(adj),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('de ${fmt(plan.kcal)} · meta fija'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
    await tester.pumpAndSettle();
    expect(find.text('${fmt(plan.kcal)} kcal'), findsWidgets);
    expect(find.textContaining('fija hasta el lunes'), findsOneWidget);
  });
}
