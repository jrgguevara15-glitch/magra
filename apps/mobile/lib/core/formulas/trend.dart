/// Un pesaje.
class WeighIn {
  const WeighIn(this.date, this.weightKg);

  final DateTime date;
  final double weightKg;
}

/// Qué hacer con la meta según la tendencia de peso.
enum TrendAdvice {
  /// Menos de 3 pesajes en la ventana.
  notEnoughData,

  /// Baja más de 1 % del peso por semana: subir ~150 kcal.
  tooFast,

  /// Baja menos de la mitad del ritmo meta: revisar registro y, si se
  /// repite, bajar 100–150 kcal.
  tooSlow,

  onTrack,
}

class WeightTrend {
  const WeightTrend({
    required this.kgPerWeek,
    required this.samples,
    required this.advice,
  });

  /// Pendiente en kg por semana (negativa = bajando). `null` sin datos.
  final double? kgPerWeek;
  final int samples;
  final TrendAdvice advice;
}

/// Tendencia por regresión lineal de los pesajes de los últimos
/// [windowDays] días, comparada con el ritmo meta.
WeightTrend weightTrend(
  List<WeighIn> weighIns, {
  required double paceKgPerWeek,
  int windowDays = 28,
}) {
  if (weighIns.isEmpty) {
    return const WeightTrend(
        kgPerWeek: null, samples: 0, advice: TrendAdvice.notEnoughData);
  }
  final sorted = [...weighIns]..sort((a, b) => a.date.compareTo(b.date));
  final last = sorted.last.date;
  final window = sorted
      .where((w) => last.difference(w.date).inDays <= windowDays)
      .toList();
  if (window.length < 3) {
    return WeightTrend(
        kgPerWeek: null,
        samples: window.length,
        advice: TrendAdvice.notEnoughData);
  }

  final slope = slopeKgPerWeek(window);
  final n = window.length;

  final loss = -slope;
  final currentWeight = window.last.weightKg;
  final TrendAdvice advice;
  if (loss / currentWeight * 100 > 1) {
    advice = TrendAdvice.tooFast;
  } else if (loss < paceKgPerWeek * 0.5) {
    advice = TrendAdvice.tooSlow;
  } else {
    advice = TrendAdvice.onTrack;
  }
  return WeightTrend(kgPerWeek: slope, samples: n, advice: advice);
}

/// Pendiente por regresión lineal, en kg por semana (pesajes ordenados).
double slopeKgPerWeek(List<WeighIn> sorted) {
  final last = sorted.last.date;
  final xs = [
    for (final w in sorted) w.date.difference(last).inHours / (24 * 7),
  ];
  final ys = [for (final w in sorted) w.weightKg];
  final n = xs.length;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var num = 0.0, den = 0.0;
  for (var i = 0; i < n; i++) {
    num += (xs[i] - mx) * (ys[i] - my);
    den += (xs[i] - mx) * (xs[i] - mx);
  }
  return den == 0 ? 0.0 : num / den;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Peso de tendencia: un punto por día desde el primer pesaje hasta el
/// último. Los días sin pesaje se interpolan y se aplica una media móvil
/// exponencial (α = 0,1) que filtra el agua, la sal y el tránsito.
List<WeighIn> trendLine(List<WeighIn> weighIns, {double alpha = 0.1}) {
  if (weighIns.isEmpty) return const [];
  // Un pesaje por día (el último de ese día).
  final byDay = <DateTime, double>{};
  for (final w in [...weighIns]..sort((a, b) => a.date.compareTo(b.date))) {
    byDay[_day(w.date)] = w.weightKg;
  }
  final days = byDay.keys.toList()..sort();
  final out = <WeighIn>[];
  var ema = byDay[days.first]!;
  for (var i = 0; i < days.length; i++) {
    final day = days[i];
    if (i > 0) {
      final prev = days[i - 1];
      // Redondeo: un día con cambio de horario dura 23 o 25 h.
      final gap = (day.difference(prev).inHours / 24).round();
      for (var k = 1; k <= gap; k++) {
        final raw =
            byDay[prev]! + (byDay[day]! - byDay[prev]!) * k / gap;
        ema += alpha * (raw - ema);
        out.add(WeighIn(DateTime(prev.year, prev.month, prev.day + k), ema));
      }
    } else {
      out.add(WeighIn(day, ema));
    }
  }
  return out;
}

/// Kcal que equivalen a 1 kg de grasa.
const double kcalPerKgFat = 7700;

/// Gasto real estimado con lo que come y cómo cambia el peso.
class AdaptiveTdee {
  const AdaptiveTdee({
    required this.tdee,
    required this.avgIntake,
    required this.loggedDays,
    required this.kgPerWeek,
  });

  /// kcal por día.
  final double tdee;

  /// Promedio de los días registrados completos.
  final double avgIntake;
  final int loggedDays;
  final double kgPerWeek;
}

/// Gasto real ≈ ingesta promedio − Δpeso × 7.700 / días.
///
/// Usa los últimos [windowDays] días sin contar hoy (incompleto). Un día
/// cuenta si se registraron al menos [minDayKcal] (si no, faltó anotar).
/// `null` si hay menos de [minLoggedDays] días o menos de 3 pesajes que
/// abarquen 10 días.
AdaptiveTdee? adaptiveTdee({
  required Map<DateTime, double> dailyKcal,
  required List<WeighIn> weighIns,
  required DateTime today,
  required double minDayKcal,
  int windowDays = 21,
  int minLoggedDays = 10,
}) {
  final end = _day(today);
  final start = end.subtract(Duration(days: windowDays));
  final intake = [
    for (final e in dailyKcal.entries)
      if (!_day(e.key).isBefore(start) &&
          _day(e.key).isBefore(end) &&
          e.value >= minDayKcal)
        e.value,
  ];
  if (intake.length < minLoggedDays) return null;
  final window = [
    for (final w in weighIns)
      if (!_day(w.date).isBefore(start) && !_day(w.date).isAfter(end)) w,
  ]..sort((a, b) => a.date.compareTo(b.date));
  if (window.length < 3 ||
      window.last.date.difference(window.first.date).inDays < 10) {
    return null;
  }
  final slope = slopeKgPerWeek(window);
  final avg = intake.reduce((a, b) => a + b) / intake.length;
  final tdee = avg - slope * kcalPerKgFat / 7;
  // Fuera de lo fisiológico: el registro o los pesajes no son confiables.
  if (tdee < 1000 || tdee > 6000) return null;
  return AdaptiveTdee(
    tdee: tdee,
    avgIntake: avg,
    loggedDays: intake.length,
    kgPerWeek: slope,
  );
}
