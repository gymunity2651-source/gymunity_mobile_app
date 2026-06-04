import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/auth/logout_coordinator.dart';
import 'package:my_app/core/auth/logout_providers.dart';
import 'package:my_app/core/persistence/app_state_persistence_service.dart';
import 'package:my_app/core/persistence/local_json_store.dart';
import 'package:my_app/core/persistence/persisted_cart_store.dart';
import 'package:my_app/core/routing/app_navigation_state_store.dart';
import 'package:my_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';

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
        logoutServiceStopperProvider.overrideWithValue(
          const _NoopLogoutServiceStopper(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).logout();

    expect(authRepository.logoutCalls, 1);
    expect(navigationStore.clearUserScopedStateCalls, 1);
  });

  test('logout clears central user scoped app state', () async {
    final directory = await Directory.systemTemp.createTemp(
      'gymunity_logout_state_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final authRepository = FakeAuthRepository();
    final userRepository = FakeUserRepository()
      ..currentUser = const UserEntity(id: 'user-a', email: 'a@example.com');
    final navigationStore = _FakeNavigationStateStore();
    final persistence = AppStatePersistenceService(
      FileLocalJsonStore(directory),
    );
    await persistence.cart.saveCartItems('user-a', <PersistedCartItem>[
      PersistedCartItem(productId: 'p1', quantity: 1),
    ]);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        userRepositoryProvider.overrideWithValue(userRepository),
        appNavigationStateStoreProvider.overrideWithValue(navigationStore),
        appStatePersistenceServiceProvider.overrideWith((ref) async {
          return persistence;
        }),
        logoutServiceStopperProvider.overrideWithValue(
          const _NoopLogoutServiceStopper(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).logout();

    expect(await persistence.cart.readCartItems('user-a'), isEmpty);
  });
}

class _NoopLogoutServiceStopper implements LogoutServiceStopper {
  const _NoopLogoutServiceStopper();

  @override
  Future<void> stopUserScopedServices() async {}
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
  Future<SavedRouteState?> readLastSafeRoute() async => null;

  @override
  Future<int?> readLastTabIndex(String area) async => null;

  @override
  Future<void> saveLastSafeRoute(
    String routeName, {
    Map<String, dynamic>? params,
  }) async {}

  @override
  Future<void> saveLastTabIndex(String area, int index) async {}
}
