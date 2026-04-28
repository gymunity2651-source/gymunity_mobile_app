import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/ai_coach/presentation/screens/ai_coach_home_screen.dart';
import 'package:my_app/features/coaches/presentation/screens/coaches_screen.dart';
import 'package:my_app/features/member/presentation/screens/member_profile_screen.dart';
import 'package:my_app/features/news/domain/entities/news_article.dart';
import 'package:my_app/features/news/presentation/screens/news_feed_screen.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';

import 'test_doubles.dart';

void main() {
  group('Member shell phone smoke', () {
    testWidgets('AI coach screen', (tester) async {
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
  });
}

Future<void> _pumpPhoneScreen(WidgetTester tester, Widget child) async {
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
        authCallbackIngressProvider.overrideWithValue(FakeAuthCallbackIngress()),
        storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
        newsRepositoryProvider.overrideWithValue(newsRepository),
        coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        memberRepositoryProvider.overrideWithValue(FakeMemberRepository()),
        sellerRepositoryProvider.overrideWithValue(FakeSellerRepository()),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
        plannerRepositoryProvider.overrideWithValue(FakePlannerRepository()),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}
