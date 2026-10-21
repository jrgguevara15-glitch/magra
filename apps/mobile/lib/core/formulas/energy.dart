import 'body_composition.dart';

/// Tipo de día del plan. En los días sin carbohidratos cada comida lleva
/// solo proteína, lípido y vegetales (regla del nutricionista).
enum DayType { normal, lowCarb }

/// Factores de actividad fuera del entrenamiento.
abstract final class ActivityFactor {
  /// Sedentario. El que usó el nutricionista.
  static const double sedentary = 1.2;
  static const double light = 1.375;
  static const double active = 1.55;
}

/// Ajustes del día sin carbohidratos: proteína y lípido +25 %,
/// vegetales ×1,5 para no pasar hambre.
abstract final class LowCarbRules {
  static const double proteinFactor = 1.25;
  static const double lipidFactor = 1.25;
  static const double vegetableFactor = 1.5;

  /// Carbohidratos que aportan los vegetales del día, en gramos.
  static const double vegetableCarbsG = 30;

  /// Proteína que aportan los vegetales del día, en gramos.
  static const double vegetableProteinG = 8;
}

/// kcal diarias reservadas para vegetales en el plan de intercambios.
const double vegetableKcalPerDay = 100;

/// Tasa metabólica basal (Mifflin-St Jeor).
double bmrMifflin({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
}) =>
    10 * weightKg + 6.25 * heightCm - 5 * age + (sex == Sex.male ? 5 : -161);

/// Tasa metabólica basal según la masa magra (Katch-McArdle). Más precisa
/// que Mifflin cuando se conoce el % de grasa, sobre todo con mucha o poca
/// grasa corporal.
double bmrKatchMcArdle(double leanKg) => 370 + 21.6 * leanKg;

/// Fórmula usada para el metabolismo basal.
enum BmrFormula {
  mifflin('Mifflin-St Jeor'),
  katch('Katch-McArdle');

  const BmrFormula(this.label);
  final String label;
}

/// % de grasa con el que se puede usar Katch-McArdle (fuera de este rango
/// la medición probablemente está mal).
bool usableBodyFat(double? pct) => pct != null && pct >= 4 && pct <= 60;

/// Reparto de macronutrientes en % de las calorías.
class MacroSplit {
  const MacroSplit({
    required this.proteinPct,
    required this.carbPct,
    required this.lipidPct,
  });

  /// Último plan del nutricionista (feb-2022).
  static const nutritionistDefault =
      MacroSplit(proteinPct: 30, carbPct: 45, lipidPct: 25);

  final double proteinPct;
  final double carbPct;
  final double lipidPct;

  bool get isValid => (proteinPct + carbPct + lipidPct - 100).abs() < 0.5;
}

class MacroGrams {
  const MacroGrams({
    required this.protein,
    required this.carbs,
    required this.lipids,
  });

  final double protein;
  final double carbs;
  final double lipids;
}

/// Calorías y macros objetivo de un día.
class EnergyTarget {
  const EnergyTarget({
    required this.bmr,
    required this.tdee,
    required this.baseKcal,
    required this.kcal,
    required this.grams,
    required this.dayType,
    required this.floorApplied,
    this.formula = BmrFormula.mifflin,
  });

  /// Metabolismo basal.
  final double bmr;

  /// Con qué fórmula se calculó [bmr].
  final BmrFormula formula;

  /// Gasto diario = TMB × factor de actividad.
  final double tdee;

  /// Meta de un día normal (gasto − déficit, con piso de seguridad).
  final double baseKcal;

  /// Meta del tipo de día pedido.
  final double kcal;
  final MacroGrams grams;
  final DayType dayType;

  /// `true` si la meta quedó en el mínimo seguro y no baja más.
  final bool floorApplied;

  double get deficit => tdee - kcal;
}

/// Mínimo diario seguro, sin supervisión médica.
double safeFloorKcal(Sex sex) => sex == Sex.male ? 1500 : 1200;

/// Meta diaria como la calcula el nutricionista:
/// TMB × actividad − (ritmo kg/semana × 1.000 kcal). La TMB sale de
/// Katch-McArdle si se conoce el % de grasa ([bodyFatPct]); si no, de
/// Mifflin-St Jeor.
EnergyTarget energyTarget({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
  double activityFactor = ActivityFactor.sedentary,
  double paceKgPerWeek = 0.5,
  MacroSplit split = MacroSplit.nutritionistDefault,
  DayType dayType = DayType.normal,
  double? bodyFatPct,
}) {
  final katch = usableBodyFat(bodyFatPct);
  final bmr = katch
      ? bmrKatchMcArdle(weightKg * (1 - bodyFatPct! / 100))
      : bmrMifflin(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age);
  final formula = katch ? BmrFormula.katch : BmrFormula.mifflin;
  final tdee = bmr * activityFactor;
  final wanted = tdee - paceKgPerWeek * 1000;
  final floor = safeFloorKcal(sex);
  final base = wanted < floor ? floor : wanted;

  final normalGrams = MacroGrams(
    protein: base * split.proteinPct / 100 / 4,
    carbs: base * split.carbPct / 100 / 4,
    lipids: base * split.lipidPct / 100 / 9,
  );

  if (dayType == DayType.normal) {
    return EnergyTarget(
      bmr: bmr,
      tdee: tdee,
      baseKcal: base,
      kcal: base,
      grams: normalGrams,
      dayType: dayType,
      floorApplied: wanted < floor,
      formula: formula,
    );
  }

  final kcal = base * split.proteinPct / 100 * LowCarbRules.proteinFactor +
      base * split.lipidPct / 100 * LowCarbRules.lipidFactor +
      vegetableKcalPerDay * LowCarbRules.vegetableFactor;
  return EnergyTarget(
    bmr: bmr,
    tdee: tdee,
    baseKcal: base,
    kcal: kcal,
    grams: MacroGrams(
      protein: normalGrams.protein * LowCarbRules.proteinFactor +
          LowCarbRules.vegetableProteinG,
      carbs: LowCarbRules.vegetableCarbsG,
      lipids: normalGrams.lipids * LowCarbRules.lipidFactor,
    ),
    dayType: dayType,
    floorApplied: wanted < floor,
    formula: formula,
  );
}
