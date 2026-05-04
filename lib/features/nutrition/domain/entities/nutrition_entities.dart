class NutritionProfileEntity {
  const NutritionProfileEntity({
    required this.memberId,
    this.activityLevel,
    this.dietaryPreference = 'balanced',
    this.mealCountPreference = 4,
    this.allergies = const <String>[],
    this.foodExclusions = const <String>[],
    this.preferredCuisines = const <String>['egyptian', 'international'],
    this.budgetLevel = 'balanced',
    this.cookingPreference = 'simple',
    this.wakeTime,
    this.sleepTime,
    this.workoutTiming,
    this.hydrationPreference = 'standard',
    this.createdAt,
    this.updatedAt,
  });

  final String memberId;
  final String? activityLevel;
  final String dietaryPreference;
  final int mealCountPreference;
  final List<String> allergies;
  final List<String> foodExclusions;
  final List<String> preferredCuisines;
  final String budgetLevel;
  final String cookingPreference;
  final String? wakeTime;
  final String? sleepTime;
  final String? workoutTiming;
  final String hydrationPreference;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NutritionProfileEntity copyWith({
    String? memberId,
    String? activityLevel,
    String? dietaryPreference,
    int? mealCountPreference,
    List<String>? allergies,
    List<String>? foodExclusions,
    List<String>? preferredCuisines,
    String? budgetLevel,
    String? cookingPreference,
    String? wakeTime,
    String? sleepTime,
    String? workoutTiming,
    String? hydrationPreference,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NutritionProfileEntity(
      memberId: memberId ?? this.memberId,
      activityLevel: activityLevel ?? this.activityLevel,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      mealCountPreference: mealCountPreference ?? this.mealCountPreference,
      allergies: allergies ?? this.allergies,
      foodExclusions: foodExclusions ?? this.foodExclusions,
      preferredCuisines: preferredCuisines ?? this.preferredCuisines,
      budgetLevel: budgetLevel ?? this.budgetLevel,
      cookingPreference: cookingPreference ?? this.cookingPreference,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
      workoutTiming: workoutTiming ?? this.workoutTiming,
      hydrationPreference: hydrationPreference ?? this.hydrationPreference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory NutritionProfileEntity.fromMap(Map<String, dynamic> map) {
    return NutritionProfileEntity(
      memberId: map['member_id'] as String? ?? '',
      activityLevel: map['activity_level'] as String?,
      dietaryPreference: map['dietary_preference'] as String? ?? 'balanced',
      mealCountPreference:
          (map['meal_count_preference'] as num?)?.toInt() ?? 4,
      allergies: _stringList(map['allergies']),
      foodExclusions: _stringList(map['food_exclusions']),
      preferredCuisines: _stringList(map['preferred_cuisines']).isEmpty
          ? const <String>['egyptian', 'international']
          : _stringList(map['preferred_cuisines']),
      budgetLevel: map['budget_level'] as String? ?? 'balanced',
      cookingPreference: map['cooking_preference'] as String? ?? 'simple',
      wakeTime: map['wake_time'] as String?,
      sleepTime: map['sleep_time'] as String?,
      workoutTiming: map['workout_timing'] as String?,
      hydrationPreference:
          map['hydration_preference'] as String? ?? 'standard',
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return <String, dynamic>{
      'member_id': memberId,
      'activity_level': activityLevel,
      'dietary_preference': dietaryPreference,
      'meal_count_preference': mealCountPreference,
      'allergies': allergies,
      'food_exclusions': foodExclusions,
      'preferred_cuisines': preferredCuisines,
      'budget_level': budgetLevel,
      'cooking_preference': cookingPreference,
      'wake_time': wakeTime,
      'sleep_time': sleepTime,
      'workout_timing': workoutTiming,
      'hydration_preference': hydrationPreference,
    }..removeWhere((key, value) => value == null);
  }
}

class NutritionTargetEntity {
  const NutritionTargetEntity({
    required this.id,
    required this.memberId,
    required this.goalSnapshot,
    required this.bmrCalories,
    required this.tdeeCalories,
    required this.targetCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatsPercent,
    required this.hydrationMl,
    this.formulaVersion = 'gymunity_msj_v1',
    this.explanation = const <String, dynamic>{},
    this.sourceContext = const <String, dynamic>{},
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String memberId;
  final String formulaVersion;
  final String goalSnapshot;
  final int bmrCalories;
  final int tdeeCalories;
  final int targetCalories;
  final int proteinG;
  final int carbsG;
  final int fatsG;
  final int proteinPercent;
  final int carbsPercent;
  final int fatsPercent;
  final int hydrationMl;
  final Map<String, dynamic> explanation;
  final Map<String, dynamic> sourceContext;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NutritionTargetEntity.fromMap(Map<String, dynamic> map) {
    return NutritionTargetEntity(
      id: map['id'] as String? ?? '',
      memberId: map['member_id'] as String? ?? '',
      formulaVersion: map['formula_version'] as String? ?? 'gymunity_msj_v1',
      goalSnapshot: map['goal_snapshot'] as String? ?? 'maintenance',
      bmrCalories: (map['bmr_calories'] as num?)?.toInt() ?? 0,
      tdeeCalories: (map['tdee_calories'] as num?)?.toInt() ?? 0,
      targetCalories: (map['target_calories'] as num?)?.toInt() ?? 0,
      proteinG: (map['protein_g'] as num?)?.toInt() ?? 0,
      carbsG: (map['carbs_g'] as num?)?.toInt() ?? 0,
      fatsG: (map['fats_g'] as num?)?.toInt() ?? 0,
      proteinPercent: (map['protein_percent'] as num?)?.toInt() ?? 0,
      carbsPercent: (map['carbs_percent'] as num?)?.toInt() ?? 0,
      fatsPercent: (map['fats_percent'] as num?)?.toInt() ?? 0,
      hydrationMl: (map['hydration_ml'] as num?)?.toInt() ?? 0,
      explanation: _jsonMap(map['explanation_json']),
      sourceContext: _jsonMap(map['source_context_json']),
      status: map['status'] as String? ?? 'active',
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toInsertMap({String? memberIdOverride}) {
    return <String, dynamic>{
      'member_id': memberIdOverride ?? memberId,
      'formula_version': formulaVersion,
      'goal_snapshot': goalSnapshot,
      'bmr_calories': bmrCalories,
      'tdee_calories': tdeeCalories,
      'target_calories': targetCalories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fats_g': fatsG,
      'protein_percent': proteinPercent,
      'carbs_percent': carbsPercent,
      'fats_percent': fatsPercent,
      'hydration_ml': hydrationMl,
      'explanation_json': explanation,
      'source_context_json': sourceContext,
      'status': status,
    };
  }

  NutritionTargetEntity adjusted({
    required String id,
    required int targetCalories,
    required String reason,
  }) {
    final macroCalories = targetCalories.toDouble();
    final protein = proteinG;
    final fats = fatsG;
    final remaining = macroCalories - (protein * 4) - (fats * 9);
    final carbs = (remaining / 4).round().clamp(0, 600);
    return NutritionTargetEntity(
      id: id,
      memberId: memberId,
      formulaVersion: formulaVersion,
      goalSnapshot: goalSnapshot,
      bmrCalories: bmrCalories,
      tdeeCalories: tdeeCalories,
      targetCalories: targetCalories,
      proteinG: protein,
      carbsG: carbs,
      fatsG: fats,
      proteinPercent: ((protein * 4) / targetCalories * 100).round(),
      carbsPercent: ((carbs * 4) / targetCalories * 100).round(),
      fatsPercent: ((fats * 9) / targetCalories * 100).round(),
      hydrationMl: hydrationMl,
      explanation: <String, dynamic>{
        ...explanation,
        'adjustment_reason': reason,
      },
      sourceContext: sourceContext,
    );
  }
}

class NutritionMealTemplateEntity {
  const NutritionMealTemplateEntity({
    required this.id,
    required this.mealType,
    required this.titleEn,
    required this.descriptionEn,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    this.ownerUserId,
    this.titleAr,
    this.descriptionAr = '',
    this.cuisineTags = const <String>[],
    this.dietaryTags = const <String>[],
    this.allergenTags = const <String>[],
    this.budgetLevel = 'balanced',
    this.prepLevel = 'simple',
    this.ingredients = const <String>[],
    this.ingredientsAr = const <String>[],
    this.instructionsEn = '',
    this.instructionsAr = '',
    this.isActive = true,
  });

  final String id;
  final String? ownerUserId;
  final String mealType;
  final String titleEn;
  final String? titleAr;
  final String descriptionEn;
  final String descriptionAr;
  final List<String> cuisineTags;
  final List<String> dietaryTags;
  final List<String> allergenTags;
  final String budgetLevel;
  final String prepLevel;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatsG;
  final List<String> ingredients;
  final List<String> ingredientsAr;
  final String instructionsEn;
  final String instructionsAr;
  final bool isActive;

  String title({required bool arabic}) {
    if (arabic && (titleAr ?? '').trim().isNotEmpty) {
      return titleAr!.trim();
    }
    return titleEn;
  }

  String description({required bool arabic}) {
    if (arabic && descriptionAr.trim().isNotEmpty) {
      return descriptionAr.trim();
    }
    return descriptionEn;
  }

  List<String> ingredientsFor({required bool arabic}) {
    if (arabic && ingredientsAr.isNotEmpty) {
      return ingredientsAr;
    }
    return ingredients;
  }

  String instructions({required bool arabic}) {
    if (arabic && instructionsAr.trim().isNotEmpty) {
      return instructionsAr.trim();
    }
    return instructionsEn;
  }

  factory NutritionMealTemplateEntity.fromMap(Map<String, dynamic> map) {
    return NutritionMealTemplateEntity(
      id: map['id'] as String? ?? '',
      ownerUserId: map['owner_user_id'] as String?,
      mealType: map['meal_type'] as String? ?? 'snack',
      titleEn: map['title_en'] as String? ?? '',
      titleAr: map['title_ar'] as String?,
      descriptionEn: map['description_en'] as String? ?? '',
      descriptionAr: map['description_ar'] as String? ?? '',
      cuisineTags: _stringList(map['cuisine_tags']),
      dietaryTags: _stringList(map['dietary_tags']),
      allergenTags: _stringList(map['allergen_tags']),
      budgetLevel: map['budget_level'] as String? ?? 'balanced',
      prepLevel: map['prep_level'] as String? ?? 'simple',
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      proteinG: (map['protein_g'] as num?)?.toInt() ?? 0,
      carbsG: (map['carbs_g'] as num?)?.toInt() ?? 0,
      fatsG: (map['fats_g'] as num?)?.toInt() ?? 0,
      ingredients: _stringList(map['ingredients_json']),
      ingredientsAr: _stringList(map['ingredients_ar_json']),
      instructionsEn: map['instructions_en'] as String? ?? '',
      instructionsAr: map['instructions_ar'] as String? ?? '',
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class NutritionMealPlanEntity {
  const NutritionMealPlanEntity({
    required this.id,
    required this.memberId,
    required this.targetId,
    required this.startDate,
    required this.endDate,
    required this.mealCount,
    this.status = 'active',
    this.days = const <NutritionMealPlanDayEntity>[],
    this.generationContext = const <String, dynamic>{},
  });

  final String id;
  final String memberId;
  final String targetId;
  final DateTime startDate;
  final DateTime endDate;
  final int mealCount;
  final String status;
  final List<NutritionMealPlanDayEntity> days;
  final Map<String, dynamic> generationContext;

  factory NutritionMealPlanEntity.fromMap(
    Map<String, dynamic> map, {
    List<NutritionMealPlanDayEntity> days = const <NutritionMealPlanDayEntity>[],
  }) {
    return NutritionMealPlanEntity(
      id: map['id'] as String? ?? '',
      memberId: map['member_id'] as String? ?? '',
      targetId: map['target_id'] as String? ?? '',
      startDate: _parseDateOnly(map['start_date']) ?? DateTime.now(),
      endDate: _parseDateOnly(map['end_date']) ?? DateTime.now(),
      mealCount: (map['meal_count'] as num?)?.toInt() ?? 4,
      status: map['status'] as String? ?? 'active',
      generationContext: _jsonMap(map['generation_context_json']),
      days: days,
    );
  }
}

class NutritionMealPlanDayEntity {
  const NutritionMealPlanDayEntity({
    required this.id,
    required this.mealPlanId,
    required this.memberId,
    required this.planDate,
    required this.targetCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    required this.hydrationMl,
    this.meals = const <NutritionPlannedMealEntity>[],
  });

  final String id;
  final String mealPlanId;
  final String memberId;
  final DateTime planDate;
  final int targetCalories;
  final int proteinG;
  final int carbsG;
  final int fatsG;
  final int hydrationMl;
  final List<NutritionPlannedMealEntity> meals;

  factory NutritionMealPlanDayEntity.fromMap(
    Map<String, dynamic> map, {
    List<NutritionPlannedMealEntity> meals =
        const <NutritionPlannedMealEntity>[],
  }) {
    return NutritionMealPlanDayEntity(
      id: map['id'] as String? ?? '',
      mealPlanId: map['meal_plan_id'] as String? ?? '',
      memberId: map['member_id'] as String? ?? '',
      planDate: _parseDateOnly(map['plan_date']) ?? DateTime.now(),
      targetCalories: (map['target_calories'] as num?)?.toInt() ?? 0,
      proteinG: (map['protein_g'] as num?)?.toInt() ?? 0,
      carbsG: (map['carbs_g'] as num?)?.toInt() ?? 0,
      fatsG: (map['fats_g'] as num?)?.toInt() ?? 0,
      hydrationMl: (map['hydration_ml'] as num?)?.toInt() ?? 0,
      meals: meals,
    );
  }
}

class NutritionPlannedMealEntity {
  const NutritionPlannedMealEntity({
    required this.id,
    required this.mealPlanDayId,
    required this.mealPlanId,
    required this.memberId,
    required this.planDate,
    required this.mealType,
    required this.title,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    this.scheduledTime,
    this.templateId,
    this.description = '',
    this.ingredients = const <String>[],
    this.instructions = '',
    this.sortOrder = 0,
    this.completedAt,
  });

  final String id;
  final String mealPlanDayId;
  final String mealPlanId;
  final String memberId;
  final DateTime planDate;
  final String mealType;
  final String? scheduledTime;
  final String? templateId;
  final String title;
  final String description;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatsG;
  final List<String> ingredients;
  final String instructions;
  final int sortOrder;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  factory NutritionPlannedMealEntity.fromMap(Map<String, dynamic> map) {
    return NutritionPlannedMealEntity(
      id: map['id'] as String? ?? '',
      mealPlanDayId: map['meal_plan_day_id'] as String? ?? '',
      mealPlanId: map['meal_plan_id'] as String? ?? '',
      memberId: map['member_id'] as String? ?? '',
      planDate: _parseDateOnly(map['plan_date']) ?? DateTime.now(),
      mealType: map['meal_type'] as String? ?? 'snack',
      scheduledTime: map['scheduled_time'] as String?,
      templateId: map['template_id'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      proteinG: (map['protein_g'] as num?)?.toInt() ?? 0,
      carbsG: (map['carbs_g'] as num?)?.toInt() ?? 0,
      fatsG: (map['fats_g'] as num?)?.toInt() ?? 0,
      ingredients: _stringList(map['ingredients_json']),
      instructions: map['instructions'] as String? ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      completedAt: _parseDateTime(map['completed_at']),
    );
  }
}

class MealLogEntity {
  const MealLogEntity({
    required this.id,
    required this.memberId,
    required this.logDate,
    required this.source,
    required this.title,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
    required this.completedAt,
    this.plannedMealId,
    this.note,
  });

  final String id;
  final String memberId;
  final String? plannedMealId;
  final DateTime logDate;
  final String source;
  final String title;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatsG;
  final DateTime completedAt;
  final String? note;

  factory MealLogEntity.fromMap(Map<String, dynamic> map) {
    return MealLogEntity(
      id: map['id'] as String? ?? '',
      memberId: map['member_id'] as String? ?? '',
      plannedMealId: map['planned_meal_id'] as String?,
      logDate: _parseDateOnly(map['log_date']) ?? DateTime.now(),
      source: map['source'] as String? ?? 'planned',
      title: map['title'] as String? ?? '',
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      proteinG: (map['protein_g'] as num?)?.toInt() ?? 0,
      carbsG: (map['carbs_g'] as num?)?.toInt() ?? 0,
      fatsG: (map['fats_g'] as num?)?.toInt() ?? 0,
      completedAt: _parseDateTime(map['completed_at']) ?? DateTime.now(),
      note: map['note'] as String?,
    );
  }
}

class HydrationLogEntity {
  const HydrationLogEntity({
    required this.id,
    required this.memberId,
    required this.logDate,
    required this.amountMl,
    required this.loggedAt,
  });

  final String id;
  final String memberId;
  final DateTime logDate;
  final int amountMl;
  final DateTime loggedAt;

  factory HydrationLogEntity.fromMap(Map<String, dynamic> map) {
    return HydrationLogEntity(
      id: map['id'] as String? ?? '',
      memberId: map['member_id'] as String? ?? '',
      logDate: _parseDateOnly(map['log_date']) ?? DateTime.now(),
      amountMl: (map['amount_ml'] as num?)?.toInt() ?? 0,
      loggedAt: _parseDateTime(map['logged_at']) ?? DateTime.now(),
    );
  }
}

class NutritionCheckinEntity {
  const NutritionCheckinEntity({
    required this.id,
    required this.memberId,
    required this.weekStart,
    required this.adherenceScore,
    this.hungerScore,
    this.energyScore,
    this.notes,
    this.suggestedAdjustment = const <String, dynamic>{},
  });

  final String id;
  final String memberId;
  final DateTime weekStart;
  final int adherenceScore;
  final int? hungerScore;
  final int? energyScore;
  final String? notes;
  final Map<String, dynamic> suggestedAdjustment;

  factory NutritionCheckinEntity.fromMap(Map<String, dynamic> map) {
    return NutritionCheckinEntity(
      id: map['id'] as String? ?? '',
      memberId: map['member_id'] as String? ?? '',
      weekStart: _parseDateOnly(map['week_start']) ?? DateTime.now(),
      adherenceScore: (map['adherence_score'] as num?)?.toInt() ?? 0,
      hungerScore: (map['hunger_score'] as num?)?.toInt(),
      energyScore: (map['energy_score'] as num?)?.toInt(),
      notes: map['notes'] as String?,
      suggestedAdjustment: _jsonMap(map['suggested_adjustment_json']),
    );
  }
}

class NutritionDaySummaryEntity {
  const NutritionDaySummaryEntity({
    required this.date,
    this.target,
    this.day,
    this.logs = const <MealLogEntity>[],
    this.hydrationLogs = const <HydrationLogEntity>[],
  });

  final DateTime date;
  final NutritionTargetEntity? target;
  final NutritionMealPlanDayEntity? day;
  final List<MealLogEntity> logs;
  final List<HydrationLogEntity> hydrationLogs;

  List<NutritionPlannedMealEntity> get plannedMeals =>
      day?.meals ?? const <NutritionPlannedMealEntity>[];

  int get caloriesConsumed => logs.fold(0, (sum, log) => sum + log.calories);
  int get proteinConsumed => logs.fold(0, (sum, log) => sum + log.proteinG);
  int get carbsConsumed => logs.fold(0, (sum, log) => sum + log.carbsG);
  int get fatsConsumed => logs.fold(0, (sum, log) => sum + log.fatsG);
  int get hydrationConsumed =>
      hydrationLogs.fold(0, (sum, log) => sum + log.amountMl);

  int get mealsCompleted =>
      plannedMeals.where((meal) => meal.isCompleted).length;

  double get calorieProgress {
    final targetCalories = day?.targetCalories ?? target?.targetCalories ?? 0;
    if (targetCalories <= 0) return 0;
    return (caloriesConsumed / targetCalories).clamp(0, 1.4);
  }

  double get hydrationProgress {
    final targetHydration = day?.hydrationMl ?? target?.hydrationMl ?? 0;
    if (targetHydration <= 0) return 0;
    return (hydrationConsumed / targetHydration).clamp(0, 1.4);
  }
}

class NutritionInsightEntity {
  const NutritionInsightEntity({
    required this.title,
    required this.message,
    this.calorieAdjustment,
    this.severity = 'info',
  });

  final String title;
  final String message;
  final int? calorieAdjustment;
  final String severity;

  bool get hasAdjustment => calorieAdjustment != null && calorieAdjustment != 0;
}

class NutritionGuidanceEntity {
  const NutritionGuidanceEntity({
    required this.nutritionStatus,
    required this.calorieGuidance,
    required this.proteinFocus,
    required this.hydrationFocus,
    required this.mealSuggestion,
    required this.warning,
    this.confidence = 'medium',
  });

  final String nutritionStatus;
  final String calorieGuidance;
  final String proteinFocus;
  final String hydrationFocus;
  final String mealSuggestion;
  final String warning;
  final String confidence;

  factory NutritionGuidanceEntity.fromResponse(dynamic response) {
    final map = _jsonMap(response);
    final result = _jsonMap(map['result']);
    return NutritionGuidanceEntity(
      nutritionStatus:
          result['nutrition_status'] as String? ?? 'needs_context',
      calorieGuidance:
          result['calorie_guidance'] as String? ??
          'Keep intake close to your active target.',
      proteinFocus:
          result['protein_focus'] as String? ??
          'Prioritize a protein-forward meal.',
      hydrationFocus:
          result['hydration_focus'] as String? ??
          'Keep water intake steady.',
      mealSuggestion:
          result['meal_suggestion'] as String? ??
          'Choose a simple balanced meal.',
      warning:
          result['warning'] as String? ??
          'General fitness nutrition guidance only, not medical advice.',
      confidence: _confidence(
        result['confidence'] ?? _jsonMap(map['data_quality'])['confidence'],
      ),
    );
  }
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String dateWire(DateTime date) {
  final normalized = dateOnly(date);
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}

String _confidence(dynamic value) {
  final text = value?.toString().trim().toLowerCase();
  return text == 'low' || text == 'medium' || text == 'high'
      ? text!
      : 'medium';
}

DateTime? _parseDateOnly(dynamic value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  return dateOnly(parsed);
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

List<String> _stringList(dynamic value) {
  if (value is List<String>) {
    return value.where((item) => item.trim().isNotEmpty).toList();
  }
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    return <String>[value.trim()];
  }
  return const <String>[];
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}
