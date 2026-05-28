import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/ai_coach/presentation/screens/ai_coach_home_screen.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/coaches/presentation/screens/coaches_screen.dart';
import 'package:my_app/features/member/presentation/screens/member_profile_screen.dart';
import 'package:my_app/features/news/domain/entities/news_article.dart';
import 'package:my_app/features/news/presentation/screens/news_feed_screen.dart';
import 'package:my_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';

import 'test_doubles.dart';

void main() {
  group('Member shell phone smoke', () {
    testWidgets('TAIYO coach screen', (tester) async {
      await _pumpPhoneScreen(tester, const AiCoachHomeScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('coaches screen', (tester) async {
      await _pumpPhoneScreen(tester, const CoachesScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('news screen', (tester) async {
      await _pumpPhoneScreen(tester, const NewsFeedScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('profile screen', (tester) async {
      await _pumpPhoneScreen(tester, const MemberProfileScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('profile keeps messages separate from notification alerts', (
      tester,
    ) async {
      await _pumpPhoneScreen(
        tester,
        const MemberProfileScreen(),
        overrides: <Override>[
          notificationsProvider.overrideWith(
            (ref) => Stream<List<AppNotificationItem>>.value(
              const <AppNotificationItem>[
                AppNotificationItem(
                  id: 'notification-1',
                  title: 'Checkout started',
                  body: 'Payment is pending.',
                  category: NotificationCategory.coaching,
                  timeLabel: 'Just now',
                ),
                AppNotificationItem(
                  id: 'notification-2',
                  title: 'System update',
                  body: 'Welcome back.',
                  category: NotificationCategory.system,
                  timeLabel: '1h ago',
                ),
              ],
            ),
          ),
        ],
      );

      await tester.dragUntilVisible(
        find.text('Messages'),
        find.byType(ListView),
        const Offset(0, -300),
        maxIteration: 8,
      );
      await tester.pumpAndSettle();

      expect(find.text('No active coaching thread'), findsOneWidget);
      expect(find.text('2 unread alerts'), findsOneWidget);
      expect(find.text('2 new notifications'), findsNothing);
    });

    testWidgets('profile labels failed coaching checkout as attention needed', (
      tester,
    ) async {
      final memberRepository = FakeMemberRepository()
        ..subscriptions = const <SubscriptionEntity>[
          SubscriptionEntity(
            id: 'sub-failed',
            memberId: 'member-1',
            coachId: 'coach-1',
            status: 'checkout_pending',
            checkoutStatus: 'failed',
            paymentGateway: 'paymob',
            amount: 700,
            planName: 'good deal',
          ),
        ];

      await _pumpPhoneScreen(
        tester,
        const MemberProfileScreen(),
        memberRepository: memberRepository,
      );

      await tester.dragUntilVisible(
        find.text('My Coaching'),
        find.byType(ListView),
        const Offset(0, -300),
        maxIteration: 4,
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment needs attention'), findsOneWidget);
      expect(find.text('1 active program'), findsNothing);
    });
  });
}

Future<void> _pumpPhoneScreen(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const <Override>[],
  FakeMemberRepository? memberRepository,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final userRepository = FakeUserRepository()
    ..profile = const ProfileEntity(
      userId: 'member-1',
      email: 'member@gymunity.com',
      fullName: 'GymUnity Member',
      role: AppRole.member,
      onboardingCompleted: true,
    );

  final newsRepository = FakeNewsRepository()
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
    ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        userRepositoryProvider.overrideWithValue(userRepository),
        authCallbackIngressProvider.overrideWithValue(
          FakeAuthCallbackIngress(),
        ),
        storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
        newsRepositoryProvider.overrideWithValue(newsRepository),
        coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        memberRepositoryProvider.overrideWithValue(
          memberRepository ?? FakeMemberRepository(),
        ),
        sellerRepositoryProvider.overrideWithValue(FakeSellerRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        plannerRepositoryProvider.overrideWithValue(FakePlannerRepository()),
        ...overrides,
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}
