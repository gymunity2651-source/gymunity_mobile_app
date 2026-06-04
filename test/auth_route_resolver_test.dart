import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/routing/app_navigation_state_store.dart';
import 'package:my_app/core/routing/auth_route_resolver.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_session_entity.dart';
import 'package:my_app/features/ai_coach/domain/entities/ai_coach_entities.dart';
import 'package:my_app/features/planner/domain/entities/planner_entities.dart';
import 'package:my_app/features/planner/presentation/route_args.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';

import 'test_doubles.dart';

void main() {
  group('AuthRouteResolver', () {
    setUp(() {
      AppConfig.debugOverrideForTests(_config());
    });

    tearDown(AppConfig.clearDebugOverride);

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
      expect(store.clearLastSafeRouteCalls, 1);
    });

    test(
      'clears and falls back when saved route is for another role',
      () async {
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
            routeName: AppRoutes.coachDashboard,
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

    test(
      'clears and falls back when saved store route feature is disabled',
      () async {
        AppConfig.debugOverrideForTests(_config(enableStorePurchases: false));
        final userRepository = _memberUserRepository();
        final store = _FakeNavigationStateStore()
          ..savedRoute = SavedRouteState(
            userId: 'user-1',
            routeName: AppRoutes.storeHome,
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

    test(
      'clears and falls back when coach subscription feature is disabled',
      () async {
        AppConfig.debugOverrideForTests(
          _config(enableCoachSubscriptions: false),
        );
        final userRepository = _memberUserRepository();
        final store = _FakeNavigationStateStore()
          ..savedRoute = SavedRouteState(
            userId: 'user-1',
            routeName: AppRoutes.coaches,
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

    test('clears and falls back when coach role feature is disabled', () async {
      AppConfig.debugOverrideForTests(_config(enableCoachRole: false));
      final userRepository = FakeUserRepository()
        ..currentUser = const UserEntity(id: 'coach-1', email: 'coach@test.com')
        ..profile = const ProfileEntity(
          userId: 'coach-1',
          role: AppRole.coach,
          onboardingCompleted: true,
        );
      final store = _FakeNavigationStateStore()
        ..savedRoute = SavedRouteState(
          userId: 'coach-1',
          routeName: AppRoutes.coachDashboard,
          savedAt: DateTime.utc(2026, 6, 4),
        );
      final resolver = AuthRouteResolver(
        userRepository,
        navigationStateStore: store,
        clock: () => DateTime.utc(2026, 6, 5),
      );

      final route = await resolver.resolveInitialRoute();

      expect(route, AppRoutes.coachDashboard);
      expect(store.clearLastSafeRouteCalls, 1);
    });

    test('restores AI conversation when saved session exists', () async {
      final chatRepository = FakeChatRepository()
        ..sessions.add(
          ChatSessionEntity(
            id: 'session-1',
            userId: 'user-1',
            title: 'Saved chat',
            updatedAt: DateTime.utc(2026, 6, 4),
          ),
        );
      final store = _FakeNavigationStateStore()
        ..savedRoute = SavedRouteState(
          userId: 'user-1',
          routeName: AppRoutes.aiConversation,
          savedAt: DateTime.utc(2026, 6, 4),
          params: const <String, dynamic>{'sessionId': 'session-1'},
        );
      final resolver = AuthRouteResolver(
        _memberUserRepository(),
        navigationStateStore: store,
        chatRepository: chatRepository,
        clock: () => DateTime.utc(2026, 6, 5),
      );

      final route = await resolver.resolveInitialAppRoute();

      expect(route.routeName, AppRoutes.aiConversation);
      expect(route.arguments, isA<AiConversationArgs>());
      expect(store.clearLastSafeRouteCalls, 0);
    });

    test(
      'clears and falls back when saved AI session no longer exists',
      () async {
        final store = _FakeNavigationStateStore()
          ..savedRoute = SavedRouteState(
            userId: 'user-1',
            routeName: AppRoutes.aiConversation,
            savedAt: DateTime.utc(2026, 6, 4),
            params: const <String, dynamic>{'sessionId': 'missing-session'},
          );
        final resolver = AuthRouteResolver(
          _memberUserRepository(),
          navigationStateStore: store,
          chatRepository: FakeChatRepository(),
          clock: () => DateTime.utc(2026, 6, 5),
        );

        final route = await resolver.resolveInitialRoute();

        expect(route, AppRoutes.aiChatHome);
        expect(store.clearLastSafeRouteCalls, 1);
      },
    );

    test(
      'AI conversation validation error falls back without startup failure',
      () async {
        final store = _FakeNavigationStateStore()
          ..savedRoute = SavedRouteState(
            userId: 'user-1',
            routeName: AppRoutes.aiConversation,
            savedAt: DateTime.utc(2026, 6, 4),
            params: const <String, dynamic>{'sessionId': 'session-1'},
          );
        final resolver = AuthRouteResolver(
          _memberUserRepository(),
          navigationStateStore: store,
          chatRepository: _ThrowingChatRepository(),
          clock: () => DateTime.utc(2026, 6, 5),
        );

        final route = await resolver.resolveInitialRoute();

        expect(route, AppRoutes.memberHome);
        expect(store.clearLastSafeRouteCalls, 1);
      },
    );

    test('restores workout plan when saved plan exists', () async {
      final plannerRepository = FakePlannerRepository()
        ..plans['plan-1'] = const PlanDetailEntity(
          planId: 'plan-1',
          planTitle: 'Plan',
          planStatus: 'active',
          planSource: 'ai',
        );
      final store = _FakeNavigationStateStore()
        ..savedRoute = SavedRouteState(
          userId: 'user-1',
          routeName: AppRoutes.workoutPlan,
          savedAt: DateTime.utc(2026, 6, 4),
          params: const <String, dynamic>{'planId': 'plan-1'},
        );
      final resolver = AuthRouteResolver(
        _memberUserRepository(),
        navigationStateStore: store,
        plannerRepository: plannerRepository,
        clock: () => DateTime.utc(2026, 6, 5),
      );

      final route = await resolver.resolveInitialAppRoute();

      expect(route.routeName, AppRoutes.workoutPlan);
      expect(route.arguments, isA<WorkoutPlanArgs>());
      expect(store.clearLastSafeRouteCalls, 0);
    });

    test(
      'clears and falls back when saved workout plan no longer exists',
      () async {
        final store = _FakeNavigationStateStore()
          ..savedRoute = SavedRouteState(
            userId: 'user-1',
            routeName: AppRoutes.workoutPlan,
            savedAt: DateTime.utc(2026, 6, 4),
            params: const <String, dynamic>{'planId': 'missing-plan'},
          );
        final resolver = AuthRouteResolver(
          _memberUserRepository(),
          navigationStateStore: store,
          plannerRepository: FakePlannerRepository(),
          clock: () => DateTime.utc(2026, 6, 5),
        );

        final route = await resolver.resolveInitialRoute();

        expect(route, AppRoutes.memberHome);
        expect(store.clearLastSafeRouteCalls, 1);
      },
    );

    test(
      'workout validation error falls back without startup failure',
      () async {
        final store = _FakeNavigationStateStore()
          ..savedRoute = SavedRouteState(
            userId: 'user-1',
            routeName: AppRoutes.workoutPlan,
            savedAt: DateTime.utc(2026, 6, 4),
            params: const <String, dynamic>{'planId': 'plan-1'},
          );
        final resolver = AuthRouteResolver(
          _memberUserRepository(),
          navigationStateStore: store,
          plannerRepository: _ThrowingPlannerRepository(),
          clock: () => DateTime.utc(2026, 6, 5),
        );

        final route = await resolver.resolveInitialRoute();

        expect(route, AppRoutes.memberHome);
        expect(store.clearLastSafeRouteCalls, 1);
      },
    );

    test('active workout does not restore completed session', () async {
      final aiCoachRepository = FakeAiCoachRepository()
        ..activeWorkoutSession = ActiveWorkoutSessionEntity(
          id: 'session-1',
          status: 'completed',
          startedAt: DateTime.utc(2026, 6, 4, 10),
          endedAt: DateTime.utc(2026, 6, 4, 11),
          plannedMinutes: 40,
          wasShortened: false,
          wasSwapped: false,
          whyShort: 'Done',
          confidence: 0.9,
        );
      final store = _FakeNavigationStateStore()
        ..savedRoute = SavedRouteState(
          userId: 'user-1',
          routeName: AppRoutes.activeWorkoutSession,
          savedAt: DateTime.utc(2026, 6, 4),
          params: const <String, dynamic>{'sessionId': 'session-1'},
        );
      final resolver = AuthRouteResolver(
        _memberUserRepository(),
        navigationStateStore: store,
        aiCoachRepository: aiCoachRepository,
        clock: () => DateTime.utc(2026, 6, 5),
      );

      final route = await resolver.resolveInitialRoute();

      expect(route, AppRoutes.memberHome);
      expect(store.clearLastSafeRouteCalls, 1);
    });
  });
}

FakeUserRepository _memberUserRepository() {
  return FakeUserRepository()
    ..currentUser = const UserEntity(id: 'user-1', email: 'user@test.com')
    ..profile = const ProfileEntity(
      userId: 'user-1',
      role: AppRole.member,
      onboardingCompleted: true,
    );
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

class _ThrowingChatRepository extends FakeChatRepository {
  @override
  Future<List<ChatSessionEntity>> listSessions() async {
    throw StateError('network unavailable');
  }
}

class _ThrowingPlannerRepository extends FakePlannerRepository {
  @override
  Future<PlanDetailEntity?> getPlanDetail({String? planId}) async {
    throw StateError('network unavailable');
  }
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
  Future<SavedRouteState?> readLastSafeRoute() async => savedRoute;

  @override
  Future<int?> readLastTabIndex(String area) async => null;

  @override
  Future<void> saveLastSafeRoute(
    String routeName, {
    Map<String, dynamic>? params,
  }) async {}

  @override
  Future<void> saveLastTabIndex(String area, int index) async {}
}
