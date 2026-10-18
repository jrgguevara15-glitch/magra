import '../../core/format.dart';
import '../../core/formulas/formulas.dart';

/// Perfil del usuario: los datos que necesitan las fórmulas.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.sex,
    required this.birthDate,
    required this.heightCm,
    this.activityFactor = ActivityFactor.sedentary,
    this.paceKgPerWeek = 0.5,
    this.goalFatPct = 17,
    this.split = MacroSplit.nutritionistDefault,
    this.lowCarbDays = const [2, 4],
  });

  final String name;
  final Sex sex;
  final DateTime birthDate;
  final double heightCm;
  final double activityFactor;
  final double paceKgPerWeek;
  final double goalFatPct;
  final MacroSplit split;

  /// Días de la semana sin carbohidratos (1 = lunes … 7 = domingo).
  final List<int> lowCarbDays;

  /// Edad cumplida a la fecha dada.
  int ageOn(DateTime date) {
    var age = date.year - birthDate.year;
    final hadBirthday = date.month > birthDate.month ||
        (date.month == birthDate.month && date.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }

  factory UserProfile.fromRow(Map<String, dynamic> row) => UserProfile(
        name: row['name'] as String? ?? '',
        sex: row['sex'] == 'female' ? Sex.female : Sex.male,
        birthDate: DateTime.parse(row['birth_date'] as String),
        heightCm: (row['height_cm'] as num).toDouble(),
        activityFactor: (row['activity_factor'] as num).toDouble(),
        paceKgPerWeek: (row['pace_kg_week'] as num).toDouble(),
        goalFatPct: (row['goal_fat_pct'] as num).toDouble(),
        split: MacroSplit(
          proteinPct: (row['protein_pct'] as num).toDouble(),
          carbPct: (row['carb_pct'] as num).toDouble(),
          lipidPct: (row['lipid_pct'] as num).toDouble(),
        ),
        lowCarbDays: [
          for (final d in (row['low_carb_days'] as List? ?? const []))
            (d as num).toInt(),
        ],
      );

  Map<String, dynamic> toRow() => {
        'name': name,
        'sex': sex == Sex.female ? 'female' : 'male',
        'birth_date': isoDate(birthDate),
        'height_cm': heightCm,
        'activity_factor': activityFactor,
        'pace_kg_week': paceKgPerWeek,
        'goal_fat_pct': goalFatPct,
        'protein_pct': split.proteinPct,
        'carb_pct': split.carbPct,
        'lipid_pct': split.lipidPct,
        'low_carb_days': lowCarbDays,
      };
}
