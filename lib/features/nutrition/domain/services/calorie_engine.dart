import '../../../coach/domain/entities/workout_plan_entity.dart';
import '../../../member/domain/entities/member_profile_entity.dart';
import '../../../member/domain/entities/member_progress_entity.dart';
import '../entities/nutrition_entities.dart';
import 'macro_engine.dart';

class CalorieEngine {
  const CalorieEngine({this.macroEngine = const MacroEngine()});

  final MacroEngine macroEngine;

  NutritionCalculationResult calculate(NutritionCalculationContext context) {
    final missing = missingCriticalFields(context);
    if (missing.isNotEmpty) {
      return NutritionCalculationResult.missing(missing);
    }

    final profile = context.memberProfile!;
    final weightKg = context.latestWeightKg!;
    final heightCm = profile.heightCm!;
    final age = profile.age!;
    final goal = _normalizeGoal(profile.goal);
    final gender = profile.gender?.trim().toLowerCase();
    final bmr = _mifflinStJeor(
      gender: gender,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
    );
    final trainingDays = trainingDaysPerWeek(profile.trainingFrequency);
    final activityMultiplier = _activityMultiplier(
      nutritionActivityLevel: context.nutritionProfile?.activityLevel,
      trainingFrequency: profile.trainingFrequency,
      activePlan: context.activePlan,
      recentSessions: context.recentSessions,
    );
    final tdee = (bmr * activityMultiplier).round();
    final targetCalories = _targetCalories(
      goal: goal,
      tdee: tdee,
      bmr: bmr.round(),
      gender: gender,
    );
    final macros = macroEngine.calculate(
      targetCalories: targetCalories,
      weightKg: weightKg,
      goal: goal,
      trainingDaysPerWeek: trainingDays,
    );
    final hydration = _hydrationMl(weightKg, trainingDays);

    final target = NutritionTargetEntity(
      id: '',
      memberId: profile.userId,
      goalSnapshot: goal,
      bmrCalories: bmr.round(),
      tdeeCalories: tdee,
      targetCalories: targetCalories,
      proteinG: macros.proteinG,
      carbsG: macros.carbsG,
      fatsG: macros.fatsG,
      proteinPercent: macros.proteinPercent,
      carbsPercent: macros.carbsPercent,
      fatsPercent: macros.fatsPercent,
      hydrationMl: hydration,
      explanation: <String, dynamic>{
        'formula': 'Mifflin-St Jeor',
        'activity_multiplier': activityMultiplier,
        'goal_rule': _goalExplanation(goal),
        'safe_floor_applied': targetCalories > _rawGoalCalories(goal, tdee),
        'macro_rule':
            'Protein is weight and goal based; fats are kept in a healthy range; carbs use remaining calories.',
      },
      sourceContext: <String, dynamic>{
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'age': age,
        'gender': gender,
        'training_frequency': profile.trainingFrequency,
        'activity_level': context.nutritionProfile?.activityLevel,
        'recent_workout_sessions': context.recentSessions.length,
        'active_plan_id': context.activePlan?.id,
      }..removeWhere((key, value) => value == null),
    );

    return NutritionCalculationResult(target: target);
  }

  List<String> missingCriticalFields(NutritionCalculationContext context) {
    final profile = context.memberProfile;
    final missing = <String>[];
    if (profile == null) {
      return <String>['member_profile'];
    }
    if ((profile.goal ?? '').trim().isEmpty) missing.add('goal');
    if ((profile.gender ?? '').trim().isEmpty) missing.add('gender');
    if (profile.age == null || profile.age! <= 0) missing.add('age');
    if (profile.heightCm == null || profile.heightCm! <= 0) {
      missing.add('height_cm');
    }
    if (context.latestWeightKg == null || context.latestWeightKg! <= 0) {
      missing.add('weight_kg');
    }
    if ((profile.trainingFrequency ?? '').trim().isEmpty) {
      missing.add('training_frequency');
    }
    return missing;
  }

  static int trainingDaysPerWeek(String? trainingFrequency) {
    switch (trainingFrequency?.trim().toLowerCase()) {
      case '1_2_days_per_week':
      case '1-2 days/week':
        return 2;
      case '3_4_days_per_week':
      case '3-4 days/week':
        return 4;
      case '5_6_days_per_week':
      case '5-6 days/week':
        return 5;
      case 'daily':
      case 'every day':
        return 6;
      default:
        return 3;
    }
  }

  static double _mifflinStJeor({
    required String? gender,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    final base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    if (gender == 'male') {
      return base + 5;
    }
    if (gender == 'female') {
      return base - 161;
    }
    return base - 78;
  }

  static double _activityMultiplier({
    required String? nutritionActivityLevel,
    required String? trainingFrequency,
    required WorkoutPlanEntity? activePlan,
    required List<WorkoutSessionEntity> recentSessions,
  }) {
    final explicit = switch (nutritionActivityLevel?.trim().toLowerCase()) {
      'sedentary' => 1.2,
      'light' => 1.375,
      'moderate' => 1.55,
      'active' => 1.725,
      'very_active' => 1.85,
      _ => null,
    };
    var multiplier =
        explicit ??
        switch (trainingDaysPerWeek(trainingFrequency)) {
          <= 2 => 1.375,
          <= 4 => 1.55,
          <= 5 => 1.65,
          _ => 1.72,
        };
    if (activePlan != null && activePlan.status == 'active') {
      multiplier += 0.03;
    }
    if (recentSessions.length >= 4) {
      multiplier += 0.03;
    }
    return multiplier.clamp(1.2, 1.85);
  }

  static int _targetCalories({
    required String goal,
    required int tdee,
    required int bmr,
    required String? gender,
  }) {
    final raw = _rawGoalCalories(goal, tdee);
    final bounded = switch (goal) {
      'weight_loss' || 'fat_loss' => raw.clamp(tdee - 600, tdee - 300),
      'build_muscle' || 'muscle_gain' => raw.clamp(tdee + 150, tdee + 350),
      'recomposition' => raw.clamp(tdee - 200, tdee + 50),
      _ => raw,
    };
    final floor = _safeFloor(gender, bmr);
    return bounded.round().clamp(floor, 6000);
  }

  static int _rawGoalCalories(String goal, int tdee) {
    return switch (goal) {
      'weight_loss' || 'fat_loss' => (tdee * 0.85).round(),
      'build_muscle' || 'muscle_gain' => (tdee * 1.10).round(),
      'recomposition' => (tdee * 0.95).round(),
      _ => tdee,
    };
  }

  static int _safeFloor(String? gender, int bmr) {
    final genderFloor = switch (gender) {
      'male' => 1500,
      'female' => 1200,
      _ => 1350,
    };
    final bmrFloor = (bmr * 1.05).round();
    return genderFloor > bmrFloor ? genderFloor : bmrFloor;
  }

  static int _hydrationMl(double weightKg, int trainingDays) {
    final base = (weightKg * 35).round();
    final trainingBonus = trainingDays >= 5 ? 350 : trainingDays >= 3 ? 200 : 0;
    return (base + trainingBonus).clamp(1800, 4500);
  }

  static String _normalizeGoal(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'weight_loss':
      case 'lose_weight':
      case 'fat_loss':
        return 'weight_loss';
      case 'build_muscle':
      case 'muscle_gain':
      case 'strength':
        return 'build_muscle';
      case 'recomposition':
      case 'body_recomposition':
      case 'balanced':
        return 'recomposition';
      default:
        return 'maintenance';
    }
  }

  static String _goalExplanation(String goal) {
    return switch (goal) {
      'weight_loss' => 'Moderate deficit with high protein and safe floors.',
      'build_muscle' => 'Conservative surplus with high protein.',
      'recomposition' => 'Near maintenance with high protein and training support.',
      _ => 'Maintenance target based on estimated daily expenditure.',
    };
  }
}

class NutritionCalculationContext {
  const NutritionCalculationContext({
    this.memberProfile,
    this.nutritionProfile,
    this.latestWeightKg,
    this.activePlan,
    this.recentSessions = const <WorkoutSessionEntity>[],
  });

  final MemberProfileEntity? memberProfile;
  final NutritionProfileEntity? nutritionProfile;
  final double? latestWeightKg;
  final WorkoutPlanEntity? activePlan;
  final List<WorkoutSessionEntity> recentSessions;
}

class NutritionCalculationResult {
  const NutritionCalculationResult({this.target, this.missingFields = const []});

  const NutritionCalculationResult.missing(List<String> missingFields)
    : this(target: null, missingFields: missingFields);

  final NutritionTargetEntity? target;
  final List<String> missingFields;

  bool get isReady => target != null && missingFields.isEmpty;
}
