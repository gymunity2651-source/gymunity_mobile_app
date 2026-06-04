import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/routing/app_navigation_state_store.dart';
import 'package:my_app/core/routing/app_route_observer.dart';

void main() {
  group('AppRouteObserver', () {
    test('persists safe routes with stable params', () async {
      final store = _FakeNavigationStateStore();
      final observer = AppRouteObserver(store);

      observer.didPush(
        MaterialPageRoute<void>(
          settings: const RouteSettings(
            name: AppRoutes.aiConversation,
            arguments: AiConversationArgs(sessionId: 'session-1'),
          ),
          builder: (_) => const SizedBox.shrink(),
        ),
        null,
      );
      await pumpEventQueue();

      expect(store.savedRouteName, AppRoutes.aiConversation);
      expect(store.savedParams, containsPair('sessionId', 'session-1'));
    });

    test('does not persist sensitive routes', () async {
      final store = _FakeNavigationStateStore();
      final observer = AppRouteObserver(store);

      observer.didPush(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.otp),
          builder: (_) => const SizedBox.shrink(),
        ),
        null,
      );
      await pumpEventQueue();

      expect(store.savedRouteName, isNull);
    });
  });
}

class _FakeNavigationStateStore implements AppNavigationStateStore {
  String? savedRouteName;
  Map<String, dynamic>? savedParams;

  @override
  Future<void> clearLastSafeRoute() async {}

  @override
  Future<void> clearUserScopedState() async {}

  @override
  Future<String?> readLastDashboardRoute() async => null;

  @override
  Future<SavedRouteState?> readLastSafeRoute() async => null;

  @override
  Future<int?> readLastTabIndex(String area) async => null;

  @override
  Future<void> saveLastDashboardRoute(String routeName) async {}

  @override
  Future<void> saveLastSafeRoute(
    String routeName, {
    Map<String, dynamic>? params,
  }) async {
    savedRouteName = routeName;
    savedParams = params;
  }

  @override
  Future<void> saveLastTabIndex(String area, int index) async {}
}
