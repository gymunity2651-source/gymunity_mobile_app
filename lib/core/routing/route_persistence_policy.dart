import '../../app/routes.dart';
import '../../features/planner/presentation/route_args.dart';
import '../../features/user/domain/entities/app_role.dart';

class RoutePersistencePolicy {
  RoutePersistencePolicy._();

  static const Duration lastSafeRouteTtl = Duration(days: 7);

  static const Set<String> _unsafeRoutes = <String>{
    AppRoutes.splash,
    AppRoutes.welcome,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.forgotPassword,
    AppRoutes.resetPassword,
    AppRoutes.otp,
    AppRoutes.authCallback,
    AppRoutes.roleSelection,
    AppRoutes.memberOnboarding,
    AppRoutes.sellerOnboarding,
    AppRoutes.coachOnboarding,
    AppRoutes.checkout,
    AppRoutes.deleteAccount,
    AppRoutes.aiGeneratedPlan,
    AppRoutes.aiPremiumPaywall,
  };

  static const Set<String> _persistableRoutes = <String>{
    AppRoutes.memberHome,
    AppRoutes.workoutPlan,
    AppRoutes.workoutDetails,
    AppRoutes.activeWorkoutSession,
    AppRoutes.aiChatHome,
    AppRoutes.aiConversation,
    AppRoutes.nutrition,
    AppRoutes.nutritionMealPlan,
    AppRoutes.nutritionPreferences,
    AppRoutes.nutritionInsights,
    AppRoutes.storeHome,
    AppRoutes.productList,
    AppRoutes.favorites,
    AppRoutes.cart,
    AppRoutes.orders,
    AppRoutes.coaches,
    AppRoutes.mySubscriptions,
    AppRoutes.memberCheckins,
    AppRoutes.memberMessages,
    AppRoutes.coachDashboard,
    AppRoutes.clients,
    AppRoutes.coachCheckins,
    AppRoutes.coachCalendar,
    AppRoutes.coachBilling,
    AppRoutes.coachProgramLibrary,
    AppRoutes.coachResources,
    AppRoutes.packages,
    AppRoutes.coachProfile,
    AppRoutes.sellerDashboard,
    AppRoutes.productManagement,
    AppRoutes.sellerOrders,
    AppRoutes.sellerProfile,
  };

  static const Set<String> _memberRoutes = <String>{
    AppRoutes.memberHome,
    AppRoutes.workoutPlan,
    AppRoutes.workoutDetails,
    AppRoutes.activeWorkoutSession,
    AppRoutes.aiChatHome,
    AppRoutes.aiConversation,
    AppRoutes.nutrition,
    AppRoutes.nutritionMealPlan,
    AppRoutes.nutritionPreferences,
    AppRoutes.nutritionInsights,
    AppRoutes.storeHome,
    AppRoutes.productList,
    AppRoutes.favorites,
    AppRoutes.cart,
    AppRoutes.orders,
    AppRoutes.coaches,
    AppRoutes.mySubscriptions,
    AppRoutes.memberCheckins,
    AppRoutes.memberMessages,
  };

  static const Set<String> _coachRoutes = <String>{
    AppRoutes.coachDashboard,
    AppRoutes.clients,
    AppRoutes.coachCheckins,
    AppRoutes.coachCalendar,
    AppRoutes.coachBilling,
    AppRoutes.coachProgramLibrary,
    AppRoutes.coachResources,
    AppRoutes.packages,
    AppRoutes.coachProfile,
  };

  static const Set<String> _sellerRoutes = <String>{
    AppRoutes.sellerDashboard,
    AppRoutes.productManagement,
    AppRoutes.sellerOrders,
    AppRoutes.sellerProfile,
  };

  static const Set<String> _dashboardRoutes = <String>{
    AppRoutes.memberHome,
    AppRoutes.coachDashboard,
    AppRoutes.sellerDashboard,
  };

  static bool isPersistable(String routeName) {
    if (_unsafeRoutes.contains(routeName)) {
      return false;
    }
    return _persistableRoutes.contains(routeName);
  }

  static bool isSensitive(String routeName) =>
      _unsafeRoutes.contains(routeName);

  static bool requiresAuthentication(String routeName) {
    return isPersistable(routeName) || _dashboardRoutes.contains(routeName);
  }

  static bool isDashboardRoute(String routeName) {
    return _dashboardRoutes.contains(routeName);
  }

  static bool isAllowedForRole(String routeName, AppRole role) {
    return switch (role) {
      AppRole.member => _memberRoutes.contains(routeName),
      AppRole.coach => _coachRoutes.contains(routeName),
      AppRole.seller => _sellerRoutes.contains(routeName),
    };
  }

  static bool isExpired(DateTime savedAt, DateTime now) {
    return now.toUtc().difference(savedAt.toUtc()) > lastSafeRouteTtl;
  }

  static bool canPersist(String routeName, Object? arguments) {
    if (!isPersistable(routeName)) {
      return false;
    }
    return switch (routeName) {
      AppRoutes.workoutDetails => _hasAll(
        extractPersistableParams(routeName, arguments),
        const <String>['planId', 'dayId'],
      ),
      AppRoutes.activeWorkoutSession => _hasAny(
        extractPersistableParams(routeName, arguments),
        const <String>['sessionId', 'planId'],
      ),
      _ => true,
    };
  }

  static Map<String, dynamic> extractPersistableParams(
    String routeName,
    Object? arguments,
  ) {
    return switch (routeName) {
      AppRoutes.aiConversation => _aiConversationParams(arguments),
      AppRoutes.workoutPlan => _workoutPlanParams(arguments),
      AppRoutes.workoutDetails => _workoutDayParams(arguments),
      AppRoutes.activeWorkoutSession => _activeWorkoutParams(arguments),
      _ => const <String, dynamic>{},
    };
  }

  static Map<String, dynamic> _aiConversationParams(Object? arguments) {
    if (arguments is AiConversationArgs) {
      return _idParam('sessionId', arguments.sessionId);
    }
    if (arguments is String) {
      return _idParam('sessionId', arguments);
    }
    return const <String, dynamic>{};
  }

  static Map<String, dynamic> _workoutPlanParams(Object? arguments) {
    if (arguments is WorkoutPlanArgs) {
      return _idParam('planId', arguments.planId);
    }
    if (arguments is String) {
      return _idParam('planId', arguments);
    }
    return const <String, dynamic>{};
  }

  static Map<String, dynamic> _workoutDayParams(Object? arguments) {
    if (arguments is! WorkoutDayArgs) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{
      'planId': arguments.planId,
      'dayId': arguments.dayId,
    };
  }

  static Map<String, dynamic> _activeWorkoutParams(Object? arguments) {
    if (arguments is! ActiveWorkoutSessionArgs) {
      return const <String, dynamic>{};
    }
    return <String, dynamic>{
      if (_hasText(arguments.sessionId)) 'sessionId': arguments.sessionId,
      if (_hasText(arguments.planId)) 'planId': arguments.planId,
      if (_hasText(arguments.dayId)) 'dayId': arguments.dayId,
    };
  }

  static Map<String, dynamic> _idParam(String key, String? value) {
    return _hasText(value) ? <String, dynamic>{key: value} : const {};
  }

  static bool _hasAny(Map<String, dynamic> params, List<String> keys) {
    return keys.any((key) => _hasText(params[key] as String?));
  }

  static bool _hasAll(Map<String, dynamic> params, List<String> keys) {
    return keys.every((key) => _hasText(params[key] as String?));
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}
