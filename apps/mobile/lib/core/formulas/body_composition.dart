import 'dart:math' as math;

/// Sexo biológico; cambia las fórmulas de grasa corporal y TMB.
enum Sex { male, female }

/// Cómo leer un indicador: bien, atención o riesgo.
enum Severity { good, warning, bad }

/// Una clasificación con su texto para mostrar.
class Rating {
  const Rating(this.label, this.severity);

  final String label;
  final Severity severity;

  @override
  bool operator ==(Object other) =>
      other is Rating && other.label == label && other.severity == severity;

  @override
  int get hashCode => Object.hash(label, severity);

  @override
  String toString() => 'Rating($label, $severity)';
}

double _log10(num x) => math.log(x) / math.ln10;

/// % de grasa corporal por la fórmula de la Marina de EE. UU. (medidas en cm).
///
/// La mujer necesita la cadera. Devuelve `null` si faltan medidas o si no
/// tienen sentido (cintura menor o igual que el cuello).
double? bodyFatNavy({
  required Sex sex,
  required double heightCm,
  required double? neckCm,
  required double? waistCm,
  double? hipCm,
}) {
  if (neckCm == null || waistCm == null || heightCm <= 0) return null;
  if (sex == Sex.female) {
    if (hipCm == null) return null;
    final girth = waistCm + hipCm - neckCm;
    if (girth <= 0) return null;
    return 495 /
            (1.29579 - 0.35004 * _log10(girth) + 0.22100 * _log10(heightCm)) -
        450;
  }
  final girth = waistCm - neckCm;
  if (girth <= 0) return null;
  return 495 /
          (1.0324 - 0.19077 * _log10(girth) + 0.15456 * _log10(heightCm)) -
      450;
}

/// Índice de masa corporal.
double bodyMassIndex(double weightKg, double heightCm) {
  final m = heightCm / 100;
  return weightKg / (m * m);
}

/// Resultado de una medición: peso + medidas → composición corporal.
class BodyComposition {
  const BodyComposition._({
    required this.weightKg,
    required this.heightCm,
    required this.bmi,
    required this.fatPct,
    required this.waistCm,
  });

  factory BodyComposition.from({
    required Sex sex,
    required double heightCm,
    required double weightKg,
    double? neckCm,
    double? waistCm,
    double? hipCm,
  }) {
    return BodyComposition._(
      weightKg: weightKg,
      heightCm: heightCm,
      bmi: bodyMassIndex(weightKg, heightCm),
      fatPct: bodyFatNavy(
        sex: sex,
        heightCm: heightCm,
        neckCm: neckCm,
        waistCm: waistCm,
        hipCm: hipCm,
      ),
      waistCm: waistCm,
    );
  }

  final double weightKg;
  final double heightCm;
  final double bmi;

  /// `null` cuando faltan medidas para calcularlo.
  final double? fatPct;
  final double? waistCm;

  double? get fatKg => fatPct == null ? null : weightKg * fatPct! / 100;
  double? get leanKg => fatKg == null ? null : weightKg - fatKg!;

  /// Índice de masa corporal magra: masa magra / estatura².
  double? get imcm {
    final lean = leanKg;
    if (lean == null) return null;
    final m = heightCm / 100;
    return lean / (m * m);
  }

  double? get waistToHeight => waistCm == null ? null : waistCm! / heightCm;
}

Rating bmiRating(double value) {
  if (value < 18.5) return const Rating('Bajo peso', Severity.warning);
  if (value < 25) return const Rating('Normal', Severity.good);
  if (value < 30) return const Rating('Sobrepeso', Severity.warning);
  if (value < 35) return const Rating('Obesidad tipo I', Severity.bad);
  if (value < 40) return const Rating('Obesidad tipo II', Severity.bad);
  return const Rating('Obesidad tipo III', Severity.bad);
}

/// Rango saludable de % grasa según la OMS, por edad y sexo.
class FatRange {
  const FatRange(this.minAge, this.maxAge, this.male, this.female);

  final int minAge;
  final int maxAge;
  final (double, double) male;
  final (double, double) female;

  (double, double) forSex(Sex sex) => sex == Sex.male ? male : female;
}

const omsFatRanges = <FatRange>[
  FatRange(10, 30, (12, 18), (20, 26)),
  FatRange(31, 40, (13, 19), (21, 27)),
  FatRange(41, 50, (14, 20), (22, 28)),
  FatRange(51, 60, (16, 20), (22, 30)),
  FatRange(61, 200, (17, 21), (22, 31)),
];

FatRange omsFatRangeFor(int age) => omsFatRanges.firstWhere(
      (r) => age >= r.minAge && age <= r.maxAge,
      orElse: () => omsFatRanges[1],
    );

/// Puntos sobre el tope saludable donde empieza "Muy alto". Calibrado con
/// los informes del nutricionista: 25,78 % → Alto, 26,40 % → Muy alto
/// (hombre 35 años, tope 19 %).
const double veryHighFatMargin = 7;

Rating fatRating(Sex sex, int age, double fatPct) {
  final (lo, hi) = omsFatRangeFor(age).forSex(sex);
  if (fatPct < lo) return const Rating('Bajo', Severity.warning);
  if (fatPct <= hi) return const Rating('Saludable', Severity.good);
  if (fatPct <= hi + veryHighFatMargin) {
    return const Rating('Alto', Severity.warning);
  }
  return const Rating('Muy alto', Severity.bad);
}

/// Clasificación del IMCM (Eston, Hawes, Martin y Reilly).
Rating imcmRating(Sex sex, double value) {
  final (low, defined, superior) =
      sex == Sex.female ? (13.0, 17.0, 22.0) : (18.0, 21.0, 25.0);
  if (value < low) return const Rating('Bajo', Severity.warning);
  if (value < defined) return const Rating('Promedio', Severity.warning);
  if (value < superior) return const Rating('Definido', Severity.good);
  return const Rating('Nivel superior', Severity.good);
}

Rating waistToHeightRating(double ratio) {
  if (ratio < 0.5) return const Rating('Riesgo bajo', Severity.good);
  if (ratio < 0.6) return const Rating('Riesgo elevado', Severity.warning);
  return const Rating('Riesgo alto', Severity.bad);
}
