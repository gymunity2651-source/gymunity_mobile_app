import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/auth/logout_coordinator.dart';
import 'package:my_app/core/auth/logout_providers.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/persistence/app_state_persistence_service.dart';
import 'package:my_app/core/persistence/local_json_store.dart';
import 'package:my_app/core/persistence/persisted_cart_store.dart';
import 'package:my_app/core/persistence/persisted_workout_state_store.dart';
import 'package:my_app/core/routing/app_navigation_state_store.dart';
import 'package:my_app/features/ai_chat/presentation/providers/chat_providers.dart';
import 'package:my_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';

import 'test_doubles.dart';

void main() {
  test('logout captures current user before sign out and clears state', () async {
    final directory = await Directory.systemTemp.createTemp(
      'gymunity_logout_coordinator_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final userRepository = FakeUserRepository()
      ..currentUser = const UserEntity(id: 'user-a', email: 'a@example.com');
    final authRepository = _SignOutClearsUserAuthRepository(userRepository);
    final navigationStore = _FakeNavigationStateStore();
    final persistence = AppStatePersistenceService(
      FileLocalJsonStore(directory),
    );
    await _seedUserState(persistence, 'user-a');
    await _seedUserState(persistence, 'user-b');

    final container = _container(
      authRepository: authRepository,
      userRepository: userRepository,
      navigationStore: navigationStore,
      persistence: persistence,
    );
    addTearDown(container.dispose);

    final result = await container.read(logoutCoordinatorProvider).logout();

    expect(result.isSuccess, isTrue);
    expect(authRepository.logoutCalls, 1);
    expect(navigationStore.clearUserScopedStateCalls, 1);
    expect(await persistence.cart.readCartItems('user-a'), isEmpty);
    expect(await persistence.ai.readLastSessionId('user-a'), isNull);
    expect(await persistence.workouts.readActiveWorkoutState('user-a'), isNull);
    expect(await persistence.cart.readCartItems('user-b'), isNotEmpty);
    expect(await persistence.ai.readLastSessionId('user-b'), 'session-user-b');
  });

  test('logout still clears local state and navigates when sign out fails', () async {
    final directory = await Directory.systemTemp.createTemp(
      'gymunity_logout_signout_failure_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final userRepository = FakeUserRepository()
      ..currentUser = const UserEntity(id: 'user-a', email: 'a@example.com');
    final authRepository = _FailingLogoutAuthRepository();
    final navigationStore = _FakeNavigationStateStore();
    final persistence = AppStatePersistenceService(
      FileLocalJsonStore(directory),
    );
    await _seedUserState(persistence, 'user-a');

    final navigator = _FakeLogoutNavigator();
    final container = _container(
      authRepository: authRepository,
      userRepository: userRepository,
      navigationStore: navigationStore,
      persistence: persistence,
      navigator: navigator,
    );
    addTearDown(container.dispose);

    final result = await container.read(logoutCoordinatorProvider).logout();

    expect(result.isSuccess, isFalse);
    expect(authRepository.logoutCalls, 1);
    expect(navigationStore.clearUserScopedStateCalls, 1);
    expect(await persistence.cart.readCartItems('user-a'), isEmpty);
    expect(navigator.clearStackCalls, 1);
  });

  test('logout requests welcome navigation with full stack clearing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'gymunity_logout_navigation_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final navigator = _FakeLogoutNavigator();
    final container = _container(
      authRepository: FakeAuthRepository(),
      userRepository: FakeUserRepository()
        ..currentUser = const UserEntity(id: 'user-a', email: 'a@example.com'),
      navigationStore: _FakeNavigationStateStore(),
      persistence: AppStatePersistenceService(FileLocalJsonStore(directory)),
      navigator: navigator,
    );
    addTearDown(container.dispose);

    await container.read(logoutCoordinatorProvider).logout();

    expect(navigator.clearStackCalls, 1);
    expect(navigator.lastRouteName, AppRoutes.welcome);
  });

  test('logout resets in-memory AI prompt/session state', () async {
    final directory = await Directory.systemTemp.createTemp(
      'gymunity_logout_memory_state_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final container = _container(
      authRepository: FakeAuthRepository(),
      userRepository: FakeUserRepository()
        ..currentUser = const UserEntity(id: 'user-a', email: 'a@example.com'),
      navigationStore: _FakeNavigationStateStore(),
      persistence: AppStatePersistenceService(FileLocalJsonStore(directory)),
    );
    addTearDown(container.dispose);

    container.read(activeChatSessionIdProvider.notifier).state = 'session-a';
    container.read(pendingChatPromptProvider.notifier).state = 'hello';

    await container.read(logoutCoordinatorProvider).logout(
      navigateToWelcome: false,
    );

    expect(container.read(activeChatSessionIdProvider), isNull);
    expect(container.read(pendingChatPromptProvider), isNull);
  });
}

ProviderContainer _container({
  required AuthRepository authRepository,
  required FakeUserRepository userRepository,
  required AppNavigationStateStore navigationStore,
  required AppStatePersistenceService persistence,
  LogoutNavigator? navigator,
}) {
  return ProviderContainer(
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
      logoutNavigatorProvider.overrideWithValue(
        navigator ?? _FakeLogoutNavigator(),
      ),
    ],
  );
}

Future<void> _seedUserState(
  AppStatePersistenceService persistence,
  String userId,
) async {
  await persistence.cart.saveCartItems(userId, <PersistedCartItem>[
    PersistedCartItem(productId: 'product-$userId', quantity: 1),
  ]);
  await persistence.ai.saveLastSessionId(userId, 'session-$userId');
  await persistence.workouts.saveActiveWorkoutState(
    userId,
    ActiveWorkoutLocalState(
      sessionId: 'workout-$userId',
      planId: 'plan-$userId',
      dayId: 'day-$userId',
    ),
  );
}

class _SignOutClearsUserAuthRepository extends FakeAuthRepository {
  _SignOutClearsUserAuthRepository(this._userRepository);

  final FakeUserRepository _userRepository;

  @override
  Future<void> logout() async {
    await super.logout();
    _userRepository.currentUser = null;
  }
}

class _FailingLogoutAuthRepository extends FakeAuthRepository {
  @override
  Future<void> logout() async {
    logoutCalls++;
    throw Exception('network sign out failed');
  }
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

class _NoopLogoutServiceStopper implements LogoutServiceStopper {
  const _NoopLogoutServiceStopper();

  @override
  Future<void> stopUserScopedServices() async {}
}

class _FakeLogoutNavigator implements LogoutNavigator {
  int clearStackCalls = 0;
  String? lastRouteName;

  @override
  void navigateToWelcomeAndClearStack() {
    clearStackCalls++;
    lastRouteName = AppRoutes.welcome;
  }
}
