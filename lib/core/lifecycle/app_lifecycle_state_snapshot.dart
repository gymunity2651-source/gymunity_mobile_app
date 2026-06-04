class AppLifecycleStateSnapshot {
  const AppLifecycleStateSnapshot({
    required this.userId,
    required this.routeName,
    this.tabArea,
    this.tabIndex,
    this.activeWorkoutSessionId,
    this.aiSessionId,
    this.savedAt,
  });

  final String userId;
  final String routeName;
  final String? tabArea;
  final int? tabIndex;
  final String? activeWorkoutSessionId;
  final String? aiSessionId;
  final DateTime? savedAt;
}
