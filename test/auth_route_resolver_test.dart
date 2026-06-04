import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/routing/app_navigation_state_store.dart';
import 'package:my_app/core/routing/auth_route_resolver.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';

import 'test_doubles.dart';

void main() {
  group('AuthRouteResolver', () {
    test('returns welcome for unauthenticated user', () async {
      final userRepository = FakeUserRepository();
      final resolver = AuthRouteResolver(userRepository);

      final route = await resolver.resolveInitialRoute();

      expect(route, AppRoutes.welcome);
    });

    test('returns role selection when profile is missing', () async {
      final userRepository = FakeUserRepository()
        ..currentUser = const UserEntity(id: 'user-1', email: 'user@test.com');
      final resolver = AuthRouteResolver(userRepository);

      final route = await resolver.resolveInitialRoute();

      expect(route, AppRoutes.roleSelection);
    });

    test('returns onboarding route for incomplete member profile', () async {
      final userRepository = FakeUserRepository()
        ..currentUser = const UserEntity(id: 'user-1', email: 'user@test.com')
        ..profile = const ProfileEntity(
          userId: 'user-1',
          role: AppRole.member,
          onboardingCompleted: false,
        );
      final resolver = AuthRouteResolver(userRepository);

      final route = await resolver.resolveAfterAuth();

      expect(route, AppRoutes.memberOnboarding);
    });

    test('returns seller dashboard for completed seller profile', () async {
      final userRepository = FakeUserRepository()
        ..currentUser = const UserEntity(id: 'user-1', email: 'user@test.com')
        ..profile = const ProfileEntity(
          userId: 'user-1',
          role: AppRole.seller,
          onboardingCompleted: true,
        );
      final resolver = AuthRouteResolver(userRepository);

      final route = await resolver.resolveAfterAuth();

      expect(route, AppRoutes.sellerDashboard);
    });

    test('returns valid saved route for authenticated user', () async {
      final userRepository = FakeUserRepository()
        ..currentUser = const UserEntity(id: 'user-1', email: 'user@test.com')
        ..profile = const ProfileEntity(
          userId: 'user-1',
          role: AppRole.member,
          onboardingCompleted: true,
        );
      final store = _FakeNavigationStateStore()
        ..savedRoute = SavedRouteState(
          userId: 'user-1',
          routeName: AppRoutes.aiChatHome,
          savedAt: DateTime.utc(2026, 6, 4),
        );
      final resolver = AuthRouteResolver(
        userRepository,
        navigationStateStore: store,
        clock: () => DateTime.utc(2026, 6, 5),
      );

      final route = await resolver.resolveInitialRoute();

      expect(route, AppRoutes.aiChatHome);
    });

    test(
      'clears and falls back when saved route belongs to different user',
      () async {
        final userRepository = FakeUserRepository()
          ..currentUser = const UserEntity(id: 'user-2', email: 'user@test.com')
          ..profile = const ProfileEntity(
            userId: 'user-2',
            role: AppRole.member,
            onboardingCompleted: true,
          );
        final store = _FakeNavigationStateStore()
          ..savedRoute = SavedRouteState(
            userId: 'user-1',
            routeName: AppRoutes.aiChatHome,
            savedAt: DateTime.utc(2026, 6, 4),
          );
        final resolver = AuthRouteResolver(
          userRepository,
          navigationStateStore: store,
          clock: () => DateTime.utc(2026, 6, 5),
        );

        final route = await resolver.resolveInitialRoute();

        expect(route, AppRoutes.memberHome);
        expect(store.clearLastSafeRouteCalls, 1);
      },
    );

    test('falls back when saved route is unsafe', () async {
      final userRepository = FakeUserRepository()
        ..currentUser = const UserEntity(id: 'user-1', email: 'user@test.com')
        ..profile = const ProfileEntity(
          userId: 'user-1',
          role: AppRole.member,
          onboardingCompleted: true,
        );
      final store = _FakeNavigationStateStore()
        ..savedRoute = SavedRouteState(
          userId: 'user-1',
          routeName: AppRoutes.otp,
          savedAt: DateTime.utc(2026, 6, 4),
        );
      final resolver = AuthRouteResolver(
        userRepository,
        navigationStateStore: store,
        clock: () => DateTime.utc(2026, 6, 5),
      );

      final route = await resolver.resolveInitialRoute();

      expect(route, AppRoutes.memberHome);
    });

    test('falls back when saved route is expired', () async {
      final userRepository = FakeUserRepository()
        ..currentUser = const UserEntity(id: 'user-1', email: 'user@test.com')
        ..profile = const ProfileEntity(
          userId: 'user-1',
          role: AppRole.member,
          onboardingCompleted: true,
        );
      final store = _FakeNavigationStateStore()
        ..savedRoute = SavedRouteState(
          userId: 'user-1',
          routeName: AppRoutes.aiChatHome,
          savedAt: DateTime.utc(2026, 5, 20),
        );
      final resolver = AuthRouteResolver(
        userRepository,
        navigationStateStore: store,
        clock: () => DateTime.utc(2026, 6, 4),
      );

      final route = await resolver.resolveInitialRoute();

      expect(route, AppRoutes.memberHome);
      expect(store.clearLastSafeRouteCalls, 1);
    });
  });
}

class _FakeNavigationStateStore implements AppNavigationStateStore {
  SavedRouteState? savedRoute;
  int clearLastSafeRouteCalls = 0;

  @override
  Future<void> clearLastSafeRoute() async {
    clearLastSafeRouteCalls++;
    savedRoute = null;
  }

  @override
  Future<void> clearUserScopedState() async {
    savedRoute = null;
  }

  @override
  Future<String?> readLastDashboardRoute() async => null;

  @override
  Future<SavedRouteState?> readLastSafeRoute() async => savedRoute;

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
