/// kcal por kg de tejido graso (valor estándar; el nutricionista usaba
/// ~9.000, que es el de la grasa pura).
const double kcalPerKgFatTissue = 7700;

/// Meta física: llegar a un % de grasa conservando la masa magra actual.
class PhysicalGoal {
  const PhysicalGoal._({
    required this.goalWeightKg,
    required this.fatToLoseKg,
    required this.kcalToBurn,
    required this.weeks,
  });

  factory PhysicalGoal.from({
    required double weightKg,
    required double leanKg,
    required double goalFatPct,
    required double dailyDeficitKcal,
  }) {
    final goalWeight = leanKg / (1 - goalFatPct / 100);
    final fatToLose = weightKg - goalWeight;
    final lose = fatToLose > 0 ? fatToLose : 0.0;
    final kcal = lose * kcalPerKgFatTissue;
    return PhysicalGoal._(
      goalWeightKg: goalWeight,
      fatToLoseKg: lose,
      kcalToBurn: kcal,
      weeks: dailyDeficitKcal > 0 ? kcal / (dailyDeficitKcal * 7) : null,
    );
  }

  final double goalWeightKg;
  final double fatToLoseKg;
  final double kcalToBurn;

  /// `null` si no hay déficit.
  final double? weeks;

  double? get months => weeks == null ? null : weeks! / 4.345;
}
