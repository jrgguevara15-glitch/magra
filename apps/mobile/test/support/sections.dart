import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abre una sección (lista o cuadrícula) por su título; si ya está abierta,
/// no la cierra.
Future<void> openSection(WidgetTester tester, String title) async {
  var closed = find.byKey(ValueKey('section-closed-$title'));
  if (closed.evaluate().isEmpty && find.byKey(ValueKey('section-open-$title')).evaluate().isEmpty) {
    // Puede estar en otra pestaña de la pantalla: probar cada una.
    final tabs = find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('tab-'));
    for (final tab in tabs.evaluate().map((e) => e.widget.key!).toList()) {
      await tester.tap(find.byKey(tab));
      await tester.pumpAndSettle();
      if (find.byKey(ValueKey('section-closed-$title')).evaluate().isNotEmpty ||
          find.byKey(ValueKey('section-open-$title')).evaluate().isNotEmpty) {
        break;
      }
    }
    closed = find.byKey(ValueKey('section-closed-$title'));
  }
  if (closed.evaluate().isEmpty) return;
  await tester.ensureVisible(closed);
  await tester.pumpAndSettle();
  await tester.tap(closed);
  await tester.pumpAndSettle();
}

/// El botón para agregar un alimento a una comida (la primera si hay varias).
Finder addFoodButton() => find.byWidgetPredicate(
    (w) => w is IconButton && (w.tooltip ?? '').startsWith('Agregar alimento'));
