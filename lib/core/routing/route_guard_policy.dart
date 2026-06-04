import '../../app/routes.dart';
import '../../features/user/domain/entities/app_role.dart';
import '../config/app_config.dart';

class RouteAccessRule {
  const RouteAccessRule({
    required this.routeName,
    this.isPublic = false,
    this.requiresAuth = true,
    this.redirectAuthenticated = false,
    this.allowedRoles,
    this.requiresProfile = true,
    this.requiresCompletedOnboarding = true,
    this.featureFlag,
    this.fallbackRoute,
  });

  final String routeName;
  final bool isPublic;
  final bool requiresAuth;
  final bool redirectAuthenticated;
  final Set<AppRole>? allowedRoles;
  final bool requiresProfile;
  final bool requiresCompletedOnboarding;
  final String? featureFlag;
  final String? fallbackRoute;
}

class RouteAccessPolicy {
  RouteAccessPolicy._();

  static const String featureStorePurchases = 'store_purchases';
  static const String featureCoachRole = 'coach_role';
  static const String featureSellerRole = 'seller_role';
  static const String featureCoachSubscriptions = 'coach_subscriptions';

  static final Map<String, RouteAccessRule> routeAccessRules =
      <String, RouteAccessRule>{
        for (final route in _publicRoutes)
          route: RouteAccessRule(
            routeName: route,
            isPublic: true,
            requiresAuth: false,
            redirectAuthenticated: _authFlowRoutes.contains(route),
            requiresProfile: false,
            requiresCompletedOnboarding: false,
          ),
        AppRoutes.roleSelection: const RouteAccessRule(
          routeName: AppRoutes.roleSelection,
          requiresCompletedOnboarding: false,
          allowedRoles: null,
        ),
        AppRoutes.adminDashboard: const RouteAccessRule(
          routeName: AppRoutes.adminDashboard,
          requiresProfile: false,
          requiresCompletedOnboarding: false,
          allowedRoles: null,
        ),
        AppRoutes.memberOnboarding: const RouteAccessRule(
          routeName: AppRoutes.memberOnboarding,
          allowedRoles: <AppRole>{AppRole.member},
          requiresCompletedOnboarding: false,
        ),
        AppRoutes.coachOnboarding: const RouteAccessRule(
          routeName: AppRoutes.coachOnboarding,
          allowedRoles: <AppRole>{AppRole.coach},
          requiresCompletedOnboarding: false,
          featureFlag: featureCoachRole,
          fallbackRoute: AppRoutes.roleSelection,
        ),
        AppRoutes.sellerOnboarding: const RouteAccessRule(
          routeName: AppRoutes.sellerOnboarding,
          allowedRoles: <AppRole>{AppRole.seller},
          requiresCompletedOnboarding: false,
          featureFlag: featureSellerRole,
          fallbackRoute: AppRoutes.roleSelection,
        ),
        for (final route in _memberRoutes)
          route: RouteAccessRule(
            routeName: route,
            allowedRoles: const <AppRole>{AppRole.member},
            featureFlag: _featureFor(route),
            fallbackRoute: AppRoutes.memberHome,
          ),
        for (final route in _coachRoutes)
          route: RouteAccessRule(
            routeName: route,
            allowedRoles: const <AppRole>{AppRole.coach},
            featureFlag: _featureFor(route),
            fallbackRoute: AppRoutes.welcome,
          ),
        for (final route in _sellerRoutes)
          route: RouteAccessRule(
            routeName: route,
            allowedRoles: const <AppRole>{AppRole.seller},
            featureFlag: featureSellerRole,
            fallbackRoute: AppRoutes.welcome,
          ),
        for (final route in _sharedProtectedRoutes)
          route: RouteAccessRule(
            routeName: route,
            allowedRoles: const <AppRole>{
              AppRole.member,
              AppRole.coach,
              AppRole.seller,
            },
            featureFlag: _featureFor(route),
          ),
      };

  static Set<String> get allKnownRouteNames =>
      Set<String>.unmodifiable(_allKnownRouteNames);

  static RouteAccessRule? ruleFor(String routeName) {
    return routeAccessRules[routeName];
  }

  static bool shouldGuard(String routeName) {
    final rule = ruleFor(routeName);
    if (rule == null) {
      return false;
    }
    return !rule.isPublic && rule.requiresAuth;
  }

  static bool isAllowedForRole(String routeName, AppRole role) {
    final rule = ruleFor(routeName);
    final roles = rule?.allowedRoles;
    return roles == null || roles.contains(role);
  }

  static bool isEnabledByFeatureFlags(String routeName, AppConfig config) {
    final featureFlag = ruleFor(routeName)?.featureFlag;
    return switch (featureFlag) {
      featureStorePurchases => config.enableStorePurchases,
      featureCoachRole => config.enableCoachRole,
      featureSellerRole => config.enableSellerRole,
      featureCoachSubscriptions => config.enableCoachSubscriptions,
      _ => true,
    };
  }

  static String routeForRoleDashboard(AppRole role) {
    return switch (role) {
      AppRole.member => AppRoutes.memberHome,
      AppRole.coach => AppRoutes.coachDashboard,
      AppRole.seller => AppRoutes.sellerDashboard,
    };
  }

  static String routeForRoleOnboarding(AppRole role) {
    return switch (role) {
      AppRole.member => AppRoutes.memberOnboarding,
      AppRole.coach => AppRoutes.coachOnboarding,
      AppRole.seller => AppRoutes.sellerOnboarding,
    };
  }

  static String fallbackForRole(AppRole role) {
    final dashboard = routeForRoleDashboard(role);
    if (!isEnabledByFeatureFlags(dashboard, AppConfig.current)) {
      return AppRoutes.welcome;
    }
    return dashboard;
  }

  static String? _featureFor(String routeName) {
    if (_storeRoutes.contains(routeName)) {
      return featureStorePurchases;
    }
    if (_coachSubscriptionRoutes.contains(routeName)) {
      return featureCoachSubscriptions;
    }
    if (_coachRoutes.contains(routeName)) {
      return featureCoachRole;
    }
    return null;
  }

  static const Set<String> _publicRoutes = <String>{
    AppRoutes.splash,
    AppRoutes.welcome,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
    AppRoutes.resetPassword,
    AppRoutes.otp,
    AppRoutes.authCallback,
  };

  static const Set<String> _authFlowRoutes = <String>{
    AppRoutes.welcome,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
    AppRoutes.resetPassword,
    AppRoutes.otp,
  };

  static const Set<String> _memberRoutes = <String>{
    AppRoutes.memberHome,
    AppRoutes.memberProfile,
    AppRoutes.editProfile,
    AppRoutes.progress,
    AppRoutes.workoutPlan,
    AppRoutes.workoutDetails,
    AppRoutes.activeWorkoutSession,
    AppRoutes.nutrition,
    AppRoutes.nutritionSetup,
    AppRoutes.nutritionMealPlan,
    AppRoutes.nutritionPreferences,
    AppRoutes.nutritionInsights,
    AppRoutes.storeHome,
    AppRoutes.productList,
    AppRoutes.productDetails,
    AppRoutes.favorites,
    AppRoutes.cart,
    AppRoutes.checkout,
    AppRoutes.orders,
    AppRoutes.coaches,
    AppRoutes.coachDetails,
    AppRoutes.subscriptionPackages,
    AppRoutes.mySubscriptions,
    AppRoutes.myCoach,
    AppRoutes.memberCoachKickoff,
    AppRoutes.memberCoachHabits,
    AppRoutes.memberCoachResources,
    AppRoutes.memberCoachSessions,
    AppRoutes.memberCheckins,
    AppRoutes.memberMessages,
    AppRoutes.memberThread,
    AppRoutes.memberCoachVisibility,
  };

  static const Set<String> _coachRoutes = <String>{
    AppRoutes.coachDashboard,
    AppRoutes.clients,
    AppRoutes.packages,
    AppRoutes.addPackage,
    AppRoutes.coachProfile,
    AppRoutes.coachClientWorkspace,
    AppRoutes.coachCheckins,
    AppRoutes.coachCalendar,
    AppRoutes.coachBilling,
    AppRoutes.coachProgramLibrary,
    AppRoutes.coachOnboardingFlows,
    AppRoutes.coachResources,
    AppRoutes.coachMemberInsights,
  };

  static const Set<String> _sellerRoutes = <String>{
    AppRoutes.sellerDashboard,
    AppRoutes.productManagement,
    AppRoutes.addProduct,
    AppRoutes.editProduct,
    AppRoutes.sellerOrders,
    AppRoutes.sellerProfile,
  };

  static const Set<String> _sharedProtectedRoutes = <String>{
    AppRoutes.aiChatHome,
    AppRoutes.aiConversation,
    AppRoutes.aiPlannerBuilder,
    AppRoutes.aiGeneratedPlan,
    AppRoutes.aiPremiumPaywall,
    AppRoutes.subscriptionManagement,
    AppRoutes.newsFeed,
    AppRoutes.newsArticleDetails,
    AppRoutes.notifications,
    AppRoutes.settings,
    AppRoutes.deleteAccount,
    AppRoutes.helpSupport,
    AppRoutes.privacyPolicy,
    AppRoutes.terms,
  };

  static const Set<String> _storeRoutes = <String>{
    AppRoutes.storeHome,
    AppRoutes.productList,
    AppRoutes.productDetails,
    AppRoutes.favorites,
    AppRoutes.cart,
    AppRoutes.checkout,
    AppRoutes.orders,
  };

  static const Set<String> _coachSubscriptionRoutes = <String>{
    AppRoutes.coaches,
    AppRoutes.coachDetails,
    AppRoutes.subscriptionPackages,
    AppRoutes.mySubscriptions,
  };

  static const Set<String> _allKnownRouteNames = <String>{
    ..._publicRoutes,
    AppRoutes.roleSelection,
    AppRoutes.adminDashboard,
    AppRoutes.memberOnboarding,
    AppRoutes.coachOnboarding,
    AppRoutes.sellerOnboarding,
    ..._memberRoutes,
    ..._coachRoutes,
    ..._sellerRoutes,
    ..._sharedProtectedRoutes,
  };
}
