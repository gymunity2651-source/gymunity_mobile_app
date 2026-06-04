import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/auth/logout_result.dart';
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/routing/route_guard_result.dart';
import 'package:my_app/core/routing/route_guard_service.dart';
import 'package:my_app/features/user/domain/entities/account_status.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';

import 'test_doubles.dart';

void main() {
  setUp(() {
    AppConfig.debugOverrideForTests(_config());
  });

  tearDown(AppConfig.clearDebugOverride);

  test('unauthenticated user opening member dashboard redirects to login', () async {
    final logout = _RecordingLogoutCoordinator();
    final guard = RouteGuardService(
      userRepository: FakeUserRepository(),
      logout: logout.logout,
    );

    final result = await guard.guardRoute(routeName: AppRoutes.memberHome);

    expect(result, isA<RouteRedirect>());
    final redirect = result as RouteRedirect;
    expect(redirect.routeName, AppRoutes.login);
    expect(redirect.clearStack, isTrue);
    expect(logout.reasons, contains(LogoutReason.sessionExpired));
  });

  test('authenticated user with no profile redirects to role selection', () async {
    final userRepository = FakeUserRepository()
      ..currentUser = const UserEntity(id: 'user-1', email: 'u@test.com');
    final guard = RouteGuardService(
      userRepository: userRepository,
      logout: _noopLogout,
    );

    final result = await guard.guardRoute(routeName: AppRoutes.memberHome);

    expect(
      result,
      isA<RouteRedirect>().having(
        (value) => value.routeName,
        'routeName',
        AppRoutes.roleSelection,
      ),
    );
  });

  test('incomplete onboarding redirects to matching onboarding route', () async {
    final guard = RouteGuardService(
      userRepository: _userWithProfile(
        role: AppRole.coach,
        onboardingCompleted: false,
      ),
      logout: _noopLogout,
    );

    final result = await guard.guardRoute(routeName: AppRoutes.coachDashboard);

    expect(
      result,
      isA<RouteRedirect>().having(
        (value) => value.routeName,
        'routeName',
        AppRoutes.coachOnboarding,
      ),
    );
  });

  test('completed onboarding user is not sent back to onboarding', () async {
    final guard = RouteGuardService(
      userRepository: _userWithProfile(
        role: AppRole.member,
        onboardingCompleted: true,
      ),
      logout: _noopLogout,
    );

    final result = await guard.guardRoute(
      routeName: AppRoutes.memberOnboarding,
    );

    expect(
      result,
      isA<RouteRedirect>().having(
        (value) => value.routeName,
        'routeName',
        AppRoutes.memberHome,
      ),
    );
  });

  test('member cannot open coach dashboard', () async {
    final guard = RouteGuardService(
      userRepository: _userWithProfile(role: AppRole.member),
      logout: _noopLogout,
    );

    final result = await guard.guardRoute(routeName: AppRoutes.coachDashboard);

    expect(result, isA<RouteDenied>());
    expect((result as RouteDenied).fallbackRoute, AppRoutes.memberHome);
  });

  test('correct role can open its dashboard', () async {
    final guard = RouteGuardService(
      userRepository: _userWithProfile(role: AppRole.seller),
      logout: _noopLogout,
    );

    final result = await guard.guardRoute(routeName: AppRoutes.sellerDashboard);

    expect(result, isA<RouteAllowed>());
  });

  test('deleted account triggers logout and redirects safely', () async {
    final logout = _RecordingLogoutCoordinator();
    final userRepository = _userWithProfile(role: AppRole.member)
      ..accountStatus = AccountStatus.deleted;
    final guard = RouteGuardService(
      userRepository: userRepository,
      logout: logout.logout,
    );

    final result = await guard.guardRoute(routeName: AppRoutes.memberHome);

    expect(result, isA<RouteRedirect>());
    expect((result as RouteRedirect).routeName, AppRoutes.welcome);
    expect(logout.reasons, contains(LogoutReason.accountDeleted));
  });

  test('disabled store feature denies store route', () async {
    AppConfig.debugOverrideForTests(_config(enableStorePurchases: false));
    final guard = RouteGuardService(
      userRepository: _userWithProfile(role: AppRole.member),
      logout: _noopLogout,
    );

    final result = await guard.guardRoute(routeName: AppRoutes.storeHome);

    expect(result, isA<RouteDenied>());
    expect((result as RouteDenied).fallbackRoute, AppRoutes.memberHome);
  });

  test('unknown route is denied safely', () async {
    final guard = RouteGuardService(
      userRepository: _userWithProfile(role: AppRole.member),
      logout: _noopLogout,
    );

    final result = await guard.guardRoute(routeName: '/private-mystery');

    expect(result, isA<RouteDenied>());
  });
}

FakeUserRepository _userWithProfile({
  required AppRole role,
  bool onboardingCompleted = true,
}) {
  return FakeUserRepository()
    ..currentUser = const UserEntity(id: 'user-1', email: 'u@test.com')
    ..profile = ProfileEntity(
      userId: 'user-1',
      role: role,
      onboardingCompleted: onboardingCompleted,
    );
}

Future<LogoutResult> _noopLogout({
  LogoutReason reason = LogoutReason.userRequested,
  bool navigateToWelcome = true,
  bool performRemoteSignOut = true,
}) async {
  return const LogoutResult.success();
}

class _RecordingLogoutCoordinator {
  final reasons = <LogoutReason>[];

  Future<LogoutResult> logout({
    LogoutReason reason = LogoutReason.userRequested,
    bool navigateToWelcome = true,
    bool performRemoteSignOut = true,
  }) async {
    reasons.add(reason);
    return const LogoutResult.success();
  }
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
