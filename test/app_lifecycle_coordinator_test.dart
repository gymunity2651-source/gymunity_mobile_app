import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/lifecycle/app_lifecycle_coordinator.dart';

void main() {
  test('paused persists route flushes callbacks and pauses services', () async {
    final actions = _FakeLifecycleActions();
    final coordinator = AppLifecycleCoordinator(actions);

    await coordinator.handleStateChange(AppLifecycleState.paused);

    expect(actions.persistCurrentRouteCalls, 1);
    expect(actions.flushRegisteredStateCalls, 1);
    expect(actions.flushActiveWorkoutProgressCalls, 1);
    expect(actions.flushAnalyticsCalls, 1);
    expect(actions.pauseBackgroundServicesCalls, 1);
  });

  test('inactive persists route and flushes callbacks', () async {
    final actions = _FakeLifecycleActions();
    final coordinator = AppLifecycleCoordinator(actions);

    await coordinator.handleStateChange(AppLifecycleState.inactive);

    expect(actions.persistCurrentRouteCalls, 1);
    expect(actions.flushRegisteredStateCalls, 1);
  });

  test('failing lifecycle action does not throw to widget tree', () async {
    final actions = _FakeLifecycleActions()
      ..throwDuringFlushRegisteredState = true;
    final coordinator = AppLifecycleCoordinator(actions);

    await expectLater(
      coordinator.handleStateChange(AppLifecycleState.paused),
      completes,
    );

    expect(actions.pauseBackgroundServicesCalls, 1);
  });

  test('overlapping pause flushes do not run twice', () async {
    final actions = _FakeLifecycleActions()..blockFlush = true;
    final coordinator = AppLifecycleCoordinator(actions);

    final first = coordinator.handleStateChange(AppLifecycleState.paused);
    final second = coordinator.handleStateChange(AppLifecycleState.paused);
    actions.releaseFlush();
    await Future.wait(<Future<void>>[first, second]);

    expect(actions.persistCurrentRouteCalls, 1);
  });

  test(
    'resumed refreshes services profile queue deep links and workout',
    () async {
      final actions = _FakeLifecycleActions()
        ..authResult = const LifecycleAuthResult.authenticated('user-a');
      final coordinator = AppLifecycleCoordinator(actions);

      await coordinator.handleStateChange(AppLifecycleState.resumed);

      expect(actions.refreshAuthAndProfileCalls, 1);
      expect(actions.retryOfflineQueueCalls, 1);
      expect(actions.checkDeepLinksCalls, 1);
      expect(actions.refreshEntitlementsCalls, 1);
      expect(actions.syncPlannerRemindersCalls, 1);
      expect(actions.refreshAiCoachCalls, 1);
      expect(actions.revalidateActiveWorkoutCalls, 1);
      expect(actions.revalidateCartCalls, 1);
    },
  );

  test('resumed does not retry offline queue when unauthenticated', () async {
    final actions = _FakeLifecycleActions()
      ..authResult = const LifecycleAuthResult.unauthenticated();
    final coordinator = AppLifecycleCoordinator(actions);

    await coordinator.handleStateChange(AppLifecycleState.resumed);

    expect(actions.retryOfflineQueueCalls, 0);
    expect(actions.clearUnauthenticatedStateCalls, 1);
  });

  test('resume network failure does not force logout', () async {
    final actions = _FakeLifecycleActions()
      ..authResult = const LifecycleAuthResult.networkUnavailable();
    final coordinator = AppLifecycleCoordinator(actions);

    await coordinator.handleStateChange(AppLifecycleState.resumed);

    expect(actions.clearUnauthenticatedStateCalls, 0);
    expect(actions.refreshEntitlementsCalls, 1);
  });

  test('overlapping resumes do not run twice', () async {
    final actions = _FakeLifecycleActions()
      ..authResult = const LifecycleAuthResult.authenticated('user-a')
      ..blockResume = true;
    final coordinator = AppLifecycleCoordinator(actions);

    final first = coordinator.handleStateChange(AppLifecycleState.resumed);
    final second = coordinator.handleStateChange(AppLifecycleState.resumed);
    actions.releaseResume();
    await Future.wait(<Future<void>>[first, second]);

    expect(actions.refreshAuthAndProfileCalls, 1);
  });
}

class _FakeLifecycleActions implements AppLifecycleActions {
  int persistCurrentRouteCalls = 0;
  int flushRegisteredStateCalls = 0;
  int flushActiveWorkoutProgressCalls = 0;
  int flushAnalyticsCalls = 0;
  int pauseBackgroundServicesCalls = 0;
  int refreshAuthAndProfileCalls = 0;
  int retryOfflineQueueCalls = 0;
  int checkDeepLinksCalls = 0;
  int refreshEntitlementsCalls = 0;
  int syncPlannerRemindersCalls = 0;
  int refreshAiCoachCalls = 0;
  int revalidateActiveWorkoutCalls = 0;
  int revalidateCartCalls = 0;
  int clearUnauthenticatedStateCalls = 0;
  int cleanupDetachedCalls = 0;

  bool throwDuringFlushRegisteredState = false;
  bool blockFlush = false;
  bool blockResume = false;
  Completer<void>? _flushCompleter;
  Completer<void>? _resumeCompleter;
  LifecycleAuthResult authResult = const LifecycleAuthResult.authenticated(
    'user-a',
  );

  void releaseFlush() => _flushCompleter?.complete();

  void releaseResume() => _resumeCompleter?.complete();

  @override
  Future<void> persistCurrentRoute() async {
    persistCurrentRouteCalls++;
    if (blockFlush) {
      _flushCompleter ??= Completer<void>();
      await _flushCompleter!.future;
    }
  }

  @override
  Future<void> flushRegisteredState() async {
    flushRegisteredStateCalls++;
    if (throwDuringFlushRegisteredState) {
      throw StateError('flush failed');
    }
  }

  @override
  Future<void> flushActiveWorkoutProgress() async {
    flushActiveWorkoutProgressCalls++;
  }

  @override
  Future<void> flushAnalyticsIfAvailable() async {
    flushAnalyticsCalls++;
  }

  @override
  Future<void> pauseBackgroundServices() async {
    pauseBackgroundServicesCalls++;
  }

  @override
  Future<LifecycleAuthResult> refreshAuthAndProfile() async {
    refreshAuthAndProfileCalls++;
    if (blockResume) {
      _resumeCompleter ??= Completer<void>();
      await _resumeCompleter!.future;
    }
    return authResult;
  }

  @override
  Future<void> retryOfflineQueue(String userId) async {
    retryOfflineQueueCalls++;
  }

  @override
  Future<void> checkDeepLinks() async {
    checkDeepLinksCalls++;
  }

  @override
  Future<void> refreshEntitlements() async {
    refreshEntitlementsCalls++;
  }

  @override
  Future<void> syncPlannerReminders() async {
    syncPlannerRemindersCalls++;
  }

  @override
  Future<void> refreshAiCoach() async {
    refreshAiCoachCalls++;
  }

  @override
  Future<void> revalidateActiveWorkout(String userId) async {
    revalidateActiveWorkoutCalls++;
  }

  @override
  Future<void> revalidateCart(String userId) async {
    revalidateCartCalls++;
  }

  @override
  Future<void> clearUnauthenticatedState() async {
    clearUnauthenticatedStateCalls++;
  }

  @override
  Future<void> cleanupDetached() async {
    cleanupDetachedCalls++;
  }
}
