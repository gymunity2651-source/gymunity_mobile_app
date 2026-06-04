import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../features/ai_chat/presentation/providers/chat_providers.dart';
import '../../features/ai_coach/presentation/providers/ai_coach_providers.dart';
import '../../features/coach/presentation/providers/coach_providers.dart';
import '../../features/member/presentation/providers/member_providers.dart';
import '../../features/monetization/presentation/providers/monetization_providers.dart';
import '../../features/nutrition/presentation/providers/nutrition_providers.dart';
import '../../features/planner/presentation/providers/planner_providers.dart';
import '../../features/seller/presentation/providers/seller_providers.dart';
import '../../features/settings/presentation/providers/settings_providers.dart';
import '../../features/store/presentation/providers/store_providers.dart';
import '../di/providers.dart';
import '../lifecycle/active_workout_resume_coordinator.dart';
import '../navigation/app_navigator.dart';
import 'logout_result.dart';

class LogoutCoordinator {
  LogoutCoordinator(
    this._ref, {
    required LogoutServiceStopper serviceStopper,
    required LogoutNavigator navigator,
  }) : _serviceStopper = serviceStopper,
       _navigator = navigator;

  final Ref _ref;
  final LogoutServiceStopper _serviceStopper;
  final LogoutNavigator _navigator;
  Future<LogoutResult>? _inFlightLogout;

  Future<LogoutResult> logout({
    LogoutReason reason = LogoutReason.userRequested,
    bool navigateToWelcome = true,
    bool performRemoteSignOut = true,
  }) {
    final inFlight = _inFlightLogout;
    if (inFlight != null) {
      return inFlight;
    }
    final task = _logout(
      reason: reason,
      navigateToWelcome: navigateToWelcome,
      performRemoteSignOut: performRemoteSignOut,
    );
    _inFlightLogout = task;
    return task.whenComplete(() {
      _inFlightLogout = null;
    });
  }

  Future<LogoutResult> _logout({
    required LogoutReason reason,
    required bool navigateToWelcome,
    required bool performRemoteSignOut,
  }) async {
    final userId = await _readCurrentUserId();

    await _stopUserScopedServices();

    String? remoteSignOutMessage;
    if (performRemoteSignOut) {
      try {
        await _ref.read(authRepositoryProvider).logout();
      } catch (error) {
        remoteSignOutMessage = _messageFromError(error);
      }
    }

    await _clearNavigationState();
    if (userId != null) {
      await _clearLocalUserState(userId);
    }
    _resetInMemoryState();
    _invalidateUserScopedProviders();

    if (navigateToWelcome) {
      _safeNavigateToWelcome();
    }

    if (remoteSignOutMessage != null) {
      return LogoutResult.failure(remoteSignOutMessage);
    }
    return const LogoutResult.success();
  }

  Future<String?> _readCurrentUserId() async {
    try {
      return (await _ref.read(userRepositoryProvider).getCurrentUser())?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _stopUserScopedServices() async {
    await _safeCleanup(_serviceStopper.stopUserScopedServices);
  }

  Future<void> _clearNavigationState() {
    return _safeCleanup(
      () => _ref.read(appNavigationStateStoreProvider).clearUserScopedState(),
    );
  }

  Future<void> _clearLocalUserState(String userId) async {
    await _safeCleanup(() async {
      final service = await _ref.read(appStatePersistenceServiceProvider.future);
      await service.clearUserScopedState(userId);
    });
  }

  void _resetInMemoryState() {
    _safeInvalidate(activeChatSessionIdProvider);
    _safeInvalidate(pendingChatPromptProvider);
    _safeInvalidate(memberHomeTabSwitchProvider);
    _safeInvalidate(activeWorkoutResumeStateProvider);
    _safeInvalidate(activeWorkoutCompanionControllerProvider);
    _safeInvalidate(billingInteractionEventProvider);
  }

  void _invalidateUserScopedProviders() {
    for (final provider in <ProviderOrFamily>[
      authSessionProvider,
      currentUserProfileProvider,
      notificationsProvider,
      storeCartControllerProvider,
      favoriteIdsProvider,
      favoriteProductsProvider,
      shippingAddressesProvider,
      myOrdersProvider,
      chatSessionsProvider,
      aiCoachReadinessControllerProvider,
      aiCoachActionControllerProvider,
      aiCoachNudgesProvider,
      currentSubscriptionSummaryProvider,
      subscriptionManagementControllerProvider,
      todayAgendaProvider,
      plannerActionControllerProvider,
      memberProfileDetailsProvider,
      memberPreferencesProvider,
      memberWeightEntriesProvider,
      memberBodyMeasurementsProvider,
      memberWorkoutPlansProvider,
      memberWorkoutSessionsProvider,
      memberSubscriptionsProvider,
      memberCoachingThreadsProvider,
      memberOrdersProvider,
      memberHomeSummaryProvider,
      coachProfileProvider,
      coachDashboardSummaryProvider,
      coachPackagesProvider,
      coachAvailabilityProvider,
      coachClientsProvider,
      coachWorkspaceSummaryProvider,
      coachActionItemsProvider,
      coachClientPipelineFilterProvider,
      coachClientPipelineProvider,
      coachCheckinInboxProvider,
      coachProgramTemplatesProvider,
      coachExercisesProvider,
      coachOnboardingTemplatesProvider,
      coachSessionTypesProvider,
      coachBookingsProvider,
      coachPaymentQueueProvider,
      coachResourcesProvider,
      coachWorkoutPlansProvider,
      coachManagedSubscriptionsProvider,
      coachSubscriptionRequestsProvider,
      sellerProfileProvider,
      sellerDashboardSummaryProvider,
      sellerProductsProvider,
      sellerOrdersProvider,
      sellerTaiyoDashboardBriefProvider,
      nutritionProfileProvider,
      activeNutritionTargetProvider,
      activeMealPlanProvider,
      nutritionMealTemplatesProvider,
      nutritionCheckinsProvider,
      taiyoNutritionGuidanceProvider,
      nutritionDashboardProvider,
    ]) {
      _safeInvalidate(provider);
    }
  }

  void _safeNavigateToWelcome() {
    try {
      _navigator.navigateToWelcomeAndClearStack();
    } catch (_) {}
  }

  Future<void> _safeCleanup(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  void _safeInvalidate(ProviderOrFamily provider) {
    try {
      _ref.invalidate(provider);
    } catch (_) {}
  }

  String _messageFromError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    if (raw.startsWith('Bad state: ')) {
      return raw.replaceFirst('Bad state: ', '');
    }
    return raw;
  }
}

abstract class LogoutNavigator {
  void navigateToWelcomeAndClearStack();
}

class AppLogoutNavigator implements LogoutNavigator {
  AppLogoutNavigator(this._ref);

  final Ref _ref;

  @override
  void navigateToWelcomeAndClearStack() {
    final navigatorKey = _ref.read(appNavigatorKeyProvider);
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      try {
        navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (route) => false);
        return;
      } catch (_) {
        // If logout is triggered while a dialog route is still unwinding, the
        // navigator can be temporarily locked. Retry on the next frame.
      }
    }
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.welcome,
        (route) => false,
      );
    });
    binding.scheduleFrame();
  }
}

abstract class LogoutServiceStopper {
  Future<void> stopUserScopedServices();
}

class RiverpodLogoutServiceStopper implements LogoutServiceStopper {
  RiverpodLogoutServiceStopper(this._ref);

  final Ref _ref;

  @override
  Future<void> stopUserScopedServices() async {
    await _ref.read(plannerReminderBootstrapProvider).dispose();
    await _ref.read(monetizationBootstrapProvider).dispose();
    // AI coach boot has no long-lived subscription to dispose; provider
    // invalidation resets its user-scoped state before the next login.
  }
}
