import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import '../profile/user_profile.dart';

/// Una medición: peso y, opcionalmente, perímetros.
class Measurement {
  const Measurement({
    this.id,
    required this.date,
    required this.weightKg,
    this.neckCm,
    this.waistCm,
    this.hipCm,
    this.reportedFatPct,
    this.source = 'app',
  });

  /// `null` hasta que se guarda.
  final String? id;
  final DateTime date;
  final double weightKg;
  final double? neckCm;
  final double? waistCm;
  final double? hipCm;

  /// % grasa informado por un profesional (solo referencia).
  final double? reportedFatPct;
  final String source;

  BodyComposition compositionFor(UserProfile profile) =>
      BodyComposition.from(
        sex: profile.sex,
        heightCm: profile.heightCm,
        weightKg: weightKg,
        neckCm: neckCm,
        waistCm: waistCm,
        hipCm: hipCm,
      );

  factory Measurement.fromRow(Map<String, dynamic> row) {
    double? d(String k) => (row[k] as num?)?.toDouble();
    return Measurement(
      id: row['id'] as String?,
      date: DateTime.parse(row['measured_on'] as String),
      weightKg: d('weight_kg')!,
      neckCm: d('neck_cm'),
      waistCm: d('waist_cm'),
      hipCm: d('hip_cm'),
      reportedFatPct: d('reported_fat_pct'),
      source: row['source'] as String? ?? 'app',
    );
  }

  Map<String, dynamic> toRow() => {
        'measured_on': isoDate(date),
        'weight_kg': weightKg,
        'neck_cm': neckCm,
        'waist_cm': waistCm,
        'hip_cm': hipCm,
        'reported_fat_pct': reportedFatPct,
        'source': source,
      };
}
