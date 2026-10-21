import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/recommendation/seasoning.dart';
import 'package:magra/features/progress/measurement.dart';
import 'package:magra/features/questionnaire/questionnaire.dart';

import '../support/fakes.dart';
import '../support/sections.dart';
import '../widget_test.dart' show setSize;

final now = DateTime.now();
final today = DateTime(now.year, now.month, now.day);

void main() {
  test('grasas saludables según alergias y dieta', () {
    final all = healthyFatTips(Questionnaire.initial);
    expect(all.any((t) => t.startsWith('Aceite de oliva')), isTrue);
    expect(all.any((t) => t.contains('Nueces')), isTrue);
    expect(all.any((t) => t.contains('salmón')), isTrue);
    final allergic = healthyFatTips(Questionnaire.initial.copyWith(
        allergies: [Allergy.treeNuts, Allergy.peanut, Allergy.fish]));
    expect(allergic.any((t) => t.contains('Nueces') || t.contains('maní') || t.contains('salmón')), isFalse);
    final vegan = healthyFatTips(Questionnaire.initial.copyWith(dietPattern: DietPattern.vegan));
    expect(vegan.any((t) => t.contains('salmón')), isFalse);
    expect(seasoningTipsFor(Questionnaire.initial).first, contains('pollo'));
    final veg = seasoningTipsFor(Questionnaire.initial.copyWith(dietPattern: DietPattern.vegetarian));
    expect(veg.any((t) => t.contains('pollo') || t.contains('pescado') || t.contains('carne')), isFalse);
    expect(veg.any((t) => t.contains('Merkén')), isTrue);
  });

  testWidgets('el Plan muestra grasas y condimentos recomendados', (tester) async {
    setSize(tester, const Size(700, 5000));
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(sampleProfile),
      measurements: FakeMeasurements([
        Measurement(id: 'm', date: today, weightKg: 95, neckCm: 40, waistCm: 100),
      ]),
      questionnaires: FakeQuestionnaires(Questionnaire.initial),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();
    await openSection(tester, 'Grasas saludables');
    await openSection(tester, 'Condimentos');
    expect(find.text('Grasas saludables recomendadas'), findsOneWidget);
    expect(find.text('Condimentos y sazón'), findsOneWidget);
    expect(find.textContaining('Aceite de oliva extra virgen'), findsOneWidget);
  });
}
