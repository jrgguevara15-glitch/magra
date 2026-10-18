/// Números en formato chileno: coma decimal y punto de miles.
String fmt(num? value, [int decimals = 0]) {
  if (value == null || !value.isFinite) return '—';
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final grouped = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) grouped.write('.');
    grouped.write(intPart[i]);
  }
  final sign = value < 0 && double.parse(fixed) != 0 ? '−' : '';
  return parts.length > 1 ? '$sign$grouped,${parts[1]}' : '$sign$grouped';
}

const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// 2-ago-2021
String fmtDate(DateTime d) => '${d.day}-${_months[d.month - 1]}-${d.year}';

/// yyyy-mm-dd para la base de datos.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Lee un número escrito con coma o punto decimal. `null` si está vacío o
/// no es número.
double? parseNum(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}
