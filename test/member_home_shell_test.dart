import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/routing/app_navigation_state_store.dart';
import 'package:my_app/features/member/domain/entities/member_home_summary_entity.dart';
import 'package:my_app/features/member/presentation/screens/member_home_screen.dart';
import 'package:my_app/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:my_app/features/news/domain/entities/news_article.dart';
import 'package:my_app/features/nutrition/presentation/screens/nutrition_home_screen.dart';
import 'package:my_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:my_app/features/settings/presentation/screens/notifications_screen.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';

import 'test_doubles.dart';

void main() {
  group('Member home shell', () {
    testWidgets(
      'profile tab shows the profile screen instead of home content',
      (tester) async {
        await _pumpMemberShell(tester);

        await tester.tap(find.byKey(const Key('member-nav-PROFILE')));
        await _settleShell(tester);

        expect(find.text('member@gymunity.com'), findsOneWidget);
        expect(find.text('My Coaching'), findsOneWidget);
        expect(find.text('Open my coaching'), findsNothing);
      },
    );

    testWidgets('TAIYO tab remains on the TAIYO home after rebuild', (
      tester,
    ) async {
      final widget = _buildShellApp();

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(widget);
      await _settleShell(tester);

      await tester.tap(find.byKey(const Key('member-nav-TAIYO')));
      await _settleShell(tester);

      expect(find.text('TAIYO Coach'), findsOneWidget);
      expect(find.text('Daily guidance in one screen'), findsOneWidget);
      expect(
        find.byKey(const Key('member-bottom-nav-default-mode')),
        findsOneWidget,
      );

      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('TAIYO Coach'), findsOneWidget);
      expect(find.text('Daily guidance in one screen'), findsOneWidget);
      expect(
        find.byKey(const Key('member-bottom-nav-default-mode')),
        findsOneWidget,
      );
      expect(find.text('My Coaching'), findsNothing);
    });

    testWidgets('news tab opens the recommended reads feed', (tester) async {
      await _pumpMemberShell(tester);

      await tester.tap(find.byKey(const Key('member-nav-NEWS')));
      await _settleShell(tester);

      expect(find.textContaining('Recommended'), findsOneWidget);
      expect(
        find.text('Recovery basics for consistent training'),
        findsOneWidget,
      );
    });

    testWidgets('restores a valid saved member tab index', (tester) async {
      await _pumpMemberShell(
        tester,
        navigationStateStore: _SavedTabNavigationStateStore(
          area: 'member_home',
          index: 2,
        ),
      );

      expect(find.text('TAIYO Coach'), findsOneWidget);
      expect(find.byKey(const Key('member-daily-streak-card')), findsNothing);
    });

    testWidgets('ignores an invalid saved member tab index', (tester) async {
      await _pumpMemberShell(
        tester,
        navigationStateStore: _SavedTabNavigationStateStore(
          area: 'member_home',
          index: 99,
        ),
      );

      expect(find.byKey(const Key('member-daily-streak-card')), findsOneWidget);
      expect(find.text('TAIYO Coach'), findsNothing);
    });

    testWidgets('android back from coaches tab returns to home tab', (
      tester,
    ) async {
      await _pumpMemberShell(tester);

      await tester.tap(find.byKey(const Key('member-nav-COACHES')));
      await _settleShell(tester);

      expect(find.text('Coach\nMarketplace'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _settleShell(tester);

      expect(find.byKey(const Key('member-daily-streak-card')), findsOneWidget);
      expect(find.text('Coach\nMarketplace'), findsNothing);
    });

    testWidgets('home quick action opens the TAIYO screen', (tester) async {
      await _pumpMemberShell(tester);

      await tester.tap(find.text('Open TAIYO'));
      await _settleShell(tester);

      expect(find.text('TAIYO Coach'), findsOneWidget);
      expect(find.text('Daily guidance in one screen'), findsOneWidget);
    });

    testWidgets('home nutrition quick action opens nutrition screen', (
      tester,
    ) async {
      await _pumpMemberShell(tester);

      await tester.tap(find.byKey(const Key('member-home-nutrition-action')));
      await _settleShell(tester);

      expect(find.byType(NutritionHomeScreen), findsOneWidget);
      expect(find.text('Build your nutrition plan'), findsOneWidget);
    });

    testWidgets('bottom nav styling stays consistent on the TAIYO tab', (
      tester,
    ) async {
      await _pumpMemberShell(tester);

      expect(
        find.byKey(const Key('member-bottom-nav-default-mode')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('member-nav-TAIYO')));
      await _settleShell(tester);

      expect(
        find.byKey(const Key('member-bottom-nav-default-mode')),
        findsOneWidget,
      );
      expect(find.text('HOME'), findsOneWidget);

      await tester.tap(find.byKey(const Key('member-nav-NEWS')));
      await _settleShell(tester);

      expect(
        find.byKey(const Key('member-bottom-nav-default-mode')),
        findsOneWidget,
      );
      expect(find.textContaining('Recommended'), findsOneWidget);
    });

    testWidgets('profile shortcut opens profile from home and coaches', (
      tester,
    ) async {
      await _pumpMemberShell(tester);

      await tester.tap(find.byKey(const Key('member-profile-shortcut')));
      await _settleShell(tester);

      expect(find.text('member@gymunity.com'), findsOneWidget);
      expect(find.text('My Coaching'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await _settleShell(tester);

      await tester.tap(find.byKey(const Key('member-nav-COACHES')));
      await _settleShell(tester);
      await tester.tap(find.byKey(const Key('member-profile-shortcut')));
      await _settleShell(tester);

      expect(find.text('member@gymunity.com'), findsOneWidget);
      expect(find.text('My Coaching'), findsOneWidget);
    });

    testWidgets('profile nutrition action opens nutrition screen', (
      tester,
    ) async {
      await _pumpMemberShell(tester);

      await tester.tap(find.byKey(const Key('member-nav-PROFILE')));
      await _settleShell(tester);
      await tester.tap(
        find.byKey(const Key('member-profile-nutrition-action')),
      );
      await _settleShell(tester);

      expect(find.byType(NutritionHomeScreen), findsOneWidget);
      expect(find.text('Build your nutrition plan'), findsOneWidget);
    });

    testWidgets('notification bell opens notifications from member home', (
      tester,
    ) async {
      await _pumpMemberShell(tester);

      await tester.tap(find.byKey(const Key('member-notifications-shortcut')));
      await _settleShell(tester);

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('home fallback states still expose the profile shortcut', (
      tester,
    ) async {
      await _pumpMemberShell(tester, userRepository: FakeUserRepository());

      expect(find.byKey(const Key('member-profile-shortcut')), findsOneWidget);
      expect(find.text('GymUnity Member'), findsOneWidget);
    });

    testWidgets('returning to home refreshes the daily streak card', (
      tester,
    ) async {
      final memberRepository = FakeMemberRepository()
        ..homeSummary = MemberHomeSummaryEntity(
          dailyStreak: MemberDailyStreakEntity(
            currentCount: 1,
            lastActivityDate: DateTime(2026, 4, 21),
          ),
        );

      await _pumpMemberShell(tester, memberRepository: memberRepository);

      expect(
        tester
            .widget<Text>(find.byKey(const Key('member-daily-streak-value')))
            .data,
        '1 Day Active',
      );

      memberRepository.homeSummary = MemberHomeSummaryEntity(
        dailyStreak: MemberDailyStreakEntity(
          currentCount: 2,
          lastActivityDate: DateTime(2026, 4, 22),
        ),
      );

      await tester.tap(find.byKey(const Key('member-nav-TAIYO')));
      await _settleShell(tester);
      await tester.tap(find.byKey(const Key('member-nav-HOME')));
      await _settleShell(tester);

      expect(
        tester
            .widget<Text>(find.byKey(const Key('member-daily-streak-value')))
            .data,
        '2 Days Active',
      );
    });

    testWidgets('home shell renders on a phone-sized viewport without errors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildShellApp());
      await _settleShell(tester);

      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('member-daily-streak-card')), findsOneWidget);
    });

    testWidgets(
      'disposing the home shell during an in-flight summary refresh does not throw',
      (tester) async {
        final memberRepository = _DelayedHomeSummaryMemberRepository(
          const Duration(milliseconds: 80),
        );

        await tester.pumpWidget(
          _buildShellApp(memberRepository: memberRepository),
        );
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 120));

        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<void> _pumpMemberShell(
  WidgetTester tester, {
  FakeUserRepository? userRepository,
  FakeNewsRepository? newsRepository,
  FakeMemberRepository? memberRepository,
  AppNavigationStateStore? navigationStateStore,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    _buildShellApp(
      userRepository: userRepository,
      newsRepository: newsRepository,
      memberRepository: memberRepository,
      navigationStateStore: navigationStateStore,
    ),
  );
  await _settleShell(tester);
}

Future<void> _settleShell(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1400));
}

Widget _buildShellApp({
  FakeUserRepository? userRepository,
  FakeNewsRepository? newsRepository,
  FakeMemberRepository? memberRepository,
  AppNavigationStateStore? navigationStateStore,
}) {
  final resolvedUserRepository =
      userRepository ??
      (FakeUserRepository()
        ..profile = const ProfileEntity(
          userId: 'member-1',
          email: 'member@gymunity.com',
          fullName: 'GymUnity Member',
          role: AppRole.member,
          onboardingCompleted: true,
        ));
  final resolvedNewsRepository =
      newsRepository ??
      (FakeNewsRepository()
        ..articles = <NewsArticleEntity>[
          NewsArticleEntity(
            id: 'article-1',
            sourceId: 'source-1',
            sourceName: 'NIH News in Health',
            sourceBaseUrl: 'https://newsinhealth.nih.gov',
            canonicalUrl: 'https://newsinhealth.nih.gov/article-1',
            title: 'Recovery basics for consistent training',
            summary: 'A trusted explainer on sleep, hydration, and recovery.',
            publishedAt: DateTime(2026, 3, 15),
            topicCodes: const <String>['recovery', 'sleep'],
            relevanceReason: 'Matches your goal',
          ),
        ]);
  final resolvedMemberRepository = memberRepository ?? FakeMemberRepository();

  return ProviderScope(
    overrides: <Override>[
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      userRepositoryProvider.overrideWithValue(resolvedUserRepository),
      authCallbackIngressProvider.overrideWithValue(FakeAuthCallbackIngress()),
      storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
      newsRepositoryProvider.overrideWithValue(resolvedNewsRepository),
      coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
      memberRepositoryProvider.overrideWithValue(resolvedMemberRepository),
      nutritionRepositoryProvider.overrideWithValue(FakeNutritionRepository()),
      sellerRepositoryProvider.overrideWithValue(FakeSellerRepository()),
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
      plannerRepositoryProvider.overrideWithValue(FakePlannerRepository()),
      if (navigationStateStore != null)
        appNavigationStateStoreProvider.overrideWithValue(navigationStateStore),
      notificationsProvider.overrideWith(
        (ref) => Stream<List<AppNotificationItem>>.value(
          const <AppNotificationItem>[],
        ),
      ),
      aiPremiumGateProvider.overrideWith(
        (ref) => AsyncValue<AiPremiumGateDecision>.data(
          AiPremiumGateDecision.freeAccess(),
        ),
      ),
    ],
    child: MaterialApp(
      onGenerateRoute: AppRoutes.onGenerateRoute,
      home: const MemberHomeScreen(),
    ),
  );
}

class _SavedTabNavigationStateStore implements AppNavigationStateStore {
  const _SavedTabNavigationStateStore({
    required this.area,
    required this.index,
  });

  final String area;
  final int index;

  @override
  Future<void> clearLastSafeRoute() async {}

  @override
  Future<void> clearUserScopedState() async {}

  @override
  Future<SavedRouteState?> readLastSafeRoute() async => null;

  @override
  Future<int?> readLastTabIndex(String area) async {
    return area == this.area ? index : null;
  }

  @override
  Future<void> saveLastSafeRoute(
    String routeName, {
    Map<String, dynamic>? params,
  }) async {}

  @override
  Future<void> saveLastTabIndex(String area, int index) async {}
}

class _DelayedHomeSummaryMemberRepository extends FakeMemberRepository {
  _DelayedHomeSummaryMemberRepository(this.delay);

  final Duration delay;

  @override
  Future<MemberHomeSummaryEntity> getHomeSummary() async {
    homeSummaryRequests += 1;
    if (homeSummaryError != null) {
      throw homeSummaryError!;
    }
    await Future<void>.delayed(delay);
    return homeSummary;
  }
}
