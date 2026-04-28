import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/supabase/supabase_initializer.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../planner/domain/entities/planner_entities.dart';
import '../../../planner/presentation/providers/planner_providers.dart';
import '../../domain/entities/ai_coach_entities.dart';

class AiCoachReadinessState {
  const AiCoachReadinessState({
    this.isSubmitting = false,
    this.errorMessage,
    this.lastLog,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final AiReadinessLogEntity? lastLog;

  AiCoachReadinessState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    AiReadinessLogEntity? lastLog,
    bool clearError = false,
  }) {
    return AiCoachReadinessState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastLog: lastLog ?? this.lastLog,
    );
  }
}

class AiCoachReadinessController extends StateNotifier<AiCoachReadinessState> {
  AiCoachReadinessController(this._ref) : super(const AiCoachReadinessState());

  final Ref _ref;

  Future<AiReadinessLogEntity?> submit({
    DateTime? logDate,
    int? energyLevel,
    int? sorenessLevel,
    int? stressLevel,
    int? availableMinutes,
    String? locationMode,
    List<String> equipmentOverride = const <String>[],
    String? note,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final log = await _ref
          .read(aiCoachRepositoryProvider)
          .upsertReadiness(
            logDate: _dateOnly(logDate ?? DateTime.now()),
            energyLevel: energyLevel,
            sorenessLevel: sorenessLevel,
            stressLevel: stressLevel,
            availableMinutes: availableMinutes,
            locationMode: locationMode,
            equipmentOverride: equipmentOverride,
            note: note,
          );
      _ref.invalidate(aiCoachDailyBriefProvider(_dateOnly(log.logDate)));
      _ref.invalidate(aiCoachNudgesProvider);
      state = state.copyWith(
        isSubmitting: false,
        clearError: true,
        lastLog: log,
      );
      return log;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
      );
      return null;
    }
  }
}

class AiCoachActionState {
  const AiCoachActionState({
    this.isApplying = false,
    this.isStartingWorkout = false,
    this.isSharingWeeklySummary = false,
    this.errorMessage,
    this.lastAdaptation,
    this.lastSessionId,
  });

  final bool isApplying;
  final bool isStartingWorkout;
  final bool isSharingWeeklySummary;
  final String? errorMessage;
  final AiPlanAdaptationEntity? lastAdaptation;
  final String? lastSessionId;

  AiCoachActionState copyWith({
    bool? isApplying,
    bool? isStartingWorkout,
    bool? isSharingWeeklySummary,
    String? errorMessage,
    AiPlanAdaptationEntity? lastAdaptation,
    String? lastSessionId,
    bool clearError = false,
  }) {
    return AiCoachActionState(
      isApplying: isApplying ?? this.isApplying,
      isStartingWorkout: isStartingWorkout ?? this.isStartingWorkout,
      isSharingWeeklySummary:
          isSharingWeeklySummary ?? this.isSharingWeeklySummary,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastAdaptation: lastAdaptation ?? this.lastAdaptation,
      lastSessionId: lastSessionId ?? this.lastSessionId,
    );
  }
}

class AiCoachActionController extends StateNotifier<AiCoachActionState> {
  AiCoachActionController(this._ref) : super(const AiCoachActionState());

  final Ref _ref;

  Future<AiPlanAdaptationEntity?> applyAdjustment({
    required String adjustmentType,
    DateTime? briefDate,
    String? taskId,
  }) async {
    state = state.copyWith(isApplying: true, clearError: true);
    try {
      final adaptation = await _ref
          .read(aiCoachRepositoryProvider)
          .applyAdjustment(
            adjustmentType: adjustmentType,
            briefDate: _dateOnly(briefDate ?? DateTime.now()),
            taskId: taskId,
          );
      final today = _dateOnly(briefDate ?? DateTime.now());
      _ref.invalidate(aiCoachDailyBriefProvider(today));
      _ref.invalidate(aiCoachNudgesProvider);
      _ref.invalidate(planDetailProvider(null));
      _ref.invalidate(todayAgendaProvider);
      state = state.copyWith(
        isApplying: false,
        clearError: true,
        lastAdaptation: adaptation,
      );
      return adaptation;
    } catch (error) {
      state = state.copyWith(isApplying: false, errorMessage: error.toString());
      return null;
    }
  }

  Future<String?> startWorkout({
    required String planId,
    String? dayId,
    DateTime? targetDate,
  }) async {
    state = state.copyWith(isStartingWorkout: true, clearError: true);
    try {
      final session = await _ref
          .read(aiCoachRepositoryProvider)
          .startActiveWorkout(
            planId: planId,
            dayId: dayId,
            targetDate: _dateOnly(targetDate ?? DateTime.now()),
          );
      _ref.invalidate(activeWorkoutSessionProvider(session.id));
      state = state.copyWith(
        isStartingWorkout: false,
        clearError: true,
        lastSessionId: session.id,
      );
      return session.id;
    } catch (error) {
      state = state.copyWith(
        isStartingWorkout: false,
        errorMessage: error.toString(),
      );
      return null;
    }
  }

  Future<bool> shareWeeklySummary(DateTime weekStart) async {
    state = state.copyWith(isSharingWeeklySummary: true, clearError: true);
    try {
      await _ref
          .read(aiCoachRepositoryProvider)
          .shareWeeklySummary(_startOfWeek(weekStart));
      _ref.invalidate(aiWeeklySummaryProvider(_startOfWeek(weekStart)));
      state = state.copyWith(isSharingWeeklySummary: false, clearError: true);
      return true;
    } catch (error) {
      state = state.copyWith(
        isSharingWeeklySummary: false,
        errorMessage: error.toString(),
      );
      return false;
    }
  }
}

class ActiveWorkoutCompanionState {
  const ActiveWorkoutCompanionState({
    this.sessionId,
    this.isLoading = false,
    this.isCompleting = false,
    this.errorMessage,
    this.completedTaskIds = const <String>{},
    this.partialTaskIds = const <String>{},
    this.skippedTaskIds = const <String>{},
    this.wasShortened = false,
    this.wasSwapped = false,
    this.latestPrompt = const <String, dynamic>{},
  });

  final String? sessionId;
  final bool isLoading;
  final bool isCompleting;
  final String? errorMessage;
  final Set<String> completedTaskIds;
  final Set<String> partialTaskIds;
  final Set<String> skippedTaskIds;
  final bool wasShortened;
  final bool wasSwapped;
  final Map<String, dynamic> latestPrompt;

  ActiveWorkoutCompanionState copyWith({
    String? sessionId,
    bool? isLoading,
    bool? isCompleting,
    String? errorMessage,
    Set<String>? completedTaskIds,
    Set<String>? partialTaskIds,
    Set<String>? skippedTaskIds,
    bool? wasShortened,
    bool? wasSwapped,
    Map<String, dynamic>? latestPrompt,
    bool clearError = false,
  }) {
    return ActiveWorkoutCompanionState(
      sessionId: sessionId ?? this.sessionId,
      isLoading: isLoading ?? this.isLoading,
      isCompleting: isCompleting ?? this.isCompleting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
      partialTaskIds: partialTaskIds ?? this.partialTaskIds,
      skippedTaskIds: skippedTaskIds ?? this.skippedTaskIds,
      wasShortened: wasShortened ?? this.wasShortened,
      wasSwapped: wasSwapped ?? this.wasSwapped,
      latestPrompt: latestPrompt ?? this.latestPrompt,
    );
  }
}

class ActiveWorkoutCompanionController
    extends StateNotifier<ActiveWorkoutCompanionState> {
  ActiveWorkoutCompanionController(this._ref)
    : super(const ActiveWorkoutCompanionState());

  final Ref _ref;

  Future<String?> ensureSession({
    String? sessionId,
    String? planId,
    String? dayId,
    DateTime? targetDate,
  }) async {
    if (sessionId != null && sessionId.isNotEmpty) {
      final session = await _ref
          .read(aiCoachRepositoryProvider)
          .getActiveWorkoutSession(sessionId);
      state = state.copyWith(
        sessionId: sessionId,
        completedTaskIds: session?.completedTaskIds.toSet() ?? <String>{},
        partialTaskIds: session?.partialTaskIds.toSet() ?? <String>{},
        skippedTaskIds: session?.skippedTaskIds.toSet() ?? <String>{},
      );
      return sessionId;
    }
    if (planId == null || planId.isEmpty) {
      return null;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _ref
          .read(aiCoachRepositoryProvider)
          .startActiveWorkout(
            planId: planId,
            dayId: dayId,
            targetDate: _dateOnly(targetDate ?? DateTime.now()),
          );
      _ref.invalidate(activeWorkoutSessionProvider(session.id));
      state = state.copyWith(
        sessionId: session.id,
        isLoading: false,
        completedTaskIds: session.completedTaskIds.toSet(),
        partialTaskIds: session.partialTaskIds.toSet(),
        skippedTaskIds: session.skippedTaskIds.toSet(),
      );
      return session.id;
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      return null;
    }
  }

  void markTask(String taskId, TaskCompletionStatus status) {
    final completed = Set<String>.from(state.completedTaskIds);
    final partial = Set<String>.from(state.partialTaskIds);
    final skipped = Set<String>.from(state.skippedTaskIds);
    completed.remove(taskId);
    partial.remove(taskId);
    skipped.remove(taskId);
    switch (status) {
      case TaskCompletionStatus.completed:
        completed.add(taskId);
        break;
      case TaskCompletionStatus.partial:
        partial.add(taskId);
        break;
      case TaskCompletionStatus.skipped:
      case TaskCompletionStatus.missed:
        skipped.add(taskId);
        break;
      case TaskCompletionStatus.pending:
        break;
    }
    state = state.copyWith(
      completedTaskIds: completed,
      partialTaskIds: partial,
      skippedTaskIds: skipped,
    );
  }

  Future<void> refreshPrompt({String promptKind = 'mid_session'}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    try {
      final prompt = await _ref
          .read(aiCoachRepositoryProvider)
          .getWorkoutPrompt(sessionId: sessionId, promptKind: promptKind);
      state = state.copyWith(latestPrompt: prompt, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> shortenWorkout() async {
    await _applySessionAdjustment('shorten_workout');
    state = state.copyWith(wasShortened: true);
  }

  Future<void> swapExercise(String? taskId) async {
    await _applySessionAdjustment('swap_exercise', taskId: taskId);
    state = state.copyWith(wasSwapped: true);
  }

  Future<ActiveWorkoutSessionEntity?> completeSession({
    int? difficultyScore,
  }) async {
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return null;
    }
    state = state.copyWith(isCompleting: true, clearError: true);
    try {
      final session = await _ref
          .read(aiCoachRepositoryProvider)
          .completeActiveWorkout(
            sessionId: sessionId,
            difficultyScore: difficultyScore,
            summary: <String, dynamic>{
              'completed_task_ids': state.completedTaskIds.toList(),
              'partial_task_ids': state.partialTaskIds.toList(),
              'skipped_task_ids': state.skippedTaskIds.toList(),
              'was_shortened': state.wasShortened,
              'was_swapped': state.wasSwapped,
              'active_minutes': null,
            },
          );
      _ref.invalidate(activeWorkoutSessionProvider(sessionId));
      _ref.invalidate(aiCoachDailyBriefProvider(_dateOnly(DateTime.now())));
      _ref.invalidate(planDetailProvider(null));
      _ref.invalidate(todayAgendaProvider);
      _ref.invalidate(aiCoachNudgesProvider);
      state = state.copyWith(isCompleting: false, clearError: true);
      return session;
    } catch (error) {
      state = state.copyWith(
        isCompleting: false,
        errorMessage: error.toString(),
      );
      return null;
    }
  }

  Future<void> _applySessionAdjustment(String type, {String? taskId}) async {
    try {
      await _ref
          .read(aiCoachRepositoryProvider)
          .applyAdjustment(adjustmentType: type, taskId: taskId);
      final sessionId = state.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        _ref.invalidate(activeWorkoutSessionProvider(sessionId));
      }
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }
}

class AiCoachBootController {
  AiCoachBootController(this._ref);

  final Ref _ref;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    await refresh();
  }

  Future<void> refresh() async {
    final session = _ref.read(authSessionProvider).valueOrNull;
    if (session == null || !session.isAuthenticated) {
      return;
    }
    final today = _dateOnly(DateTime.now());
    final repo = _ref.read(aiCoachRepositoryProvider);
    await _runOptional(() => repo.maintainMemory());
    await _runOptional(() => repo.refreshDailyBrief(today));
    await _runOptional(() => repo.runAccountabilityScan());
    await _runOptional(() => repo.refreshWeeklySummary(_startOfWeek(today)));
    await _ref.read(plannerReminderBootstrapProvider).sync();
    _ref.invalidate(aiCoachDailyBriefProvider(today));
    _ref.invalidate(aiCoachNudgesProvider);
    _ref.invalidate(aiWeeklySummaryProvider(_startOfWeek(today)));
  }

  Future<void> _runOptional(Future<dynamic> Function() action) async {
    try {
      await action();
    } on AppFailure {
      // Legacy backends can miss optional TAIYO Coach objects during rollout.
    }
  }
}

final aiCoachDailyBriefProvider =
    FutureProvider.family<AiDailyBriefEntity?, DateTime>((ref, date) async {
      final normalized = _dateOnly(date);
      final repo = ref.watch(aiCoachRepositoryProvider);
      final cached = await repo.getDailyBrief(normalized);
      if (cached != null) {
        return cached;
      }
      return repo.refreshDailyBrief(normalized);
    });

final aiCoachReadinessControllerProvider =
    StateNotifierProvider<AiCoachReadinessController, AiCoachReadinessState>((
      ref,
    ) {
      return AiCoachReadinessController(ref);
    });

final aiCoachActionControllerProvider =
    StateNotifierProvider<AiCoachActionController, AiCoachActionState>((ref) {
      return AiCoachActionController(ref);
    });

final activeWorkoutSessionProvider =
    FutureProvider.family<ActiveWorkoutSessionEntity?, String>((
      ref,
      sessionId,
    ) {
      return ref
          .watch(aiCoachRepositoryProvider)
          .getActiveWorkoutSession(sessionId);
    });

final activeWorkoutCompanionControllerProvider =
    StateNotifierProvider<
      ActiveWorkoutCompanionController,
      ActiveWorkoutCompanionState
    >((ref) {
      return ActiveWorkoutCompanionController(ref);
    });

final aiCoachNudgesProvider = FutureProvider<List<AiNudgeEntity>>((ref) async {
  return ref.watch(aiCoachRepositoryProvider).listNudges();
});

final aiWeeklySummaryProvider =
    FutureProvider.family<AiWeeklySummaryEntity?, DateTime>((
      ref,
      weekStart,
    ) async {
      final normalized = _startOfWeek(weekStart);
      final repo = ref.watch(aiCoachRepositoryProvider);
      final cached = await repo.getWeeklySummary(normalized);
      if (cached != null) {
        return cached;
      }
      return repo.refreshWeeklySummary(normalized);
    });

final aiCoachBootProvider = Provider<AiCoachBootController>((ref) {
  return AiCoachBootController(ref);
});

final authAwareAiCoachProvider = Provider<void>((ref) {
  if (AppConfig.current.validationErrorMessage != null ||
      !SupabaseInitializer.isInitialized) {
    return;
  }

  ref.listen<AsyncValue<AuthSession?>>(authSessionProvider, (previous, next) {
    final previousId = previous?.valueOrNull?.userId;
    final nextId = next.valueOrNull?.userId;
    if (previousId == nextId) {
      return;
    }
    unawaited(ref.read(aiCoachBootProvider).refresh());
  });
});

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _startOfWeek(DateTime value) {
  final normalized = _dateOnly(value);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}
