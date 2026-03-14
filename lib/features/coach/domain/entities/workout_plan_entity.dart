class WorkoutPlanEntity {
  const WorkoutPlanEntity({
    required this.id,
    required this.memberId,
    this.coachId,
    required this.source,
    required this.title,
    required this.status,
    this.planJson = const <String, dynamic>{},
    this.startDate,
    this.endDate,
    this.assignedAt,
    this.updatedAt,
    this.completedAt,
    this.conversationSessionId,
    this.generatedFromDraftId,
    this.planVersion = 1,
    this.defaultReminderTime,
  });

  final String id;
  final String memberId;
  final String? coachId;
  final String source;
  final String title;
  final String status;
  final Map<String, dynamic> planJson;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? assignedAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String? conversationSessionId;
  final String? generatedFromDraftId;
  final int planVersion;
  final String? defaultReminderTime;
}
