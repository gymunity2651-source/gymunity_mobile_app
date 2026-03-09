class WorkoutPlanEntity {
  const WorkoutPlanEntity({
    required this.id,
    required this.memberId,
    this.coachId,
    required this.source,
    required this.title,
    required this.status,
  });

  final String id;
  final String memberId;
  final String? coachId;
  final String source;
  final String title;
  final String status;
}

