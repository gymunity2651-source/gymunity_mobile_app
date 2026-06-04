import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/routing/route_guard_policy.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';

void main() {
  tearDown(AppConfig.clearDebugOverride);

  test('auth flow routes are public and explicitly classified', () {
    for (final route in <String>[
      AppRoutes.splash,
      AppRoutes.welcome,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.forgotPassword,
      AppRoutes.resetPassword,
      AppRoutes.otp,
      AppRoutes.authCallback,
    ]) {
      final rule = RouteAccessPolicy.ruleFor(route);

      expect(rule, isNotNull, reason: route);
      expect(rule!.isPublic, isTrue, reason: route);
      expect(rule.requiresAuth, isFalse, reason: route);
    }
  });

  test('role route rules deny mismatched roles and allow owned dashboards', () {
    expect(
      RouteAccessPolicy.isAllowedForRole(AppRoutes.memberHome, AppRole.member),
      isTrue,
    );
    expect(
      RouteAccessPolicy.isAllowedForRole(AppRoutes.memberHome, AppRole.coach),
      isFalse,
    );
    expect(
      RouteAccessPolicy.isAllowedForRole(
        AppRoutes.coachDashboard,
        AppRole.coach,
      ),
      isTrue,
    );
    expect(
      RouteAccessPolicy.isAllowedForRole(
        AppRoutes.sellerDashboard,
        AppRole.seller,
      ),
      isTrue,
    );
  });

  test('feature flags block disabled feature routes centrally', () {
    final config = _config(
      enableStorePurchases: false,
      enableCoachRole: false,
      enableSellerRole: false,
      enableCoachSubscriptions: false,
    );

    expect(
      RouteAccessPolicy.isEnabledByFeatureFlags(
        AppRoutes.storeHome,
        config,
      ),
      isFalse,
    );
    expect(
      RouteAccessPolicy.isEnabledByFeatureFlags(
        AppRoutes.coachDashboard,
        config,
      ),
      isFalse,
    );
    expect(
      RouteAccessPolicy.isEnabledByFeatureFlags(
        AppRoutes.sellerDashboard,
        config,
      ),
      isFalse,
    );
    expect(
      RouteAccessPolicy.isEnabledByFeatureFlags(
        AppRoutes.subscriptionPackages,
        config,
      ),
      isFalse,
    );
  });

  test('all known AppRoutes constants have explicit access rules', () {
    for (final route in RouteAccessPolicy.allKnownRouteNames) {
      expect(RouteAccessPolicy.ruleFor(route), isNotNull, reason: route);
    }
  });
}

AppConfig _config({
  bool enableCoachRole = true,
  bool enableSellerRole = true,
  bool enableStorePurchases = true,
  bool enableCoachSubscriptions = true,
}) {
  return AppConfig.fromMap(<String, String>{
    'SUPABASE_URL': 'https://example.supabase.co',
    'SUPABASE_ANON_KEY': 'anon-key',
    'ENABLE_COACH_ROLE': enableCoachRole.toString(),
    'ENABLE_SELLER_ROLE': enableSellerRole.toString(),
    'ENABLE_STORE_PURCHASES': enableStorePurchases.toString(),
    'ENABLE_COACH_SUBSCRIPTIONS': enableCoachSubscriptions.toString(),
  });
}
