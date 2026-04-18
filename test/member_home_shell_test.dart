import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/member/presentation/screens/member_home_screen.dart';
import 'package:my_app/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:my_app/features/news/domain/entities/news_article.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';

import 'test_doubles.dart';

void main() {
  group('Member home shell', () {
    testWidgets(
      'profile tab shows the profile screen instead of home content',
      (tester) async {
        await _pumpMemberShell(tester);

        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();

        expect(find.text('member@gymunity.com'), findsOneWidget);
        expect(find.text('My Coaching'), findsOneWidget);
        expect(find.text('Open my coaching'), findsNothing);
      },
    );

    testWidgets('AI tab remains on the TAIYO home after rebuild', (
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
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI'));
      await tester.pumpAndSettle();

      expect(find.text('TAIYO'), findsOneWidget);

      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('TAIYO'), findsOneWidget);
      expect(find.text('My Coaching'), findsNothing);
    });

    testWidgets('news tab opens the recommended reads feed', (tester) async {
      await _pumpMemberShell(tester);

      await tester.tap(find.text('News'));
      await tester.pumpAndSettle();

      expect(find.text('Recommended Reads'), findsOneWidget);
      expect(
        find.text('Recovery basics for consistent training'),
        findsOneWidget,
      );
    });

    testWidgets('home quick action opens the TAIYO screen', (tester) async {
      await _pumpMemberShell(tester);

      await tester.tap(find.text('Open TAIYO'));
      await tester.pumpAndSettle();

      expect(find.text('TAIYO'), findsOneWidget);
    });

    testWidgets('profile shortcut opens profile from home and coaches', (
      tester,
    ) async {
      await _pumpMemberShell(tester);

      await tester.tap(find.byKey(const Key('member-profile-shortcut')));
      await tester.pumpAndSettle();

      expect(find.text('member@gymunity.com'), findsOneWidget);
      expect(find.text('My Coaching'), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coaches'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('member-profile-shortcut')));
      await tester.pumpAndSettle();

      expect(find.text('member@gymunity.com'), findsOneWidget);
      expect(find.text('My Coaching'), findsOneWidget);
    });

    testWidgets('home fallback states still expose the profile shortcut', (
      tester,
    ) async {
      await _pumpMemberShell(tester, userRepository: FakeUserRepository());

      expect(find.byKey(const Key('member-profile-shortcut')), findsOneWidget);
      expect(find.text('GymUnity Member'), findsOneWidget);
    });
  });
}

Future<void> _pumpMemberShell(
  WidgetTester tester, {
  FakeUserRepository? userRepository,
  FakeNewsRepository? newsRepository,
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
    ),
  );
  await tester.pumpAndSettle();
}

Widget _buildShellApp({
  FakeUserRepository? userRepository,
  FakeNewsRepository? newsRepository,
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

  return ProviderScope(
    overrides: <Override>[
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      userRepositoryProvider.overrideWithValue(resolvedUserRepository),
      authCallbackIngressProvider.overrideWithValue(FakeAuthCallbackIngress()),
      storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
      newsRepositoryProvider.overrideWithValue(resolvedNewsRepository),
      coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
      memberRepositoryProvider.overrideWithValue(FakeMemberRepository()),
      sellerRepositoryProvider.overrideWithValue(FakeSellerRepository()),
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
      plannerRepositoryProvider.overrideWithValue(FakePlannerRepository()),
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
