import 'package:supabase_flutter/supabase_flutter.dart';

/// Mensaje claro cuando falla un guardado: si a la base le falta una tabla o
/// columna (migración sin aplicar) lo dice con el número de [migration];
/// si no, muestra el detalle del error para poder diagnosticarlo.
String saveErrorMessage(Object e, {required String migration}) {
  if (e is PostgrestException) {
    const missing = {'42P01', 'PGRST205', '42703', 'PGRST204'};
    if (missing.contains(e.code)) {
      return 'Falta aplicar la migración $migration en Supabase (SQL Editor). '
          'Pégala, ejecútala y vuelve a intentar.';
    }
    return 'No se pudo guardar: ${e.message}';
  }
  return 'No se pudo guardar. Revisa tu conexión.';
}
