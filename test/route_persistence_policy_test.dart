import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/config/app_config.dart';
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

    test(
      'does not persist billing payment or subscription-sensitive routes',
      () {
        expect(RoutePersistencePolicy.isPersistable(AppRoutes.cart), isFalse);
        expect(RoutePersistencePolicy.isPersistable(AppRoutes.orders), isFalse);
        expect(
          RoutePersistencePolicy.isPersistable(AppRoutes.mySubscriptions),
          isFalse,
        );
        expect(
          RoutePersistencePolicy.isPersistable(AppRoutes.coachBilling),
          isFalse,
        );
        expect(
          RoutePersistencePolicy.isPersistable(
            AppRoutes.subscriptionManagement,
          ),
          isFalse,
        );
        expect(
          RoutePersistencePolicy.isPersistable(AppRoutes.checkout),
          isFalse,
        );
      },
    );

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

    test('blocks feature-gated routes when their feature flag is disabled', () {
      final config = _config(
        enableStorePurchases: false,
        enableCoachSubscriptions: false,
        enableCoachRole: false,
      );

      expect(
        RoutePersistencePolicy.isEnabledByFeatureFlags(
          AppRoutes.storeHome,
          config,
        ),
        isFalse,
      );
      expect(
        RoutePersistencePolicy.isEnabledByFeatureFlags(
          AppRoutes.coaches,
          config,
        ),
        isFalse,
      );
      expect(
        RoutePersistencePolicy.isEnabledByFeatureFlags(
          AppRoutes.coachDashboard,
          config,
        ),
        isFalse,
      );
      expect(
        RoutePersistencePolicy.isEnabledByFeatureFlags(
          AppRoutes.memberHome,
          config,
        ),
        isTrue,
      );
    });
  });
}

AppConfig _config({
  bool enableStorePurchases = true,
  bool enableCoachSubscriptions = true,
  bool enableCoachRole = true,
}) {
  return AppConfig.fromMap(<String, String>{
    'SUPABASE_URL': 'https://example.supabase.co',
    'SUPABASE_ANON_KEY': 'anon-key',
    'ENABLE_STORE_PURCHASES': enableStorePurchases.toString(),
    'ENABLE_COACH_SUBSCRIPTIONS': enableCoachSubscriptions.toString(),
    'ENABLE_COACH_ROLE': enableCoachRole.toString(),
  });
}
