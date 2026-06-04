import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/routing/app_navigation_state_store.dart';
import 'package:my_app/features/auth/data/launch_state_store.dart';
import 'package:my_app/features/auth/presentation/controllers/launch_context_resolver.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_doubles.dart';

void main() {
  group('LaunchContextResolver', () {
    late FakeUserRepository userRepository;
    late _FakeNavigationStateStore navigationStore;
    late _MemoryLaunchStateStore launchStateStore;

    setUp(() {
      userRepository = FakeUserRepository();
      navigationStore = _FakeNavigationStateStore();
      launchStateStore = _MemoryLaunchStateStore();
    });

    LaunchContextResolver buildResolver() {
      return LaunchContextResolver(
        userRepository: userRepository,
        navigationStateStore: navigationStore,
        launchStateStore: launchStateStore,
      );
    }

    test('no first-launch marker returns first install launch', () async {
      userRepository.currentUser = const UserEntity(
        id: 'user-1',
        email: 'user@test.com',
      );

      expect(await buildResolver().resolve(), AppLaunchKind.firstInstallLaunch);
    });

    test('no authenticated session returns unauthenticated launch', () async {
      launchStateStore.completed = true;

      expect(
        await buildResolver().resolve(),
        AppLaunchKind.unauthenticatedLaunch,
      );
    });

    test(
      'authenticated session with safe restored route returns restored',
      () async {
        launchStateStore.completed = true;
        userRepository.currentUser = const UserEntity(
          id: 'user-1',
          email: 'user@test.com',
        );
        navigationStore.savedRoute = SavedRouteState(
          userId: 'user-1',
          routeName: AppRoutes.aiChatHome,
          savedAt: DateTime.utc(2026, 6, 4),
        );

        expect(
          await buildResolver().resolve(),
          AppLaunchKind.restoredSessionColdStart,
        );
      },
    );

    test(
      'authenticated session without restored route returns cold start',
      () async {
        launchStateStore.completed = true;
        userRepository.currentUser = const UserEntity(
          id: 'user-1',
          email: 'user@test.com',
        );

        expect(
          await buildResolver().resolve(),
          AppLaunchKind.authenticatedColdStart,
        );
      },
    );

    test('restored route for another user is treated as cold start', () async {
      launchStateStore.completed = true;
      userRepository.currentUser = const UserEntity(
        id: 'user-2',
        email: 'user@test.com',
      );
      navigationStore.savedRoute = SavedRouteState(
        userId: 'user-1',
        routeName: AppRoutes.aiChatHome,
        savedAt: DateTime.utc(2026, 6, 4),
      );

      expect(
        await buildResolver().resolve(),
        AppLaunchKind.authenticatedColdStart,
      );
    });
  });

  group('SharedPreferencesLaunchStateStore', () {
    test('marks first launch complete', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesLaunchStateStore(preferences);

      expect(await store.hasCompletedFirstLaunch(), isFalse);

      await store.markFirstLaunchComplete();

      expect(await store.hasCompletedFirstLaunch(), isTrue);
    });
  });
}

class _MemoryLaunchStateStore implements LaunchStateStore {
  bool completed = false;

  @override
  Future<bool> hasCompletedFirstLaunch() async => completed;

  @override
  Future<void> markFirstLaunchComplete() async {
    completed = true;
  }
}

class _FakeNavigationStateStore implements AppNavigationStateStore {
  SavedRouteState? savedRoute;

  @override
  Future<void> clearLastSafeRoute() async {
    savedRoute = null;
  }

  @override
  Future<void> clearUserScopedState() async {
    savedRoute = null;
  }

  @override
  Future<SavedRouteState?> readLastSafeRoute() async => savedRoute;

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
