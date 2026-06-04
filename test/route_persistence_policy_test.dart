import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/routing/route_persistence_policy.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';

void main() {
  group('RoutePersistencePolicy', () {
    test('does not persist sensitive authentication routes', () {
      expect(RoutePersistencePolicy.isPersistable(AppRoutes.splash), isFalse);
      expect(RoutePersistencePolicy.isPersistable(AppRoutes.login), isFalse);
      expect(RoutePersistencePolicy.isPersistable(AppRoutes.otp), isFalse);
      expect(
        RoutePersistencePolicy.isPersistable(AppRoutes.resetPassword),
        isFalse,
      );
      expect(
        RoutePersistencePolicy.isPersistable(AppRoutes.authCallback),
        isFalse,
      );
    });

    test('persists safe dashboard and home routes', () {
      expect(
        RoutePersistencePolicy.isPersistable(AppRoutes.memberHome),
        isTrue,
      );
      expect(
        RoutePersistencePolicy.isPersistable(AppRoutes.coachDashboard),
        isTrue,
      );
      expect(
        RoutePersistencePolicy.isPersistable(AppRoutes.sellerDashboard),
        isTrue,
      );
      expect(
        RoutePersistencePolicy.isPersistable(AppRoutes.aiChatHome),
        isTrue,
      );
      expect(RoutePersistencePolicy.isPersistable(AppRoutes.nutrition), isTrue);
      expect(RoutePersistencePolicy.isPersistable(AppRoutes.storeHome), isTrue);
    });

    test('prevents restoring another role dashboard', () {
      expect(
        RoutePersistencePolicy.isAllowedForRole(
          AppRoutes.coachDashboard,
          AppRole.member,
        ),
        isFalse,
      );
      expect(
        RoutePersistencePolicy.isAllowedForRole(
          AppRoutes.memberHome,
          AppRole.coach,
        ),
        isFalse,
      );
      expect(
        RoutePersistencePolicy.isAllowedForRole(
          AppRoutes.sellerDashboard,
          AppRole.seller,
        ),
        isTrue,
      );
    });
  });
}
