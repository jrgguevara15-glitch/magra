import '../format.dart';

/// Lo comido en un día.
class DayTotals {
  const DayTotals(this.kcal, this.protein);

  final double kcal;
  final double protein;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _minus(DateTime d, int days) => DateTime(d.year, d.month, d.day - days);

/// Días seguidos que cumplen [ok] hasta hoy. Si hoy aún no cumple, cuenta
/// hasta ayer (el día no ha terminado, la racha no se corta).
int currentStreak(bool Function(DateTime day) ok, DateTime today) {
  var day = _day(today);
  if (!ok(day)) day = _minus(day, 1);
  var n = 0;
  while (ok(day) && n < 3650) {
    n++;
    day = _minus(day, 1);
  }
  return n;
}

/// La racha más larga dentro de [days].
int bestStreak(Iterable<DateTime> days) {
  final sorted = {for (final d in days) _day(d)}.toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final d in sorted) {
    run = prev != null && _minus(d, 1) == prev ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

/// Un día cuenta como registrado si tiene al menos el 60 % del mínimo
/// seguro (si no, faltó anotar).
bool loggedDay(DayTotals? t, double floorKcal) => t != null && t.kcal >= floorKcal * 0.6;

/// Llegó a su proteína: al menos el 90 % de la meta.
bool proteinDay(DayTotals? t, double proteinTarget) =>
    t != null && proteinTarget > 0 && t.protein >= proteinTarget * 0.9;

DateTime _weekStart(DateTime d) => _minus(d, d.weekday - DateTime.monday);

/// Semanas seguidas con las sesiones planificadas. La semana en curso
/// cuenta si ya se cumplió; si no, se cuenta desde la anterior.
int trainingWeekStreak(List<DateTime> sessions, int perWeek, DateTime today) {
  if (perWeek <= 0) return 0;
  final count = <DateTime, int>{};
  for (final s in sessions) {
    final w = _weekStart(s);
    count[w] = (count[w] ?? 0) + 1;
  }
  var week = _weekStart(today);
  if ((count[week] ?? 0) < perWeek) week = _minus(week, 7);
  var n = 0;
  while ((count[week] ?? 0) >= perWeek && n < 520) {
    n++;
    week = _minus(week, 7);
  }
  return n;
}

/// Semáforo de un alimento por densidad calórica (kcal por gramo o ml),
/// corregido por proteína: lo que más sacia por menos calorías.
enum FoodLight {
  green('Verde: sacia mucho por pocas calorías'),
  yellow('Amarillo: con medida'),
  red('Rojo: muchas calorías en poco volumen');

  const FoodLight(this.label);
  final String label;
}

/// `null` si no se puede calcular (en unidades o sin cantidad).
FoodLight? foodLight({
  required double kcal,
  required double protein,
  required double? quantity,
  required String unit,
}) {
  if (quantity == null || quantity <= 0 || (unit != 'g' && unit != 'ml')) return null;
  final density = kcal / quantity;
  // ≥ 10 g de proteína por cada 100 kcal sube un nivel (carnes magras,
  // lácteos descremados, huevo).
  final proteinRich = kcal > 0 && protein / kcal * 100 >= 10;
  FoodLight light;
  if (unit == 'ml') {
    light = density <= 0.2
        ? FoodLight.green
        : density <= 0.4
            ? FoodLight.yellow
            : FoodLight.red;
  } else {
    light = density < 1.5
        ? FoodLight.green
        : density <= 4
            ? FoodLight.yellow
            : FoodLight.red;
  }
  if (proteinRich && light != FoodLight.green) {
    light = light == FoodLight.red ? FoodLight.yellow : FoodLight.green;
  }
  return light;
}

/// Lo máximo que se guarda por día y lo máximo que se usa en un día.
const bankPerDayMax = 150;
const bankUseMax = 500;

/// Banco de calorías de la semana (lunes a ayer): por cada día registrado
/// que comió bajo su meta sin bajar del mínimo seguro, guarda la
/// diferencia (hasta 150). Se descuenta lo ya usado en la semana. No pasa
/// de una semana a otra.
int bankAvailable({
  required Map<DateTime, DayTotals> history,
  required double targetKcal,
  required double floorKcal,
  required Map<DateTime, int> uses,
  required DateTime today,
}) {
  final start = _weekStart(today);
  final t = _day(today);
  var saved = 0.0;
  for (var d = start; d.isBefore(t); d = DateTime(d.year, d.month, d.day + 1)) {
    final day = history[d];
    if (!loggedDay(day, floorKcal) || day!.kcal < floorKcal) continue;
    final under = targetKcal - day.kcal;
    if (under > 0) saved += under > bankPerDayMax ? bankPerDayMax : under;
  }
  var used = 0;
  uses.forEach((d, kcal) {
    if (!d.isBefore(start) && d.isBefore(t)) used += kcal;
  });
  final left = (saved - used).floor();
  return left < 0 ? 0 : left;
}

/// Un logro con su avance.
class Achievement {
  const Achievement(this.id, this.title, this.detail, {required this.done, this.progress = 0});

  final String id;
  final String title;

  /// Qué pide o cuánto falta.
  final String detail;
  final bool done;

  /// 0–1.
  final double progress;
}

/// Datos de una medición para los logros.
class BodyPoint {
  const BodyPoint(this.date, this.weightKg, {this.fatKg, this.waistCm});

  final DateTime date;
  final double weightKg;
  final double? fatKg;
  final double? waistCm;
}

Achievement _goal(String id, String title, String unit, double done, double goal) {
  final ok = done >= goal;
  final left = goal - done;
  return Achievement(
    id,
    title,
    ok
        ? '¡Logrado!'
        : 'Te faltan ${fmt(left, left % 1 == 0 ? 0 : 1)} $unit',
    done: ok,
    progress: goal <= 0 ? 0 : (done / goal).clamp(0, 1).toDouble(),
  );
}

/// Logros por hitos reales con los datos registrados.
List<Achievement> achievements({
  required List<BodyPoint> body,
  required Iterable<DateTime> loggedDays,
  required Iterable<DateTime> proteinDays,
  required int workouts,
  required List<DateTime> photoDates,
}) {
  final sorted = [...body]..sort((a, b) => a.date.compareTo(b.date));
  double lost(double? Function(BodyPoint p) f) {
    final values = [for (final p in sorted) if (f(p) != null) f(p)!];
    if (values.length < 2) return 0;
    final first = values.first;
    final last = values.last;
    return first - last > 0 ? first - last : 0;
  }

  final weightLost = lost((p) => p.weightKg);
  final fatLost = lost((p) => p.fatKg);
  final waistLost = lost((p) => p.waistCm);
  final stage = sorted.isEmpty ? 0.0 : sorted.first.weightKg * 0.10;
  final logStreak = bestStreak(loggedDays).toDouble();
  final proteinStreak = bestStreak(proteinDays).toDouble();
  final photos = [...photoDates]..sort();
  final photoSpan = photos.length < 2 ? 0 : photos.last.difference(photos.first).inDays;

  return [
    _goal('log_7', 'Una semana registrando', 'días', logStreak, 7),
    _goal('log_30', '30 días registrando', 'días', logStreak, 30),
    _goal('protein_7', '7 días con tu proteína', 'días', proteinStreak, 7),
    _goal('fat_1', 'Primer kilo de grasa menos', 'kg', fatLost, 1),
    _goal('fat_5', '5 kg de grasa menos', 'kg', fatLost, 5),
    _goal('weight_5', '−5 kg en la balanza', 'kg', weightLost, 5),
    _goal('waist_5', '−5 cm de cintura', 'cm', waistLost, 5),
    if (stage > 0) _goal('stage_1', 'Primera etapa (−10 % del peso)', 'kg', weightLost, stage),
    _goal('workouts_10', '10 entrenos', 'entrenos', workouts.toDouble(), 10),
    _goal('workouts_50', '50 entrenos', 'entrenos', workouts.toDouble(), 50),
    Achievement('photos_1', 'Primeras fotos de progreso',
        photos.isEmpty ? 'Sube tus fotos en Progreso' : '¡Logrado!',
        done: photos.isNotEmpty, progress: photos.isEmpty ? 0 : 1),
    _goal('photos_2m', 'Dos meses de fotos', 'días', photoSpan.toDouble(), 56),
  ];
}
