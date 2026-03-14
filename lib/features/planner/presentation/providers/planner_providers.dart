import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/supabase/supabase_initializer.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../../member/presentation/providers/member_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/services/planner_reminder_bootstrap_service.dart';
import '../../domain/entities/planner_entities.dart';

class PlannerActionState {
  const PlannerActionState({
    this.isActivating = false,
    this.isUpdatingTask = false,
    this.isUpdatingReminder = false,
    this.errorMessage,
    this.lastActivatedPlanId,
  });

  final bool isActivating;
  final bool isUpdatingTask;
  final bool isUpdatingReminder;
  final String? errorMessage;
  final String? lastActivatedPlanId;

  PlannerActionState copyWith({
    bool? isActivating,
    bool? isUpdatingTask,
    bool? isUpdatingReminder,
    String? errorMessage,
    String? lastActivatedPlanId,
    bool clearError = false,
  }) {
    return PlannerActionState(
      isActivating: isActivating ?? this.isActivating,
      isUpdatingTask: isUpdatingTask ?? this.isUpdatingTask,
      isUpdatingReminder: isUpdatingReminder ?? this.isUpdatingReminder,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastActivatedPlanId: lastActivatedPlanId ?? this.lastActivatedPlanId,
    );
  }
}

class PlannerActionController extends StateNotifier<PlannerActionState> {
  PlannerActionController(this._ref) : super(const PlannerActionState());

  final Ref _ref;

  Future<PlanActivationResultEntity?> activateDraft({
    required String draftId,
    required DateTime startDate,
    String? reminderTime,
  }) async {
    state = state.copyWith(isActivating: true, clearError: true);
    try {
      final result = await _ref
          .read(plannerRepositoryProvider)
          .activateDraft(
            draftId: draftId,
            startDate: startDate,
            reminderTime: reminderTime,
          );
      _ref.invalidate(memberHomeSummaryProvider);
      _ref.invalidate(todayAgendaProvider);
      _ref.invalidate(planDetailProvider(null));
      _ref.invalidate(planDetailProvider(result.planId));
      await _ref
          .read(plannerReminderBootstrapProvider)
          .sync(requestPermissions: true);
      state = state.copyWith(
        isActivating: false,
        clearError: true,
        lastActivatedPlanId: result.planId,
      );
      return result;
    } catch (e) {
      state = state.copyWith(isActivating: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<PlanTaskEntity?> updateTaskStatus({
    required String taskId,
    required TaskCompletionStatus status,
    int? completionPercent,
    String? note,
    int? durationMinutes,
  }) async {
    state = state.copyWith(isUpdatingTask: true, clearError: true);
    try {
      final task = await _ref
          .read(plannerRepositoryProvider)
          .updateTaskStatus(
            taskId: taskId,
            status: status,
            completionPercent: completionPercent,
            note: note,
            durationMinutes: durationMinutes,
          );
      _ref.invalidate(memberHomeSummaryProvider);
      _ref.invalidate(todayAgendaProvider);
      _ref.invalidate(planDetailProvider(task.planId));
      unawaited(_ref.read(plannerReminderBootstrapProvider).sync());
      state = state.copyWith(isUpdatingTask: false, clearError: true);
      return task;
    } catch (e) {
      state = state.copyWith(isUpdatingTask: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<bool> updateReminderTime({
    required String planId,
    required String reminderTime,
  }) async {
    state = state.copyWith(isUpdatingReminder: true, clearError: true);
    try {
      final timeZone = await _ref.read(currentTimeZoneProvider.future);
      await _ref
          .read(plannerRepositoryProvider)
          .updateReminderTime(
            planId: planId,
            reminderTime: reminderTime,
            timeZone: timeZone,
          );
      _ref.invalidate(planDetailProvider(planId));
      await _ref
          .read(plannerReminderBootstrapProvider)
          .sync(requestPermissions: true);
      state = state.copyWith(isUpdatingReminder: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isUpdatingReminder: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

class TodayAgendaSummary {
  const TodayAgendaSummary({
    this.tasks = const <PlanTaskEntity>[],
    this.pendingCount = 0,
    this.completedCount = 0,
    this.missedCount = 0,
  });

  final List<PlanTaskEntity> tasks;
  final int pendingCount;
  final int completedCount;
  final int missedCount;
}

final plannerNotificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
      return FlutterLocalNotificationsPlugin();
    });

final plannerReminderBootstrapProvider =
    Provider<PlannerReminderBootstrapService>((ref) {
      return PlannerReminderBootstrapService(
        ref,
        ref.watch(plannerNotificationsPluginProvider),
      );
    });

final currentTimeZoneProvider = FutureProvider<String>((ref) async {
  final service = ref.read(plannerReminderBootstrapProvider);
  await service.start();
  return service.resolveCurrentTimeZone();
});

final latestPlannerDraftProvider =
    FutureProvider.family<PlannerDraftEntity?, String>((ref, sessionId) async {
      return ref.watch(plannerRepositoryProvider).getLatestDraft(sessionId);
    });

final plannerDraftProvider = FutureProvider.family<PlannerDraftEntity?, String>(
  (ref, draftId) async {
    return ref.watch(plannerRepositoryProvider).getDraft(draftId);
  },
);

final todayAgendaProvider = FutureProvider<List<PlanTaskEntity>>((ref) async {
  return ref.watch(plannerRepositoryProvider).listTodayAgenda();
});

final todayAgendaSummaryProvider = Provider<TodayAgendaSummary>((ref) {
  final tasks =
      ref.watch(todayAgendaProvider).valueOrNull ?? const <PlanTaskEntity>[];
  var pending = 0;
  var completed = 0;
  var missed = 0;
  for (final task in tasks) {
    switch (task.completionStatus) {
      case TaskCompletionStatus.completed:
        completed++;
        break;
      case TaskCompletionStatus.missed:
        missed++;
        break;
      case TaskCompletionStatus.pending:
        pending++;
        break;
      case TaskCompletionStatus.partial:
      case TaskCompletionStatus.skipped:
        break;
    }
  }
  return TodayAgendaSummary(
    tasks: tasks,
    pendingCount: pending,
    completedCount: completed,
    missedCount: missed,
  );
});

final planDetailProvider = FutureProvider.family<PlanDetailEntity?, String?>((
  ref,
  planId,
) async {
  return ref.watch(plannerRepositoryProvider).getPlanDetail(planId: planId);
});

final plannerActionControllerProvider =
    StateNotifierProvider<PlannerActionController, PlannerActionState>((ref) {
      return PlannerActionController(ref);
    });

final authAwarePlannerRemindersProvider = Provider<void>((ref) {
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

    unawaited(ref.read(plannerReminderBootstrapProvider).sync());
  });

  ref.listen<AsyncValue<SettingsPreferences>>(settingsPreferencesProvider, (
    previous,
    next,
  ) {
    final previousValue = previous?.valueOrNull;
    final nextValue = next.valueOrNull;
    if (previousValue == null || nextValue == null) {
      return;
    }
    if (previousValue.pushNotificationsEnabled ==
            nextValue.pushNotificationsEnabled &&
        previousValue.aiTipsEnabled == nextValue.aiTipsEnabled) {
      return;
    }
    unawaited(
      ref
          .read(plannerReminderBootstrapProvider)
          .sync(requestPermissions: nextValue.pushNotificationsEnabled),
    );
  });
});
