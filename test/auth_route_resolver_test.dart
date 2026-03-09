import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
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
  });
}
