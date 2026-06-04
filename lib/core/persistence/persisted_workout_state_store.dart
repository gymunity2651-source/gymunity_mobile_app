import 'app_state_keys.dart';
import 'app_state_scope.dart';
import 'local_json_store.dart';

class ActiveWorkoutLocalState {
  ActiveWorkoutLocalState({
    required this.sessionId,
    required this.planId,
    required this.dayId,
    this.currentExerciseIndex = 0,
    this.completedExerciseIds = const <String>[],
    this.restTimerRemainingSeconds,
    DateTime? updatedAt,
  }) : updatedAt = (updatedAt ?? DateTime.now()).toUtc();

  final String sessionId;
  final String planId;
  final String dayId;
  final int currentExerciseIndex;
  final List<String> completedExerciseIds;
  final int? restTimerRemainingSeconds;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': currentLocalStateSchemaVersion,
      'sessionId': sessionId,
      'planId': planId,
      'dayId': dayId,
      'currentExerciseIndex': currentExerciseIndex,
      'completedExerciseIds': completedExerciseIds,
      'restTimerRemainingSeconds': restTimerRemainingSeconds,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static ActiveWorkoutLocalState? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final sessionId = json['sessionId'] as String?;
    final planId = json['planId'] as String?;
    final dayId = json['dayId'] as String?;
    if (sessionId == null || planId == null || dayId == null) {
      return null;
    }
    final completed = json['completedExerciseIds'];
    return ActiveWorkoutLocalState(
      sessionId: sessionId,
      planId: planId,
      dayId: dayId,
      currentExerciseIndex: json['currentExerciseIndex'] is int
          ? json['currentExerciseIndex'] as int
          : 0,
      completedExerciseIds: completed is List
          ? completed.whereType<String>().toList(growable: false)
          : const <String>[],
      restTimerRemainingSeconds: json['restTimerRemainingSeconds'] is int
          ? json['restTimerRemainingSeconds'] as int
          : null,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class PersistedWorkoutStateStore {
  PersistedWorkoutStateStore(this._store);

  final LocalJsonStore _store;

  Future<void> saveActiveWorkoutState(
    String userId,
    ActiveWorkoutLocalState state,
  ) {
    return _store.writeMap(_key(userId), state.toJson());
  }

  Future<ActiveWorkoutLocalState?> readActiveWorkoutState(String userId) {
    return _store.readMap(_key(userId)).then(ActiveWorkoutLocalState.fromJson);
  }

  Future<ActiveWorkoutLocalState?> restoreActiveWorkoutState(
    String userId, {
    required Future<bool> Function(ActiveWorkoutLocalState state) isStillActive,
  }) async {
    final state = await readActiveWorkoutState(userId);
    if (state == null) {
      return null;
    }
    if (!await isStillActive(state)) {
      await clearActiveWorkoutState(userId);
      return null;
    }
    return state;
  }

  Future<void> clearActiveWorkoutState(String userId) {
    return _store.remove(_key(userId));
  }

  static String _key(String userId) {
    return AppStateScope.userKey(AppStateKeys.workoutsPrefix, userId, <String>[
      'active',
    ]);
  }
}
