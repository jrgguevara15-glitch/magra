import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/app.dart';
import 'package:magra/features/shell/home_shell.dart';

void main() {
  testWidgets('teléfono: barra inferior con las 6 pestañas', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MagraApp());

    expect(find.text('MAGRA'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination),
        findsNWidgets(magraDestinations.length));
  });

  testWidgets('cambiar de pestaña muestra su pantalla', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MagraApp());
    await tester.tap(find.byIcon(Icons.shopping_basket_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Menú semanal con marcas y lista de compras.'),
        findsOneWidget);
  });

  testWidgets('escritorio: navegación lateral', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MagraApp());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
