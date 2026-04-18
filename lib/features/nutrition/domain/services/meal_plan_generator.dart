import '../entities/nutrition_entities.dart';

class MealPlanGenerator {
  const MealPlanGenerator();

  NutritionGeneratedPlan generate({
    required NutritionTargetEntity target,
    required NutritionProfileEntity profile,
    required List<NutritionMealTemplateEntity> templates,
    required DateTime startDate,
    bool arabic = false,
  }) {
    final mealCount = profile.mealCountPreference.clamp(3, 5);
    final distributions = _distributions(mealCount);
    final availableTemplates = templates.isEmpty ? _fallbackTemplates : templates;
    final days = <NutritionMealPlanDayEntity>[];

    for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
      final date = dateOnly(startDate.add(Duration(days: dayIndex)));
      final meals = <NutritionPlannedMealEntity>[];
      for (var mealIndex = 0; mealIndex < distributions.length; mealIndex++) {
        final distribution = distributions[mealIndex];
        final desiredCalories = (target.targetCalories * distribution.share)
            .round();
        final template = _bestTemplate(
          templates: availableTemplates,
          mealType: distribution.mealType,
          desiredCalories: desiredCalories,
          profile: profile,
          offset: dayIndex + mealIndex,
        );
        meals.add(
          NutritionPlannedMealEntity(
            id: '',
            mealPlanDayId: '',
            mealPlanId: '',
            memberId: target.memberId,
            planDate: date,
            mealType: distribution.mealType,
            scheduledTime: distribution.scheduledTime,
            templateId: template.id,
            title: template.title(arabic: arabic),
            description: template.description(arabic: arabic),
            calories: template.calories,
            proteinG: template.proteinG,
            carbsG: template.carbsG,
            fatsG: template.fatsG,
            ingredients: template.ingredientsFor(arabic: arabic),
            instructions: template.instructions(arabic: arabic),
            sortOrder: mealIndex,
          ),
        );
      }
      days.add(
        NutritionMealPlanDayEntity(
          id: '',
          mealPlanId: '',
          memberId: target.memberId,
          planDate: date,
          targetCalories: target.targetCalories,
          proteinG: target.proteinG,
          carbsG: target.carbsG,
          fatsG: target.fatsG,
          hydrationMl: target.hydrationMl,
          meals: meals,
        ),
      );
    }

    return NutritionGeneratedPlan(
      startDate: dateOnly(startDate),
      endDate: dateOnly(startDate.add(const Duration(days: 6))),
      mealCount: mealCount,
      days: days,
    );
  }

  List<_MealDistribution> _distributions(int mealCount) {
    return switch (mealCount) {
      3 => const <_MealDistribution>[
        _MealDistribution('breakfast', 0.30, '08:00'),
        _MealDistribution('lunch', 0.40, '14:00'),
        _MealDistribution('dinner', 0.30, '20:00'),
      ],
      5 => const <_MealDistribution>[
        _MealDistribution('breakfast', 0.20, '08:00'),
        _MealDistribution('lunch', 0.30, '13:30'),
        _MealDistribution('dinner', 0.25, '20:00'),
        _MealDistribution('snack', 0.10, '11:00'),
        _MealDistribution('snack', 0.15, '17:00'),
      ],
      _ => const <_MealDistribution>[
        _MealDistribution('breakfast', 0.25, '08:00'),
        _MealDistribution('lunch', 0.35, '14:00'),
        _MealDistribution('dinner', 0.30, '20:00'),
        _MealDistribution('snack', 0.10, '17:00'),
      ],
    };
  }

  NutritionMealTemplateEntity _bestTemplate({
    required List<NutritionMealTemplateEntity> templates,
    required String mealType,
    required int desiredCalories,
    required NutritionProfileEntity profile,
    required int offset,
  }) {
    final candidates =
        templates.where((template) {
          if (!template.isActive || template.mealType != mealType) {
            return false;
          }
          final allergens = template.allergenTags
              .map((item) => item.toLowerCase())
              .toSet();
          final allergies = profile.allergies
              .map((item) => item.toLowerCase())
              .toSet();
          if (allergies.any(allergens.contains)) {
            return false;
          }
          final titleAndIngredients = [
            template.titleEn,
            template.titleAr ?? '',
            ...template.ingredients,
          ].join(' ').toLowerCase();
          if (profile.foodExclusions.any(
            (item) => titleAndIngredients.contains(item.toLowerCase()),
          )) {
            return false;
          }
          if (profile.dietaryPreference == 'vegetarian' &&
              !template.dietaryTags.contains('vegetarian')) {
            return false;
          }
          if (profile.dietaryPreference == 'pescatarian' &&
              !template.dietaryTags.contains('pescatarian') &&
              !template.dietaryTags.contains('vegetarian')) {
            return false;
          }
          if (profile.dietaryPreference == 'low_carb' &&
              !template.dietaryTags.contains('low_carb') &&
              template.carbsG > 60) {
            return false;
          }
          return true;
        }).toList();
    final scored = (candidates.isEmpty
            ? templates.where((template) => template.mealType == mealType)
            : candidates)
        .map(
          (template) => MapEntry(
            template,
            _scoreTemplate(template, desiredCalories, profile, offset),
          ),
        )
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored.isEmpty ? _fallbackTemplates.first : scored.first.key;
  }

  double _scoreTemplate(
    NutritionMealTemplateEntity template,
    int desiredCalories,
    NutritionProfileEntity profile,
    int offset,
  ) {
    final calorieDistance = (template.calories - desiredCalories).abs();
    var score = 1000 - calorieDistance;
    if (profile.preferredCuisines.any(template.cuisineTags.contains)) {
      score += 90;
    }
    if (template.budgetLevel == profile.budgetLevel) {
      score += 55;
    }
    if (template.prepLevel == profile.cookingPreference) {
      score += 45;
    }
    if (template.dietaryTags.contains(profile.dietaryPreference)) {
      score += 45;
    }
    score -= offset % 4;
    return score.toDouble();
  }
}

class NutritionGeneratedPlan {
  const NutritionGeneratedPlan({
    required this.startDate,
    required this.endDate,
    required this.mealCount,
    required this.days,
  });

  final DateTime startDate;
  final DateTime endDate;
  final int mealCount;
  final List<NutritionMealPlanDayEntity> days;
}

class _MealDistribution {
  const _MealDistribution(this.mealType, this.share, this.scheduledTime);

  final String mealType;
  final double share;
  final String scheduledTime;
}

const _fallbackTemplates = <NutritionMealTemplateEntity>[
  NutritionMealTemplateEntity(
    id: 'fallback-breakfast',
    mealType: 'breakfast',
    titleEn: 'Protein breakfast plate',
    descriptionEn: 'Eggs, oats, and fruit.',
    calories: 450,
    proteinG: 30,
    carbsG: 48,
    fatsG: 14,
    dietaryTags: <String>['balanced', 'high_protein'],
    cuisineTags: <String>['international'],
    allergenTags: <String>['eggs'],
    ingredients: <String>['eggs', 'oats', 'fruit'],
    instructionsEn: 'Build a simple high-protein breakfast.',
  ),
  NutritionMealTemplateEntity(
    id: 'fallback-lunch',
    mealType: 'lunch',
    titleEn: 'Chicken rice bowl',
    descriptionEn: 'Lean protein with rice and vegetables.',
    calories: 650,
    proteinG: 45,
    carbsG: 72,
    fatsG: 17,
    dietaryTags: <String>['balanced', 'high_protein'],
    cuisineTags: <String>['international'],
    ingredients: <String>['chicken', 'rice', 'vegetables'],
    instructionsEn: 'Serve grilled protein with rice and vegetables.',
  ),
  NutritionMealTemplateEntity(
    id: 'fallback-dinner',
    mealType: 'dinner',
    titleEn: 'Light protein dinner',
    descriptionEn: 'Protein, vegetables, and a moderate carb serving.',
    calories: 520,
    proteinG: 38,
    carbsG: 42,
    fatsG: 18,
    dietaryTags: <String>['balanced', 'high_protein'],
    cuisineTags: <String>['international'],
    ingredients: <String>['protein', 'vegetables', 'potato'],
    instructionsEn: 'Keep the meal simple and easy to repeat.',
  ),
  NutritionMealTemplateEntity(
    id: 'fallback-snack',
    mealType: 'snack',
    titleEn: 'Protein snack',
    descriptionEn: 'A small snack to support adherence.',
    calories: 240,
    proteinG: 20,
    carbsG: 24,
    fatsG: 6,
    dietaryTags: <String>['balanced', 'high_protein'],
    cuisineTags: <String>['international'],
    ingredients: <String>['yogurt', 'fruit'],
    instructionsEn: 'Use as a practical snack.',
  ),
];
