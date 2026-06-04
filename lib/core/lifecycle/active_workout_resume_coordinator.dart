import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai_coach/domain/entities/ai_coach_entities.dart';
import '../../features/ai_coach/presentation/providers/ai_coach_providers.dart';
import '../di/providers.dart';
import '../persistence/persisted_workout_state_store.dart';

class ActiveWorkoutResumeState {
  const ActiveWorkoutResumeState({this.localState});

  final ActiveWorkoutLocalState? localState;

  bool get hasResumableWorkout => localState != null;
}

final activeWorkoutResumeStateProvider =
    StateProvider<ActiveWorkoutResumeState>(
      (ref) => const ActiveWorkoutResumeState(),
    );

class ActiveWorkoutResumeCoordinator {
  ActiveWorkoutResumeCoordinator(this._ref);

  final Ref _ref;

  Future<void> checkForResumableWorkout(String userId) async {
    final service = _ref.read(appStatePersistenceServiceProvider).valueOrNull;
    if (service == null) {
      return;
    }
    final localState = await service.workouts.readActiveWorkoutState(userId);
    if (localState == null) {
      _ref.read(activeWorkoutResumeStateProvider.notifier).state =
          const ActiveWorkoutResumeState();
      return;
    }

    final ActiveWorkoutSessionEntity? session;
    try {
      session = await _ref
          .read(aiCoachRepositoryProvider)
          .getActiveWorkoutSession(localState.sessionId);
    } catch (_) {
      return;
    }

    if (session == null ||
        session.status != 'active' ||
        session.endedAt != null) {
      await service.workouts.clearActiveWorkoutState(userId);
      _ref.read(activeWorkoutResumeStateProvider.notifier).state =
          const ActiveWorkoutResumeState();
      return;
    }

    _ref.read(activeWorkoutResumeStateProvider.notifier).state =
        ActiveWorkoutResumeState(localState: localState);
    _ref.invalidate(activeWorkoutSessionProvider(localState.sessionId));
  }
}
