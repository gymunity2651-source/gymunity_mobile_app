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
