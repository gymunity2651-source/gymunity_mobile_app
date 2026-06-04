import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../features/ai_coach/presentation/providers/ai_coach_providers.dart';
import '../../features/monetization/presentation/providers/monetization_providers.dart';
import '../../features/planner/presentation/providers/planner_providers.dart';
import '../../features/store/presentation/providers/store_providers.dart';
import '../di/providers.dart';
import '../persistence/persisted_workout_state_store.dart';
import '../supabase/auth_deep_link_bootstrap.dart';
import 'active_workout_resume_coordinator.dart';
import 'app_lifecycle_coordinator.dart';
import 'lifecycle_flush_registry.dart';
import 'offline_action_executor.dart';

final lifecycleFlushRegistryProvider = Provider<LifecycleFlushRegistry>((ref) {
  return LifecycleFlushRegistry();
});

final offlineActionExecutorProvider = Provider<OfflineActionExecutor>((ref) {
  return const NoopOfflineActionExecutor();
});

final activeWorkoutResumeCoordinatorProvider =
    Provider<ActiveWorkoutResumeCoordinator>((ref) {
      return ActiveWorkoutResumeCoordinator(ref);
    });

final appLifecycleNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((
  ref,
) {
  return GlobalKey<NavigatorState>();
});

final appLifecycleActionsProvider = Provider<AppLifecycleActions>((ref) {
  return RiverpodAppLifecycleActions(ref);
});

final appLifecycleCoordinatorProvider = Provider<AppLifecycleCoordinator>((
  ref,
) {
  return AppLifecycleCoordinator(ref.watch(appLifecycleActionsProvider));
});

class RiverpodAppLifecycleActions implements AppLifecycleActions {
  RiverpodAppLifecycleActions(this._ref);

  final Ref _ref;

  @override
  Future<void> persistCurrentRoute() {
    return _ref.read(appRouteObserverProvider).persistCurrentRoute();
  }

  @override
  Future<void> flushRegisteredState() {
    return _ref.read(lifecycleFlushRegistryProvider).flushAll();
  }

  @override
  Future<void> flushActiveWorkoutProgress() async {
    final service = _ref.read(appStatePersistenceServiceProvider).valueOrNull;
    if (service == null) {
      return;
    }
    final userId =
        (await _ref.read(userRepositoryProvider).getCurrentUser())?.id;
    final state = _ref.read(activeWorkoutCompanionControllerProvider);
    final sessionId = state.sessionId;
    if (userId == null || sessionId == null || sessionId.isEmpty) {
      return;
    }
    await service.workouts.saveActiveWorkoutState(
      userId,
      ActiveWorkoutLocalState(
        sessionId: sessionId,
        planId: '',
        dayId: '',
        completedExerciseIds: state.completedTaskIds.toList(growable: false),
      ),
    );
  }

  @override
  Future<void> flushAnalyticsIfAvailable() async {
    // No app-level analytics/logging service is registered in this codebase yet.
  }

  @override
  Future<void> pauseBackgroundServices() async {
    // Current app-level services keep auth/purchase/reminder streams that should
    // remain subscribed. Feature timers can register flush callbacks instead.
  }

  @override
  Future<LifecycleAuthResult> refreshAuthAndProfile() async {
    try {
      final currentUser = await _ref
          .read(userRepositoryProvider)
          .getCurrentUser();
      if (currentUser == null) {
        return const LifecycleAuthResult.unauthenticated();
      }
      final accountStatus = await _ref
          .read(userRepositoryProvider)
          .getAccountStatus(userId: currentUser.id);
      if (accountStatus.isDeletedLike) {
        await _clearStateForUser(currentUser.id);
        await _ref.read(authRepositoryProvider).logout();
        _navigateToWelcome();
        return const LifecycleAuthResult.unauthenticated();
      }
      _ref.invalidate(currentUserProfileProvider);
      return LifecycleAuthResult.authenticated(currentUser.id);
    } catch (_) {
      return const LifecycleAuthResult.networkUnavailable();
    }
  }

  @override
  Future<void> retryOfflineQueue(String userId) async {
    final service = _ref.read(appStatePersistenceServiceProvider).valueOrNull;
    if (service == null) {
      return;
    }
    await service.offlineQueue.retryPendingActions(
      userId: userId,
      handler: _ref.read(offlineActionExecutorProvider).execute,
    );
  }

  @override
  Future<void> checkDeepLinks() async {
    await AuthDeepLinkBootstrap.instance.start();
    final pending = await _ref
        .read(authCallbackIngressProvider)
        .consumePendingInitialUri();
    if (pending != null) {
      // The ingress stream/bootstrap handles OAuth callbacks. Consuming here
      // re-checks native pending links on resume without reinitializing streams.
    }
  }

  @override
  Future<void> refreshEntitlements() {
    return _ref.read(monetizationBootstrapProvider).refreshEntitlements();
  }

  @override
  Future<void> syncPlannerReminders() {
    return _ref.read(plannerReminderBootstrapProvider).sync();
  }

  @override
  Future<void> refreshAiCoach() {
    return _ref.read(aiCoachBootProvider).refresh();
  }

  @override
  Future<void> revalidateActiveWorkout(String userId) {
    return _ref
        .read(activeWorkoutResumeCoordinatorProvider)
        .checkForResumableWorkout(userId);
  }

  @override
  Future<void> revalidateCart(String userId) async {
    final service = _ref.read(appStatePersistenceServiceProvider).valueOrNull;
    if (service == null) {
      return;
    }
    final result = await service.cart.revalidateCart(
      userId: userId,
      isProductAvailable: (productId) async {
        try {
          final product = await _ref
              .read(storeRepositoryProvider)
              .getProductById(productId);
          return product != null && product.isAvailable;
        } catch (_) {
          return true;
        }
      },
    );
    if (result.removedProductIds.isNotEmpty) {
      _ref.invalidate(storeCartControllerProvider);
    }
  }

  @override
  Future<void> clearUnauthenticatedState() async {
    final currentUser = await _ref
        .read(userRepositoryProvider)
        .getCurrentUser();
    final userId = currentUser?.id;
    if (userId != null) {
      await _clearStateForUser(userId);
    } else {
      await _ref.read(appNavigationStateStoreProvider).clearUserScopedState();
    }
    _ref.invalidate(currentUserProfileProvider);
    _navigateToWelcome();
  }

  @override
  Future<void> cleanupDetached() async {
    await _ref.read(plannerReminderBootstrapProvider).dispose();
    await _ref.read(monetizationBootstrapProvider).dispose();
  }

  Future<void> _clearStateForUser(String userId) async {
    await _ref.read(appNavigationStateStoreProvider).clearUserScopedState();
    final service = _ref.read(appStatePersistenceServiceProvider).valueOrNull;
    if (service != null) {
      await service.clearUserScopedState(userId);
    }
  }

  void _navigateToWelcome() {
    _ref
        .read(appLifecycleNavigatorKeyProvider)
        .currentState
        ?.pushNamedAndRemoveUntil(AppRoutes.welcome, (route) => false);
  }
}
