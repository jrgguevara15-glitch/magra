import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/core/theme.dart';
import 'package:magra/core/widgets/sections.dart';

void main() {
  Widget app() => MaterialApp(
        theme: MagraTheme.neon(),
        home: Scaffold(
          body: ListView(children: [
            SectionList(sections: [
              const PageSection(title: 'Uno', icon: Icons.looks_one, initiallyOpen: true,
                  summary: 'resumen uno', child: Text('contenido uno')),
              PageSection(title: 'Dos', icon: Icons.looks_two, summary: 'resumen dos',
                  child: Container(height: 1500, alignment: Alignment.topLeft, child: const Text('contenido dos'))),
              const PageSection(title: 'Tres', icon: Icons.looks_3, summary: 'resumen tres',
                  child: Text('contenido tres')),
            ]),
          ]),
        ),
      );

  testWidgets('resumen visible, detalle a un toque y el índice lleva a la sección',
      (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('contenido uno'), findsOneWidget);
    expect(find.text('contenido dos'), findsNothing);
    expect(find.text('resumen dos'), findsOneWidget);

    await tester.tap(find.text('resumen uno'));
    await tester.pumpAndSettle();
    expect(find.text('contenido uno'), findsNothing);

    await tester.tap(find.text('resumen dos'));
    await tester.pumpAndSettle();
    expect(find.text('contenido dos'), findsOneWidget);

    // "Tres" queda bajo los 1.500 px de "Dos": el índice abre y desplaza.
    expect(find.text('contenido tres'), findsNothing);
    await tester.tap(find.widgetWithText(ActionChip, 'Tres'));
    await tester.pumpAndSettle();
    expect(find.text('contenido tres'), findsOneWidget);
    final y = tester.getTopLeft(find.text('resumen tres')).dy;
    expect(y, inInclusiveRange(0, 900));
  });
}
