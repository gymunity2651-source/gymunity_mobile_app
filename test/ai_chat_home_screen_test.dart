import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_session_entity.dart';
import 'package:my_app/features/ai_chat/presentation/screens/ai_chat_home_screen.dart';
import 'package:my_app/features/ai_chat/presentation/screens/ai_conversation_screen.dart';
import 'package:my_app/features/monetization/presentation/providers/monetization_providers.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';

import 'test_doubles.dart';

void main() {
  group('TAIYO home', () {
    testWidgets('renders the editorial TAIYO home without the legacy FAB', (
      tester,
    ) async {
      await _pumpTaiyoHome(tester);

      expect(find.text('TAIYO'), findsOneWidget);
      expect(find.text('INTELLIGENCE'), findsOneWidget);
      expect(find.textContaining('Your Personal'), findsOneWidget);
      expect(find.textContaining('Sanctuary'), findsOneWidget);
      await _scrollUntilVisible(tester, find.text('Quick Actions'));
      expect(find.text('Quick Actions'), findsOneWidget);
      await _scrollUntilVisible(tester, find.textContaining('Recent TAIYO'));
      expect(find.textContaining('Recent TAIYO'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('hero build button starts planner conversation', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository();
      await _pumpTaiyoHome(tester, chatRepository: chatRepository);

      await tester.tap(find.byKey(const Key('taiyo-hero-build-button')));
      await _pumpTaiyoFrames(tester);

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.sessions, hasLength(1));
      expect(chatRepository.sessions.single.type, ChatSessionType.planner);
      expect(
        chatRepository.messagesFor(chatRepository.sessions.single.id),
        isNotEmpty,
      );
    });

    testWidgets('hero chat button opens a general session flow', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository();
      await _pumpTaiyoHome(tester, chatRepository: chatRepository);

      await tester.tap(find.byKey(const Key('taiyo-hero-chat-button')));
      await _pumpTaiyoFrames(tester);

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
      await _pumpTaiyoFrames(tester);

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.sessions.single.type, ChatSessionType.planner);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await _pumpTaiyoFrames(tester);

      await tester.ensureVisible(
        find.byKey(const Key('taiyo-open-chat-button')),
      );
      await tester.tap(find.byKey(const Key('taiyo-open-chat-button')));
      await _pumpTaiyoFrames(tester);

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.sessions, hasLength(2));
      expect(chatRepository.sessions.last.type, ChatSessionType.general);
    });

    testWidgets(
      'recent planner sessions show derived metadata and reopen conversation',
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
        await _pumpTaiyoFrames(tester);

        expect(find.byType(AiConversationScreen), findsOneWidget);
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
      await _pumpTaiyoFrames(tester);

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.createSessionCalls, 0);
    });
  });
}

FakeUserRepository _authenticatedMemberRepository(
  FakeUserRepository? provided,
) {
  final repository = provided ?? FakeUserRepository();
  repository.currentUser ??= const UserEntity(
    id: 'user-1',
    email: 'member@gymunity.test',
  );
  repository.profile ??= const ProfileEntity(
    userId: 'user-1',
    email: 'member@gymunity.test',
    fullName: 'Member One',
    role: AppRole.member,
    onboardingCompleted: true,
  );
  return repository;
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
          _authenticatedMemberRepository(userRepository),
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
  await _pumpTaiyoFrames(tester);
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
          _authenticatedMemberRepository(userRepository),
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
  await _pumpTaiyoFrames(tester);
}

Future<void> _pumpTaiyoFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}
