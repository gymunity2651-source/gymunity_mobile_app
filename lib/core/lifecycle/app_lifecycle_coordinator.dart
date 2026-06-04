import 'package:flutter/material.dart';

enum LifecycleAuthStatus { authenticated, unauthenticated, networkUnavailable }

class LifecycleAuthResult {
  const LifecycleAuthResult._(this.status, this.userId);

  const LifecycleAuthResult.authenticated(String userId)
    : this._(LifecycleAuthStatus.authenticated, userId);

  const LifecycleAuthResult.unauthenticated()
    : this._(LifecycleAuthStatus.unauthenticated, null);

  const LifecycleAuthResult.networkUnavailable()
    : this._(LifecycleAuthStatus.networkUnavailable, null);

  final LifecycleAuthStatus status;
  final String? userId;
}

abstract class AppLifecycleActions {
  Future<void> persistCurrentRoute();
  Future<void> flushRegisteredState();
  Future<void> flushActiveWorkoutProgress();
  Future<void> flushAnalyticsIfAvailable();
  Future<void> pauseBackgroundServices();
  Future<LifecycleAuthResult> refreshAuthAndProfile();
  Future<void> retryOfflineQueue(String userId);
  Future<void> checkDeepLinks();
  Future<void> refreshEntitlements();
  Future<void> syncPlannerReminders();
  Future<void> refreshAiCoach();
  Future<void> revalidateActiveWorkout(String userId);
  Future<void> revalidateCart(String userId);
  Future<void> clearUnauthenticatedState();
  Future<void> cleanupDetached();
}

class AppLifecycleCoordinator {
  AppLifecycleCoordinator(this._actions);

  final AppLifecycleActions _actions;
  bool _isFlushing = false;
  bool _isResuming = false;
  bool _isDetached = false;

  Future<void> handleStateChange(AppLifecycleState state) async {
    try {
      switch (state) {
        case AppLifecycleState.resumed:
          await onResumed();
          break;
        case AppLifecycleState.inactive:
          await onInactive();
          break;
        case AppLifecycleState.paused:
          await onPaused();
          break;
        case AppLifecycleState.detached:
          await onDetached();
          break;
        case AppLifecycleState.hidden:
          await onHidden();
          break;
      }
    } catch (_) {
      // Lifecycle callbacks must never throw into the widget tree.
    }
  }

  Future<void> onInactive() => flushBeforeBackground();

  Future<void> onPaused() => flushBeforeBackground();

  Future<void> onHidden() => flushBeforeBackground();

  Future<void> onDetached() async {
    if (_isDetached) {
      return;
    }
    _isDetached = true;
    try {
      await _actions.cleanupDetached();
    } catch (_) {}
  }

  Future<void> onExitRequested() async {
    await flushBeforeBackground();
  }

  Future<void> flushBeforeBackground() async {
    if (_isFlushing) {
      return;
    }
    _isFlushing = true;
    try {
      await _safe(_actions.persistCurrentRoute);
      await _safe(_actions.flushRegisteredState);
      await _safe(_actions.flushActiveWorkoutProgress);
      await _safe(_actions.flushAnalyticsIfAvailable);
      await _safe(_actions.pauseBackgroundServices);
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> onResumed() async {
    if (_isResuming) {
      return;
    }
    _isResuming = true;
    try {
      final auth = await _safeResult(
        _actions.refreshAuthAndProfile,
        const LifecycleAuthResult.networkUnavailable(),
      );

      await _safe(_actions.checkDeepLinks);
      await _safe(_actions.refreshEntitlements);
      await _safe(_actions.syncPlannerReminders);
      await _safe(_actions.refreshAiCoach);

      if (auth.status == LifecycleAuthStatus.unauthenticated) {
        await _safe(_actions.clearUnauthenticatedState);
        return;
      }

      final userId = auth.userId;
      if (auth.status == LifecycleAuthStatus.authenticated && userId != null) {
        await _safe(() => _actions.retryOfflineQueue(userId));
        await _safe(() => _actions.revalidateActiveWorkout(userId));
        await _safe(() => _actions.revalidateCart(userId));
      }
    } finally {
      _isResuming = false;
    }
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  Future<T> _safeResult<T>(Future<T> Function() action, T fallback) async {
    try {
      return await action();
    } catch (_) {
      return fallback;
    }
  }
}
