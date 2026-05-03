import '../../../ai_chat/domain/entities/planner_turn_result.dart';
import '../entities/planner_entities.dart';

abstract class PlannerRepository {
  Future<PlannerDraftEntity?> getLatestDraft(String sessionId);

  Future<PlannerDraftEntity?> getDraft(String draftId);

  Future<PlannerTurnResult> requestTaiyoWorkoutPlanDraft({
    required Map<String, dynamic> plannerAnswers,
    String? sessionId,
    String? draftId,
    String requestType = 'workout_plan_draft',
  });

  Future<PlanActivationResultEntity> activateDraft({
    required String draftId,
    required DateTime startDate,
    String? reminderTime,
  });

  Future<List<PlanTaskEntity>> listTodayAgenda();

  Future<List<PlanTaskEntity>> listPlanAgenda({
    String? planId,
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  Future<PlanDetailEntity?> getPlanDetail({String? planId});

  Future<PlanTaskEntity> updateTaskStatus({
    required String taskId,
    required TaskCompletionStatus status,
    int? completionPercent,
    String? note,
    int? durationMinutes,
  });

  Future<int> updateReminderTime({
    required String planId,
    required String reminderTime,
    required String timeZone,
  });

  Future<int> syncReminders({required String timeZone, int limit});
}
