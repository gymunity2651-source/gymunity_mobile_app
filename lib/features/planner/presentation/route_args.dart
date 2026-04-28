class AiGeneratedPlanArgs {
  const AiGeneratedPlanArgs({required this.sessionId, required this.draftId});

  final String sessionId;
  final String draftId;
}

class PlannerBuilderArgs {
  const PlannerBuilderArgs({this.seedPrompt, this.existingSessionId});

  final String? seedPrompt;
  final String? existingSessionId;
}

class WorkoutPlanArgs {
  const WorkoutPlanArgs({this.planId});

  final String? planId;
}

class WorkoutDayArgs {
  const WorkoutDayArgs({required this.planId, required this.dayId});

  final String planId;
  final String dayId;
}

class ActiveWorkoutSessionArgs {
  const ActiveWorkoutSessionArgs({this.sessionId, this.planId, this.dayId});

  final String? sessionId;
  final String? planId;
  final String? dayId;
}

class NutritionRouteArgs {
  const NutritionRouteArgs({this.initialHydrationAmountMl});

  final int? initialHydrationAmountMl;
}

class MealPlanRouteArgs {
  const MealPlanRouteArgs({this.openQuickAddOnLaunch = false});

  final bool openQuickAddOnLaunch;
}
