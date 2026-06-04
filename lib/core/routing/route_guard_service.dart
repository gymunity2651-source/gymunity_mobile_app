import '../../app/routes.dart';
import '../../features/user/domain/entities/account_status.dart';
import '../../features/user/domain/entities/profile_entity.dart';
import '../../features/user/domain/repositories/user_repository.dart';
import '../auth/logout_result.dart';
import '../config/app_config.dart';
import 'route_guard_policy.dart';
import 'route_guard_result.dart';

typedef GuardLogoutAction =
    Future<LogoutResult> Function({
      LogoutReason reason,
      bool navigateToWelcome,
      bool performRemoteSignOut,
    });

class RouteGuardService {
  RouteGuardService({required this.userRepository, required this.logout});

  final UserRepository userRepository;
  final GuardLogoutAction logout;

  Future<RouteGuardResult> guardRoute({
    required String routeName,
    Object? arguments,
  }) async {
    final rule = RouteAccessPolicy.ruleFor(routeName);
    if (rule == null) {
      return const RouteDenied(
        reason: 'You do not have access to this area.',
        fallbackRoute: AppRoutes.welcome,
      );
    }

    if (rule.isPublic && !rule.redirectAuthenticated) {
      return const RouteAllowed();
    }

    final currentUser = await userRepository.getCurrentUser();
    if (currentUser == null) {
      if (rule.isPublic) {
        return const RouteAllowed();
      }
      await logout(
        reason: LogoutReason.sessionExpired,
        navigateToWelcome: false,
        performRemoteSignOut: false,
      );
      return const RouteRedirect(
        routeName: AppRoutes.login,
        clearStack: true,
      );
    }

    final accountStatus = await _readAccountStatus(currentUser.id);
    if (accountStatus.isDeletedLike) {
      await logout(
        reason: LogoutReason.accountDeleted,
        navigateToWelcome: false,
        performRemoteSignOut: true,
      );
      return const RouteRedirect(
        routeName: AppRoutes.welcome,
        clearStack: true,
      );
    }

    final ProfileEntity? profile;
    if (rule.requiresProfile || rule.redirectAuthenticated) {
      try {
        profile = await userRepository.getProfile();
      } catch (_) {
        return const RouteDenied(
          reason: 'We could not verify your account permissions.',
          fallbackRoute: AppRoutes.login,
        );
      }
    } else {
      profile = null;
    }
    final role = profile?.role;

    if (rule.redirectAuthenticated) {
      if (profile == null || role == null) {
        return const RouteRedirect(routeName: AppRoutes.roleSelection);
      }
      if (!profile.onboardingCompleted) {
        return RouteRedirect(
          routeName: RouteAccessPolicy.routeForRoleOnboarding(role),
        );
      }
      return RouteRedirect(routeName: RouteAccessPolicy.fallbackForRole(role));
    }

    if (rule.requiresProfile && (profile == null || role == null)) {
      return const RouteRedirect(routeName: AppRoutes.roleSelection);
    }
    if (role == null) {
      return const RouteAllowed();
    }

    final onboardingRoute = RouteAccessPolicy.routeForRoleOnboarding(role);
    final dashboardRoute = RouteAccessPolicy.fallbackForRole(role);
    if (!profile!.onboardingCompleted) {
      if (routeName == onboardingRoute) {
        return const RouteAllowed();
      }
      return RouteRedirect(routeName: onboardingRoute);
    }
    if (_isOnboardingRoute(routeName)) {
      return RouteRedirect(routeName: dashboardRoute);
    }

    if (!RouteAccessPolicy.isAllowedForRole(routeName, role)) {
      return RouteDenied(
        reason: 'You do not have access to this area.',
        fallbackRoute: dashboardRoute,
      );
    }

    if (!RouteAccessPolicy.isEnabledByFeatureFlags(
      routeName,
      AppConfig.current,
    )) {
      return RouteDenied(
        reason: 'This feature is not available right now.',
        fallbackRoute: rule.fallbackRoute ?? dashboardRoute,
      );
    }

    return const RouteAllowed();
  }

  Future<AccountStatus> _readAccountStatus(String userId) async {
    try {
      return await userRepository.getAccountStatus(userId: userId);
    } catch (_) {
      return AccountStatus.active;
    }
  }

  bool _isOnboardingRoute(String routeName) {
    return routeName == AppRoutes.memberOnboarding ||
        routeName == AppRoutes.coachOnboarding ||
        routeName == AppRoutes.sellerOnboarding;
  }
}
