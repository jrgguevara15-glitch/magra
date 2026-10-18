import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/formulas/formulas.dart';
import 'package:magra/features/progress/progress_page.dart';

import '../support/fakes.dart';
import '../widget_test.dart' show setSize;

Future<void> openProgress(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.monitor_weight_outlined));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin perfil pide completarlo y lo guarda', (tester) async {
    setSize(tester, const Size(500, 1400));
    final profiles = FakeProfiles();
    await tester.pumpWidget(
        testApp(auth: FakeAuth(signedIn: true), profiles: profiles));
    await tester.pumpAndSettle();
    await openProgress(tester);

    expect(find.text('Completa tu perfil'), findsOneWidget);

    // Sin fecha de nacimiento no guarda.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Estatura'), '180');
    await tester.tap(find.text('Guardar perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Elige tu fecha de nacimiento.'), findsOneWidget);
    expect(profiles.profile, isNull);

    await tester.tap(find.text('Fecha de nacimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar perfil'));
    await tester.pumpAndSettle();

    expect(profiles.profile, isNotNull);
    expect(profiles.profile!.heightCm, 180);
    expect(profiles.profile!.lowCarbDays, [2, 4]);
    expect(find.text('Nueva medición'), findsOneWidget);
  });

  testWidgets('evaluación con las mediciones de Magic Formula', (tester) async {
    setSize(tester, const Size(900, 2400));
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(juniorProfile),
      measurements: FakeMeasurements(magicFormulaMeasurements),
    ));
    await tester.pumpAndSettle();
    await openProgress(tester);

    expect(find.text('Hola, Junior'), findsOneWidget);
    // Feb-2022: 110,9 kg, cuello 44, cintura 102 → 23,9 % (no 18,74).
    expect(find.text('110,9 kg'), findsOneWidget);
    expect(find.text('23,9 %'), findsOneWidget);
    expect(find.text('● Alto'), findsOneWidget);
    expect(find.text('● Obesidad tipo I'), findsOneWidget);
    // Historial con las 5 mediciones y el % informado distinto.
    expect(find.textContaining('Nutri · Dieta'), findsNWidgets(5));
    expect(find.textContaining('informado 18,7 %'), findsOneWidget);
  });

  testWidgets('nueva medición se guarda y aparece', (tester) async {
    setSize(tester, const Size(500, 1400));
    final store = FakeMeasurements();
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(juniorProfile),
      measurements: store,
    ));
    await tester.pumpAndSettle();
    await openProgress(tester);

    await tester.tap(find.text('Nueva medición'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Peso'), '108,5');
    await tester.enterText(find.widgetWithText(TextFormField, 'Cuello'), '43');
    await tester.enterText(find.widgetWithText(TextFormField, 'Cintura'), '100');
    await tester.tap(find.text('Guardar medición'));
    await tester.pumpAndSettle();

    expect(store.items, hasLength(1));
    expect(store.items.single.weightKg, 108.5);
    expect(find.byType(EvaluationCard), findsOneWidget);
    expect(find.text('108,5 kg'), findsWidgets);
  });

  testWidgets('rechaza cintura menor que el cuello', (tester) async {
    setSize(tester, const Size(500, 1400));
    final store = FakeMeasurements();
    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(juniorProfile),
      measurements: store,
    ));
    await tester.pumpAndSettle();
    await openProgress(tester);

    await tester.tap(find.text('Nueva medición'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Peso'), '108');
    await tester.enterText(find.widgetWithText(TextFormField, 'Cuello'), '44');
    await tester.enterText(find.widgetWithText(TextFormField, 'Cintura'), '40');
    await tester.tap(find.text('Guardar medición'));
    await tester.pumpAndSettle();

    expect(find.text('La cintura debe ser mayor que el cuello.'), findsOneWidget);
    expect(store.items, isEmpty);
  });

  testWidgets('teléfono de 360 px: perfil y evaluación sin desbordes',
      (tester) async {
    setSize(tester, const Size(360, 2400));
    await tester.pumpWidget(testApp(auth: FakeAuth(signedIn: true)));
    await tester.pumpAndSettle();
    await openProgress(tester);
    expect(find.text('Completa tu perfil'), findsOneWidget);

    await tester.pumpWidget(testApp(
      auth: FakeAuth(signedIn: true),
      profiles: FakeProfiles(juniorProfile),
      measurements: FakeMeasurements(magicFormulaMeasurements),
    ));
    await tester.pumpAndSettle();
    await openProgress(tester);
    expect(find.byType(EvaluationCard), findsOneWidget);
    await tester.tap(find.byTooltip('Editar perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar perfil'), findsOneWidget);
  });

  test('perfil de Junior: edad y meta', () {
    expect(juniorProfile.ageOn(DateTime(2026, 10, 18)), 40);
    expect(juniorProfile.ageOn(DateTime(2027, 2, 28)), 40);
    expect(juniorProfile.ageOn(DateTime(2027, 3, 1)), 41);
    expect(juniorProfile.sex, Sex.male);
  });
}
