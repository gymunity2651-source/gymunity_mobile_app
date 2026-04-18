import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../member/domain/entities/member_profile_entity.dart';
import '../../../member/domain/entities/member_progress_entity.dart';
import '../../domain/entities/nutrition_entities.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../../domain/services/calorie_engine.dart';
import '../../domain/services/meal_plan_generator.dart';
import '../../domain/services/macro_engine.dart';
import '../../domain/services/nutrition_adaptation_engine.dart';
import '../../domain/services/nutrition_setup_question_factory.dart';

final nutritionProfileProvider = FutureProvider<NutritionProfileEntity?>((
  ref,
) {
  return ref.watch(nutritionRepositoryProvider).getProfile();
});

final activeNutritionTargetProvider =
    FutureProvider<NutritionTargetEntity?>((ref) {
      return ref.watch(nutritionRepositoryProvider).getActiveTarget();
    });

final activeMealPlanProvider = FutureProvider<NutritionMealPlanEntity?>((ref) {
  return ref.watch(nutritionRepositoryProvider).getActiveMealPlan();
});

final nutritionMealTemplatesProvider =
    FutureProvider<List<NutritionMealTemplateEntity>>((ref) {
      return ref.watch(nutritionRepositoryProvider).listMealTemplates();
    });

final nutritionDaySummaryProvider =
    FutureProvider.family<NutritionDaySummaryEntity, DateTime>((ref, date) {
      return ref.watch(nutritionRepositoryProvider).getDaySummary(date);
    });

final nutritionCheckinsProvider =
    FutureProvider<List<NutritionCheckinEntity>>((ref) {
      return ref.watch(nutritionRepositoryProvider).listCheckins();
    });

final calorieEngineProvider = Provider<CalorieEngine>((ref) {
  return const CalorieEngine(macroEngine: MacroEngine());
});

final mealPlanGeneratorProvider = Provider<MealPlanGenerator>((ref) {
  return const MealPlanGenerator();
});

final nutritionAdaptationEngineProvider =
    Provider<NutritionAdaptationEngine>((ref) {
      return const NutritionAdaptationEngine();
    });

final nutritionSetupQuestionFactoryProvider =
    Provider<NutritionSetupQuestionFactory>((ref) {
      return const NutritionSetupQuestionFactory();
    });

final nutritionDashboardProvider = FutureProvider<NutritionDashboardState>((
  ref,
) async {
  final nutritionRepository = ref.watch(nutritionRepositoryProvider);
  final memberRepository = ref.watch(memberRepositoryProvider);
  final memberProfile = await memberRepository.getMemberProfile();
  final nutritionProfile = await nutritionRepository.getProfile();
  final target = await nutritionRepository.getActiveTarget();
  final mealPlan = await nutritionRepository.getActiveMealPlan();
  final today = await nutritionRepository.getDaySummary(DateTime.now());
  final weights = await memberRepository.listWeightEntries();
  final sessions = await memberRepository.listWorkoutSessions();
  final plans = await memberRepository.listWorkoutPlans();
  final checkins = await nutritionRepository.listCheckins();
  final activePlan = plans
      .where((plan) => plan.status == 'active')
      .cast<dynamic>()
      .toList()
      .isEmpty
      ? null
      : plans.firstWhere((plan) => plan.status == 'active');
  final calculation = ref.read(calorieEngineProvider).calculate(
    NutritionCalculationContext(
      memberProfile: memberProfile,
      nutritionProfile: nutritionProfile,
      latestWeightKg: weights.isNotEmpty
          ? weights.last.weightKg
          : memberProfile?.currentWeightKg,
      activePlan: activePlan,
      recentSessions: sessions,
    ),
  );
  final insight = ref.read(nutritionAdaptationEngineProvider).evaluate(
    goal: memberProfile?.goal ?? target?.goalSnapshot ?? 'maintenance',
    target: target,
    weightEntries: weights,
    checkins: checkins,
    today: today,
  );
  return NutritionDashboardState(
    memberProfile: memberProfile,
    nutritionProfile: nutritionProfile,
    target: target,
    mealPlan: mealPlan,
    today: today,
    setupMissingFields: calculation.missingFields,
    insight: insight,
  );
});

class NutritionDashboardState {
  const NutritionDashboardState({
    required this.memberProfile,
    required this.nutritionProfile,
    required this.target,
    required this.mealPlan,
    required this.today,
    required this.setupMissingFields,
    required this.insight,
  });

  final MemberProfileEntity? memberProfile;
  final NutritionProfileEntity? nutritionProfile;
  final NutritionTargetEntity? target;
  final NutritionMealPlanEntity? mealPlan;
  final NutritionDaySummaryEntity today;
  final List<String> setupMissingFields;
  final NutritionInsightEntity insight;

  bool get isSetupComplete =>
      nutritionProfile != null &&
      target != null &&
      mealPlan != null &&
      setupMissingFields.isEmpty;
}
