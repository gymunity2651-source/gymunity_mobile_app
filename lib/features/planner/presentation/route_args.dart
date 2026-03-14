class AiGeneratedPlanArgs {
  const AiGeneratedPlanArgs({required this.sessionId, required this.draftId});

  final String sessionId;
  final String draftId;
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
