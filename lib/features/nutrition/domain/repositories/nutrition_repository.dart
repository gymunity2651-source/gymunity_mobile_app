import '../entities/nutrition_entities.dart';

abstract class NutritionRepository {
  Future<NutritionProfileEntity?> getProfile();

  Future<NutritionProfileEntity> upsertProfile(NutritionProfileEntity profile);

  Future<NutritionTargetEntity?> getActiveTarget();

  Future<NutritionTargetEntity> saveTarget(NutritionTargetEntity target);

  Future<List<NutritionMealTemplateEntity>> listMealTemplates();

  Future<NutritionMealPlanEntity?> getActiveMealPlan();

  Future<NutritionMealPlanEntity> saveGeneratedMealPlan({
    required NutritionTargetEntity target,
    required DateTime startDate,
    required int mealCount,
    required List<NutritionMealPlanDayEntity> days,
    Map<String, dynamic> generationContext = const <String, dynamic>{},
  });

  Future<NutritionDaySummaryEntity> getDaySummary(DateTime date);

  Future<void> completePlannedMeal(String plannedMealId);

  Future<void> uncompletePlannedMeal(String plannedMealId);

  Future<void> quickAddMeal({
    required DateTime date,
    required String title,
    required int calories,
    int proteinG = 0,
    int carbsG = 0,
    int fatsG = 0,
    String? note,
  });

  Future<void> addHydration({required DateTime date, required int amountMl});

  Future<NutritionPlannedMealEntity> swapPlannedMeal({
    required String plannedMealId,
    required NutritionMealTemplateEntity template,
    required bool arabic,
  });

  Future<List<NutritionCheckinEntity>> listCheckins();

  Future<NutritionCheckinEntity> saveCheckin({
    required DateTime weekStart,
    required int adherenceScore,
    int? hungerScore,
    int? energyScore,
    String? notes,
    Map<String, dynamic> suggestedAdjustment = const <String, dynamic>{},
  });
}
