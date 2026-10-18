import 'energy.dart';

/// Grupos del sistema de intercambios (colores del plan del nutricionista).
enum FoodGroup { carb, protein, lipid, vegetable, other }

enum PortionUnit { grams, milliliters, portion, cup, unit }

/// Un alimento del plan. Valores nutricionales por 100 g/ml, o por unidad
/// cuando [unit] no es gramos ni mililitros.
class ExchangeFood {
  const ExchangeFood({
    required this.name,
    required this.group,
    required this.unit,
    required this.basePortion,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.lipids,
    this.brand,
  });

  final String name;
  final FoodGroup group;
  final PortionUnit unit;

  /// Porción del plan base (Dieta 04, 24-feb-2022).
  final double basePortion;
  final double kcal;
  final double protein;
  final double carbs;
  final double lipids;

  /// Marca sugerida en supermercados de Chile.
  final String? brand;

  bool get isMeasured =>
      unit == PortionUnit.grams || unit == PortionUnit.milliliters;

  /// Nutrientes para una cantidad dada (g/ml, o unidades).
  Nutrients nutrientsFor(double quantity) {
    final k = isMeasured ? quantity / 100 : quantity;
    return Nutrients(
      kcal: kcal * k,
      protein: protein * k,
      carbs: carbs * k,
      lipids: lipids * k,
    );
  }
}

class Nutrients {
  const Nutrients({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.lipids,
  });

  static const zero = Nutrients(kcal: 0, protein: 0, carbs: 0, lipids: 0);

  final double kcal;
  final double protein;
  final double carbs;
  final double lipids;

  Nutrients operator +(Nutrients o) => Nutrients(
        kcal: kcal + o.kcal,
        protein: protein + o.protein,
        carbs: carbs + o.carbs,
        lipids: lipids + o.lipids,
      );
}

/// Plan base del que salen las porciones: 1.976,8 kcal, P30 / C45 / L25.
abstract final class BasePlan {
  static const double kcal = 1976.8;
  static const MacroSplit split = MacroSplit.nutritionistDefault;
  static const int mealsPerDay = 4;
}

double _groupKcalPerMeal(double dayKcal, MacroSplit split, FoodGroup group) {
  switch (group) {
    case FoodGroup.carb:
      return (dayKcal * split.carbPct / 100 - vegetableKcalPerDay) /
          BasePlan.mealsPerDay;
    case FoodGroup.protein:
      return dayKcal * split.proteinPct / 100 / BasePlan.mealsPerDay;
    case FoodGroup.lipid:
      return dayKcal * split.lipidPct / 100 / BasePlan.mealsPerDay;
    case FoodGroup.vegetable:
    case FoodGroup.other:
      return 1;
  }
}

/// Cuánto se agranda o achica cada grupo respecto del plan base.
///
/// En un día sin carbohidratos el factor de carbohidratos es 0.
double portionScale({
  required FoodGroup group,
  required double baseKcal,
  MacroSplit split = MacroSplit.nutritionistDefault,
  DayType dayType = DayType.normal,
}) {
  if (group == FoodGroup.vegetable) {
    return dayType == DayType.lowCarb ? LowCarbRules.vegetableFactor : 1;
  }
  if (group == FoodGroup.other) return 1;
  final scale = _groupKcalPerMeal(baseKcal, split, group) /
      _groupKcalPerMeal(BasePlan.kcal, BasePlan.split, group);
  if (dayType == DayType.normal) return scale;
  return switch (group) {
    FoodGroup.carb => 0,
    FoodGroup.protein => scale * LowCarbRules.proteinFactor,
    FoodGroup.lipid => scale * LowCarbRules.lipidFactor,
    _ => scale,
  };
}

/// Porción sugerida de un alimento para la meta del día, redondeada a 5.
///
/// Los alimentos por unidad o porción no se escalan. Devuelve `null` si el
/// alimento no corresponde a ese tipo de día (carbohidratos en día sin
/// carbohidratos).
double? suggestedPortion(
  ExchangeFood food, {
  required double baseKcal,
  MacroSplit split = MacroSplit.nutritionistDefault,
  DayType dayType = DayType.normal,
}) {
  if (!food.isMeasured) {
    return dayType == DayType.lowCarb && food.group == FoodGroup.carb
        ? null
        : food.basePortion;
  }
  final scale = portionScale(
    group: food.group,
    baseKcal: baseKcal,
    split: split,
    dayType: dayType,
  );
  if (scale == 0) return null;
  final rounded = (food.basePortion * scale / 5).round() * 5.0;
  return rounded > 0 ? rounded : food.basePortion;
}
