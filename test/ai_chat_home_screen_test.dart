import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_session_entity.dart';
import 'package:my_app/features/ai_chat/presentation/screens/ai_chat_home_screen.dart';
import 'package:my_app/features/ai_chat/presentation/screens/ai_conversation_screen.dart';
import 'package:my_app/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:my_app/features/planner/presentation/screens/planner_builder_screen.dart';

import 'test_doubles.dart';

void main() {
  group('TAIYO home', () {
    testWidgets('renders the editorial AI home without the legacy FAB', (
      tester,
    ) async {
      await _pumpTaiyoHome(tester);

      expect(find.text('TAIYO'), findsOneWidget);
      expect(find.text('INTELLIGENCE'), findsOneWidget);
      expect(find.textContaining('Your Personal'), findsOneWidget);
      expect(find.textContaining('Sanctuary'), findsOneWidget);
      await tester.ensureVisible(find.text('Quick Actions'));
      expect(find.text('Quick Actions'), findsOneWidget);
      await _scrollUntilVisible(tester, find.textContaining('Recent TAIYO'));
      expect(find.textContaining('Recent TAIYO'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('hero build button opens the planner route', (tester) async {
      await _pumpTaiyoHome(tester);

      await tester.tap(find.byKey(const Key('taiyo-hero-build-button')));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerBuilderScreen), findsOneWidget);
    });

    testWidgets('hero chat button opens a general session flow', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository();
      await _pumpTaiyoHome(tester, chatRepository: chatRepository);

      await tester.tap(find.byKey(const Key('taiyo-hero-chat-button')));
      await tester.pumpAndSettle();

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.sessions, hasLength(1));
      expect(chatRepository.sessions.single.type, ChatSessionType.general);
    });

    testWidgets('ai chat home route resolves to the TAIYO home screen', (
      tester,
    ) async {
      await _pumpNamedTaiyoRoute(tester, AppRoutes.aiChatHome);

      expect(find.byType(AiChatHomeScreen), findsOneWidget);
      expect(find.byKey(const Key('taiyo-hero-build-button')), findsOneWidget);
      expect(find.byKey(const Key('taiyo-hero-chat-button')), findsOneWidget);
    });

    testWidgets('secondary builder and chat cards still route correctly', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository();
      await _pumpTaiyoHome(tester, chatRepository: chatRepository);

      await tester.ensureVisible(
        find.byKey(const Key('taiyo-open-builder-button')),
      );
      await tester.tap(find.byKey(const Key('taiyo-open-builder-button')));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerBuilderScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('taiyo-open-chat-button')),
      );
      await tester.tap(find.byKey(const Key('taiyo-open-chat-button')));
      await tester.pumpAndSettle();

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.sessions, hasLength(1));
    });

    testWidgets(
      'recent planner sessions show derived metadata and reopen builder',
      (tester) async {
        final now = DateTime.now();
        final chatRepository = FakeChatRepository()
          ..sessions.add(
            ChatSessionEntity(
              id: 'planner-session',
              userId: 'user-1',
              title: 'Morning Clarity',
              updatedAt: now,
              type: ChatSessionType.planner,
              plannerStatus: 'collecting_info',
              plannerProfileJson: const <String, dynamic>{
                'session_minutes': 45,
              },
            ),
          );

        await _pumpTaiyoHome(tester, chatRepository: chatRepository);

        await _scrollUntilVisible(tester, find.text('Morning Clarity'));
        expect(find.text('45 min'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);

        await tester.tap(find.text('Morning Clarity'));
        await tester.pumpAndSettle();

        expect(find.byType(PlannerBuilderScreen), findsOneWidget);
      },
    );

    testWidgets('recent general sessions open the saved conversation', (
      tester,
    ) async {
      final now = DateTime.now();
      final chatRepository = FakeChatRepository()
        ..sessions.add(
          ChatSessionEntity(
            id: 'general-session',
            userId: 'user-1',
            title: 'Deep Release',
            updatedAt: now.subtract(const Duration(days: 1)),
            type: ChatSessionType.general,
          ),
        );

      await _pumpTaiyoHome(tester, chatRepository: chatRepository);

      await _scrollUntilVisible(tester, find.text('Deep Release'));
      expect(find.text('Yesterday'), findsOneWidget);

      await tester.tap(find.text('Deep Release'));
      await tester.pumpAndSettle();

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.createSessionCalls, 0);
    });
  });
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    320,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _pumpNamedTaiyoRoute(
  WidgetTester tester,
  String routeName, {
  FakeChatRepository? chatRepository,
  FakeUserRepository? userRepository,
  FakeMemberRepository? memberRepository,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        userRepositoryProvider.overrideWithValue(
          userRepository ?? FakeUserRepository(),
        ),
        authCallbackIngressProvider.overrideWithValue(
          FakeAuthCallbackIngress(),
        ),
        storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
        newsRepositoryProvider.overrideWithValue(FakeNewsRepository()),
        coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        memberRepositoryProvider.overrideWithValue(
          memberRepository ?? FakeMemberRepository(),
        ),
        sellerRepositoryProvider.overrideWithValue(FakeSellerRepository()),
        chatRepositoryProvider.overrideWithValue(
          chatRepository ?? FakeChatRepository(),
        ),
        plannerRepositoryProvider.overrideWithValue(FakePlannerRepository()),
        aiPremiumGateProvider.overrideWith(
          (ref) => AsyncValue<AiPremiumGateDecision>.data(
            AiPremiumGateDecision.freeAccess(),
          ),
        ),
      ],
      child: MaterialApp(
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushNamed(context, routeName);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTaiyoHome(
  WidgetTester tester, {
  FakeChatRepository? chatRepository,
  FakeUserRepository? userRepository,
  FakeMemberRepository? memberRepository,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        userRepositoryProvider.overrideWithValue(
          userRepository ?? FakeUserRepository(),
        ),
        authCallbackIngressProvider.overrideWithValue(
          FakeAuthCallbackIngress(),
        ),
        storeRepositoryProvider.overrideWithValue(FakeStoreRepository()),
        newsRepositoryProvider.overrideWithValue(FakeNewsRepository()),
        coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        memberRepositoryProvider.overrideWithValue(
          memberRepository ?? FakeMemberRepository(),
        ),
        sellerRepositoryProvider.overrideWithValue(FakeSellerRepository()),
        chatRepositoryProvider.overrideWithValue(
          chatRepository ?? FakeChatRepository(),
        ),
        plannerRepositoryProvider.overrideWithValue(FakePlannerRepository()),
        aiPremiumGateProvider.overrideWith(
          (ref) => AsyncValue<AiPremiumGateDecision>.data(
            AiPremiumGateDecision.freeAccess(),
          ),
        ),
      ],
      child: MaterialApp(
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: const AiChatHomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
