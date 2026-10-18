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

  final xs = [
    for (final w in window) w.date.difference(last).inHours / (24 * 7),
  ];
  final ys = [for (final w in window) w.weightKg];
  final n = xs.length;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var num = 0.0, den = 0.0;
  for (var i = 0; i < n; i++) {
    num += (xs[i] - mx) * (ys[i] - my);
    den += (xs[i] - mx) * (xs[i] - mx);
  }
  final slope = den == 0 ? 0.0 : num / den;

  final loss = -slope;
  final currentWeight = ys.last;
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
