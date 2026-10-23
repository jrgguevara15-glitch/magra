import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abre una sección (lista o cuadrícula) por su título; si ya está abierta,
/// no la cierra.
Future<void> openSection(WidgetTester tester, String title) async {
  final closed = find.byKey(ValueKey('section-closed-$title'));
  if (closed.evaluate().isEmpty) return;
  await tester.ensureVisible(closed);
  await tester.pumpAndSettle();
  await tester.tap(closed);
  await tester.pumpAndSettle();
}

/// El botón para agregar un alimento a una comida (la primera si hay varias).
Finder addFoodButton() => find.byWidgetPredicate(
    (w) => w is IconButton && (w.tooltip ?? '').startsWith('Agregar alimento'));
