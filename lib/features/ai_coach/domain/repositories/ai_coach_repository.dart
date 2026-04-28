import '../entities/ai_coach_entities.dart';

abstract class AiCoachRepository {
  Future<AiDailyBriefEntity?> getDailyBrief(DateTime date);

  Future<AiDailyBriefEntity> refreshDailyBrief(DateTime date);

  Future<AiReadinessLogEntity> upsertReadiness({
    DateTime? logDate,
    int? energyLevel,
    int? sorenessLevel,
    int? stressLevel,
    int? availableMinutes,
    String? locationMode,
    List<String> equipmentOverride = const <String>[],
    String? note,
    String source = 'member',
  });

  Future<AiPlanAdaptationEntity> applyAdjustment({
    required String adjustmentType,
    DateTime? briefDate,
    String? taskId,
  });

  Future<List<AiNudgeEntity>> listNudges();

  Future<void> runAccountabilityScan();

  Future<void> maintainMemory();

  Future<ActiveWorkoutSessionEntity?> getActiveWorkoutSession(String sessionId);

  Future<ActiveWorkoutSessionEntity> startActiveWorkout({
    required String planId,
    String? dayId,
    DateTime? targetDate,
  });

  Future<void> recordActiveWorkoutEvent({
    required String sessionId,
    required String eventType,
    Map<String, dynamic> payload = const <String, dynamic>{},
  });

  Future<ActiveWorkoutSessionEntity> completeActiveWorkout({
    required String sessionId,
    int? difficultyScore,
    Map<String, dynamic> summary = const <String, dynamic>{},
  });

  Future<Map<String, dynamic>> getWorkoutPrompt({
    required String sessionId,
    String promptKind = 'mid_session',
  });

  Future<AiWeeklySummaryEntity?> getWeeklySummary(DateTime weekStart);

  Future<AiWeeklySummaryEntity> refreshWeeklySummary(DateTime weekStart);

  Future<void> shareWeeklySummary(DateTime weekStart);
}
