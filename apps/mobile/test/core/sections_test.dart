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

  testWidgets('resumen visible, detalle a un toque',
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

    // Sin índice de chips: cada sección se abre desde su propio título.
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('cuadrícula: cifra visible y el detalle se abre debajo, uno a la vez', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: MagraTheme.neon(),
      home: Scaffold(
        body: ListView(children: const [
          SectionGrid(sections: [
            PageSection(title: 'Pasos', icon: Icons.directions_walk, value: '3.240 / 7.000',
                summary: 'resumen pasos', child: Text('detalle pasos')),
            PageSection(title: 'Racha', icon: Icons.local_fire_department, value: '5 días',
                child: Text('detalle racha')),
          ]),
        ]),
      ),
    ));
    expect(find.text('3.240 / 7.000'), findsOneWidget);
    expect(find.text('detalle pasos'), findsNothing);
    await tester.tap(find.text('3.240 / 7.000'));
    await tester.pumpAndSettle();
    expect(find.text('detalle pasos'), findsOneWidget);
    expect(find.text('resumen pasos'), findsOneWidget);
    await tester.tap(find.text('5 días'));
    await tester.pumpAndSettle();
    expect(find.text('detalle pasos'), findsNothing);
    expect(find.text('detalle racha'), findsOneWidget);
  });
}
