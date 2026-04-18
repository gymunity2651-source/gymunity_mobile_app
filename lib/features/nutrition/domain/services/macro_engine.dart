class MacroEngine {
  const MacroEngine();

  MacroRecommendation calculate({
    required int targetCalories,
    required double weightKg,
    required String goal,
    required int trainingDaysPerWeek,
  }) {
    final normalizedGoal = goal.trim().toLowerCase();
    final proteinFactor = switch (normalizedGoal) {
      'weight_loss' || 'fat_loss' || 'lose_weight' || 'recomposition' => 2.0,
      'build_muscle' || 'muscle_gain' || 'strength' => 1.8,
      _ => 1.6,
    };
    final proteinG = (weightKg * proteinFactor).round().clamp(70, 240);

    final fatPercent = trainingDaysPerWeek >= 5 ? 0.24 : 0.28;
    final fatFromPercent = ((targetCalories * fatPercent) / 9).round();
    final minimumFat = (weightKg * 0.6).round();
    final maxFat = ((targetCalories * 0.35) / 9).round();
    final fatG = fatFromPercent.clamp(minimumFat, maxFat);

    final remainingCalories = targetCalories - (proteinG * 4) - (fatG * 9);
    final carbsG = (remainingCalories / 4).round().clamp(40, 700);

    final proteinPercent = ((proteinG * 4) / targetCalories * 100).round();
    final carbsPercent = ((carbsG * 4) / targetCalories * 100).round();
    final fatsPercent = ((fatG * 9) / targetCalories * 100).round();

    return MacroRecommendation(
      proteinG: proteinG,
      carbsG: carbsG,
      fatsG: fatG,
      proteinPercent: proteinPercent,
      carbsPercent: carbsPercent,
      fatsPercent: fatsPercent,
    );
  }
}

class MacroRecommendation {
  const MacroRecommendation({
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatsPercent,
  });

  final int proteinG;
  final int carbsG;
  final int fatsG;
  final int proteinPercent;
  final int carbsPercent;
  final int fatsPercent;
}
