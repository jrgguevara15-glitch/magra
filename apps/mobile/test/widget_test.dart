import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magra/features/auth/auth_page.dart';
import 'package:magra/features/shell/home_shell.dart';

import 'support/fakes.dart';

void setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('sin sesión muestra el inicio de sesión', (tester) async {
    setSize(tester, const Size(400, 800));
    await tester.pumpWidget(testApp(auth: FakeAuth()));
    await tester.pumpAndSettle();

    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('valida el formulario antes de entrar', (tester) async {
    setSize(tester, const Size(400, 800));
    final auth = FakeAuth();
    await tester.pumpWidget(testApp(auth: auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Escribe un correo válido.'), findsOneWidget);
    expect(find.text('Mínimo 8 caracteres.'), findsOneWidget);
    expect(auth.lastPassword, isNull);
  });

  testWidgets('al entrar pasa a la app y al salir vuelve', (tester) async {
    setSize(tester, const Size(400, 800));
    final auth = FakeAuth();
    await tester.pumpWidget(testApp(auth: auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'usuario@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'clave-segura');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthPage), findsOneWidget);
  });

  testWidgets('teléfono: barra inferior con las 6 pestañas', (tester) async {
    setSize(tester, const Size(400, 800));
    await tester.pumpWidget(testApp(auth: FakeAuth(signedIn: true)));
    await tester.pumpAndSettle();

    expect(find.text('MAGRA'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination),
        findsNWidgets(magraDestinations.length));
  });

  testWidgets('cambiar de pestaña muestra su pantalla', (tester) async {
    setSize(tester, const Size(400, 800));
    await tester.pumpWidget(testApp(auth: FakeAuth(signedIn: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shopping_basket_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Para armar tu menú semanal me falta:'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Asesor IA con tus datos.'), findsOneWidget);
  });

  testWidgets('escritorio: navegación lateral', (tester) async {
    setSize(tester, const Size(1280, 800));
    await tester.pumpWidget(testApp(auth: FakeAuth(signedIn: true)));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
