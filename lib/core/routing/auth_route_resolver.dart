import '../../app/routes.dart';
import '../../features/ai_chat/domain/repositories/chat_repository.dart';
import '../../features/ai_coach/domain/repositories/ai_coach_repository.dart';
import '../../features/planner/domain/repositories/planner_repository.dart';
import '../../features/planner/presentation/route_args.dart';
import '../../features/user/domain/entities/app_role.dart';
import '../../features/user/domain/entities/profile_entity.dart';
import '../../features/user/domain/repositories/user_repository.dart';
import 'app_navigation_state_store.dart';
import 'route_persistence_policy.dart';

class ResolvedAppRoute {
  const ResolvedAppRoute({required this.routeName, this.arguments});

  final String routeName;
  final Object? arguments;
}

typedef PlannerRepositoryReader = PlannerRepository Function();
typedef ChatRepositoryReader = ChatRepository Function();
typedef AiCoachRepositoryReader = AiCoachRepository Function();

class AuthRouteResolver {
  AuthRouteResolver(
    this._userRepository, {
    AppNavigationStateStore? navigationStateStore,
    PlannerRepository? plannerRepository,
    ChatRepository? chatRepository,
    AiCoachRepository? aiCoachRepository,
    PlannerRepositoryReader? plannerRepositoryReader,
    ChatRepositoryReader? chatRepositoryReader,
    AiCoachRepositoryReader? aiCoachRepositoryReader,
    NavigationClock? clock,
  }) : _navigationStateStore = navigationStateStore,
       _plannerRepository = plannerRepository,
       _chatRepository = chatRepository,
       _aiCoachRepository = aiCoachRepository,
       _plannerRepositoryReader = plannerRepositoryReader,
       _chatRepositoryReader = chatRepositoryReader,
       _aiCoachRepositoryReader = aiCoachRepositoryReader,
       _clock = clock ?? DateTime.now;

  final UserRepository _userRepository;
  final AppNavigationStateStore? _navigationStateStore;
  final PlannerRepository? _plannerRepository;
  final ChatRepository? _chatRepository;
  final AiCoachRepository? _aiCoachRepository;
  final PlannerRepositoryReader? _plannerRepositoryReader;
  final ChatRepositoryReader? _chatRepositoryReader;
  final AiCoachRepositoryReader? _aiCoachRepositoryReader;
  final NavigationClock _clock;

  Future<String> resolveInitialRoute() async {
    return (await resolveInitialAppRoute()).routeName;
  }

  Future<ResolvedAppRoute> resolveInitialAppRoute() async {
    final currentUser = await _userRepository.getCurrentUser();
    if (currentUser == null) {
      await _navigationStateStore?.clearLastSafeRoute();
      return const ResolvedAppRoute(routeName: AppRoutes.welcome);
    }
    final profile = await _userRepository.getProfile();
    return _resolveByProfile(profile, currentUserId: currentUser.id);
  }

  Future<String> resolveAfterAuth() async {
    final currentUser = await _userRepository.getCurrentUser();
    if (currentUser == null) return AppRoutes.login;
    final profile = await _userRepository.getProfile();
    return (await _resolveByProfile(
      profile,
      currentUserId: currentUser.id,
    )).routeName;
  }

  String routeForRoleDashboard(AppRole role) {
    switch (role) {
      case AppRole.member:
        return AppRoutes.memberHome;
      case AppRole.coach:
        return AppRoutes.coachDashboard;
      case AppRole.seller:
        return AppRoutes.sellerDashboard;
    }
  }

  String routeForRoleOnboarding(AppRole role) {
    switch (role) {
      case AppRole.member:
        return AppRoutes.memberOnboarding;
      case AppRole.coach:
        return AppRoutes.coachOnboarding;
      case AppRole.seller:
        return AppRoutes.sellerOnboarding;
    }
  }

  Future<ResolvedAppRoute> _resolveByProfile(
    ProfileEntity? profile, {
    required String currentUserId,
  }) async {
    if (profile == null) {
      return const ResolvedAppRoute(routeName: AppRoutes.roleSelection);
    }
    final role = profile.role;
    if (role == null) {
      return const ResolvedAppRoute(routeName: AppRoutes.roleSelection);
    }
    if (!profile.onboardingCompleted) {
      return ResolvedAppRoute(routeName: routeForRoleOnboarding(role));
    }
    final savedRoute = await _navigationStateStore?.readLastSafeRoute();
    if (savedRoute != null) {
      final restoredRoute = await _restoreSavedRoute(
        savedRoute,
        currentUserId: currentUserId,
        role: role,
      );
      if (restoredRoute != null) {
        return restoredRoute;
      }
    }
    return ResolvedAppRoute(routeName: routeForRoleDashboard(role));
  }

  Future<ResolvedAppRoute?> _restoreSavedRoute(
    SavedRouteState savedRoute, {
    required String currentUserId,
    required AppRole role,
  }) async {
    if (savedRoute.userId != currentUserId ||
        RoutePersistencePolicy.isExpired(savedRoute.savedAt, _clock())) {
      await _navigationStateStore?.clearLastSafeRoute();
      return null;
    }
    if (!RoutePersistencePolicy.isPersistable(savedRoute.routeName) ||
        !RoutePersistencePolicy.isAllowedForRole(savedRoute.routeName, role)) {
      return null;
    }
    return _validateSavedRouteEntities(savedRoute);
  }

  Future<ResolvedAppRoute?> _validateSavedRouteEntities(
    SavedRouteState savedRoute,
  ) async {
    switch (savedRoute.routeName) {
      case AppRoutes.aiConversation:
        final sessionId = _stringParam(savedRoute, 'sessionId');
        if (sessionId == null) {
          return const ResolvedAppRoute(routeName: AppRoutes.aiChatHome);
        }
        final chatRepository = _chatRepository ?? _chatRepositoryReader?.call();
        if (chatRepository != null) {
          final sessions = await chatRepository.listSessions();
          final exists = sessions.any((session) => session.id == sessionId);
          if (!exists) {
            return const ResolvedAppRoute(routeName: AppRoutes.aiChatHome);
          }
        }
        return ResolvedAppRoute(
          routeName: AppRoutes.aiConversation,
          arguments: AiConversationArgs(sessionId: sessionId),
        );
      case AppRoutes.workoutPlan:
        final planId = _stringParam(savedRoute, 'planId');
        final plannerRepository =
            _plannerRepository ?? _plannerRepositoryReader?.call();
        if (planId != null && plannerRepository != null) {
          final plan = await plannerRepository.getPlanDetail(planId: planId);
          if (plan == null) {
            return const ResolvedAppRoute(routeName: AppRoutes.memberHome);
          }
        }
        return ResolvedAppRoute(
          routeName: AppRoutes.workoutPlan,
          arguments: WorkoutPlanArgs(planId: planId),
        );
      case AppRoutes.workoutDetails:
        final planId = _stringParam(savedRoute, 'planId');
        final dayId = _stringParam(savedRoute, 'dayId');
        if (planId == null || dayId == null) {
          return const ResolvedAppRoute(routeName: AppRoutes.memberHome);
        }
        final plannerRepository =
            _plannerRepository ?? _plannerRepositoryReader?.call();
        if (plannerRepository != null) {
          final plan = await plannerRepository.getPlanDetail(planId: planId);
          if (plan == null) {
            return const ResolvedAppRoute(routeName: AppRoutes.memberHome);
          }
          final dayExists = plan.days.any((day) => day.id == dayId);
          if (!dayExists) {
            return ResolvedAppRoute(
              routeName: AppRoutes.workoutPlan,
              arguments: WorkoutPlanArgs(planId: planId),
            );
          }
        }
        return ResolvedAppRoute(
          routeName: AppRoutes.workoutDetails,
          arguments: WorkoutDayArgs(planId: planId, dayId: dayId),
        );
      case AppRoutes.activeWorkoutSession:
        final sessionId = _stringParam(savedRoute, 'sessionId');
        final planId = _stringParam(savedRoute, 'planId');
        final dayId = _stringParam(savedRoute, 'dayId');
        final aiCoachRepository =
            _aiCoachRepository ?? _aiCoachRepositoryReader?.call();
        if (sessionId != null && aiCoachRepository != null) {
          final session = await aiCoachRepository.getActiveWorkoutSession(
            sessionId,
          );
          if (session == null ||
              session.status.toLowerCase() == 'completed' ||
              session.endedAt != null) {
            return const ResolvedAppRoute(routeName: AppRoutes.memberHome);
          }
        }
        return ResolvedAppRoute(
          routeName: AppRoutes.activeWorkoutSession,
          arguments: ActiveWorkoutSessionArgs(
            sessionId: sessionId,
            planId: planId,
            dayId: dayId,
          ),
        );
      default:
        return ResolvedAppRoute(routeName: savedRoute.routeName);
    }
  }

  String? _stringParam(SavedRouteState savedRoute, String key) {
    final value = savedRoute.params[key];
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    return value;
  }
}
