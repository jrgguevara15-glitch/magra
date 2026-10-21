import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abre una sección de la pantalla tocando su subtítulo del índice.
Future<void> openSection(WidgetTester tester, String title) async {
  await tester.tap(find.widgetWithText(ActionChip, title));
  await tester.pumpAndSettle();
}
