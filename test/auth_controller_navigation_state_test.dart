import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/routing/app_navigation_state_store.dart';
import 'package:my_app/features/auth/presentation/providers/auth_providers.dart';

import 'test_doubles.dart';

void main() {
  test('logout clears saved navigation state', () async {
    final authRepository = FakeAuthRepository();
    final navigationStore = _FakeNavigationStateStore();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        appNavigationStateStoreProvider.overrideWithValue(navigationStore),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).logout();

    expect(authRepository.logoutCalls, 1);
    expect(navigationStore.clearUserScopedStateCalls, 1);
  });
}

class _FakeNavigationStateStore implements AppNavigationStateStore {
  int clearUserScopedStateCalls = 0;

  @override
  Future<void> clearLastSafeRoute() async {}

  @override
  Future<void> clearUserScopedState() async {
    clearUserScopedStateCalls++;
  }

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
  }) async {}

  @override
  Future<void> saveLastTabIndex(String area, int index) async {}
}
