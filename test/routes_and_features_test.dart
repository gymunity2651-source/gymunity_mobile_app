import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_message_entity.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_session_entity.dart';
import 'package:my_app/features/ai_chat/presentation/screens/ai_conversation_screen.dart';
import 'package:my_app/features/ai_chat/presentation/screens/ai_chat_home_screen.dart';
import 'package:my_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_app/features/auth/presentation/screens/auth_callback_screen.dart';
import 'package:my_app/features/coach/presentation/screens/coach_dashboard_screen.dart';
import 'package:my_app/features/member/presentation/screens/edit_profile_screen.dart';
import 'package:my_app/features/seller/presentation/screens/seller_dashboard_screen.dart';
import 'package:my_app/features/seller/presentation/screens/seller_product_editor_screen.dart';
import 'package:my_app/features/store/presentation/screens/cart_screen.dart';
import 'package:my_app/features/store/domain/entities/product_entity.dart';
import 'package:my_app/features/store/presentation/screens/store_home_screen.dart';
import 'package:my_app/features/planner/domain/entities/planner_entities.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';

import 'test_doubles.dart';

void main() {
  group('Routes and feature wiring', () {
    testWidgets('help support route resolves to functional support screen', (
      tester,
    ) async {
      await _pumpNamedRoute(tester, AppRoutes.helpSupport);
      await tester.pumpAndSettle();

      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.textContaining('Need help with login'), findsOneWidget);
    });

    testWidgets(
      'edit profile route resolves to functional edit profile screen',
      (tester) async {
        final userRepository = FakeUserRepository()
          ..profile = const ProfileEntity(
            userId: 'member-1',
            email: 'member@gymunity.com',
            fullName: 'GymUnity Member',
          );

        await _pumpNamedRoute(
          tester,
          AppRoutes.editProfile,
          userRepository: userRepository,
        );
        await tester.pumpAndSettle();

        expect(find.byType(EditProfileScreen), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);
        expect(find.text('Change Avatar'), findsOneWidget);
      },
    );

    testWidgets(
      'OAuth callback route resolves to callback screen instead of unknown',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
              userRepositoryProvider.overrideWithValue(FakeUserRepository()),
              authCallbackIngressProvider.overrideWithValue(
                FakeAuthCallbackIngress(),
              ),
              googleOAuthTimeoutProvider.overrideWithValue(
                const Duration(milliseconds: 20),
              ),
              googleOAuthPollIntervalProvider.overrideWithValue(
                const Duration(milliseconds: 5),
              ),
            ],
            child: MaterialApp(
              onGenerateRoute: AppRoutes.onGenerateRoute,
              home: Builder(
                builder: (context) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushNamed(context, '/?code=test-auth-code');
                  });
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        await tester.pumpAndSettle();

        expect(find.byType(AuthCallbackScreen), findsOneWidget);
        expect(find.text('Unknown Route'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('coach dashboard quick action opens create package screen', (
      tester,
    ) async {
      await _pumpScreen(tester, const CoachDashboardScreen());

      await tester.ensureVisible(find.text('Create Package'));
      await tester.tap(find.text('Create Package'));
      await tester.pumpAndSettle();

      expect(find.textContaining('coaching packages'), findsOneWidget);
    });

    testWidgets('seller dashboard quick action opens add product screen', (
      tester,
    ) async {
      await _pumpScreen(tester, const SellerDashboardScreen());

      await tester.tap(find.text('Add Product'));
      await tester.pumpAndSettle();

      expect(find.byType(SellerProductEditorScreen), findsOneWidget);
      expect(find.text('Create Product'), findsOneWidget);
    });

    testWidgets('store product add button shows actionable feedback', (
      tester,
    ) async {
      final storeRepository = FakeStoreRepository()
        ..products = const <ProductEntity>[
          ProductEntity(
            id: '1',
            sellerId: 'seller-1',
            name: 'Test Product',
            description: 'Real product description',
            category: 'SUPPLEMENTS',
            price: 49.99,
            stockQty: 8,
          ),
        ];

      await _pumpScreen(
        tester,
        const StoreHomeScreen(),
        storeRepository: storeRepository,
      );

      await tester.ensureVisible(find.text('Add to cart').first);
      await tester.tap(find.text('Add to cart').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('added to your cart'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('cart route resolves to functional cart screen', (
      tester,
    ) async {
      await _pumpNamedRoute(
        tester,
        AppRoutes.cart,
        storeRepository: FakeStoreRepository(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CartScreen), findsOneWidget);
      expect(
        find.textContaining('Your cart is empty. Add products'),
        findsOneWidget,
      );
    });

    testWidgets('AI home quick chip opens conversation flow', (tester) async {
      final chatRepository = FakeChatRepository();

      await _pumpScreen(
        tester,
        const AiChatHomeScreen(),
        chatRepository: chatRepository,
      );

      await tester.tap(find.text('Strength plan'));
      await tester.pumpAndSettle();

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.sessions, hasLength(1));
      expect(
        chatRepository.messagesFor(chatRepository.sessions.single.id),
        isNotEmpty,
      );
    });

    testWidgets('planner missing-field helpers prefill the composer', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository();
      chatRepository.sessions.add(
        ChatSessionEntity(
          id: 'planner-session',
          userId: 'user-1',
          title: 'AI Planner',
          updatedAt: DateTime(2026, 3, 8),
          type: ChatSessionType.planner,
          plannerStatus: 'collecting_info',
        ),
      );

      final plannerRepository = FakePlannerRepository()
        ..latestDraft = PlannerDraftEntity(
          id: 'draft-1',
          userId: 'user-1',
          sessionId: 'planner-session',
          status: 'collecting_info',
          assistantMessage: 'Need a few details before building the plan.',
          missingFields: const <String>[
            'days_per_week',
            'session_minutes',
            'equipment',
          ],
          createdAt: DateTime(2026, 3, 8),
          updatedAt: DateTime(2026, 3, 8),
        );

      await _pumpScreen(
        tester,
        const AiConversationScreen(sessionId: 'planner-session'),
        chatRepository: chatRepository,
        plannerRepository: plannerRepository,
      );

      expect(find.text('Answer details'), findsOneWidget);

      await tester.tap(find.text('days per week').first);
      await tester.pump();

      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, contains('Days per week: '));

      await tester.tap(find.text('Answer details'));
      await tester.pump();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, contains('Session minutes: '));
      expect(textField.controller?.text, contains('Equipment available: '));
    });

    testWidgets('conversation send shows the streamed AI reply', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository();

      await _pumpScreen(
        tester,
        const AiConversationScreen(),
        chatRepository: chatRepository,
      );

      await tester.enterText(find.byType(TextField), 'Test recovery question');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Handled: Test recovery question'),
        findsOneWidget,
      );
    });

    testWidgets('conversation keeps messages ordered from top to bottom', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository();
      chatRepository.sessions.add(
        ChatSessionEntity(
          id: 'general-session',
          userId: 'user-1',
          title: 'General AI',
          updatedAt: DateTime(2026, 3, 8),
        ),
      );
      chatRepository.replaceMessages('general-session', <ChatMessageEntity>[
        ChatMessageEntity(
          id: 'second-message',
          sessionId: 'general-session',
          sender: 'user',
          content: 'Second message',
          createdAt: DateTime(2026, 3, 8, 12, 5),
        ),
        ChatMessageEntity(
          id: 'first-message',
          sessionId: 'general-session',
          sender: 'user',
          content: 'First message',
          createdAt: DateTime(2026, 3, 8, 12, 0),
        ),
      ]);

      await _pumpScreen(
        tester,
        const AiConversationScreen(sessionId: 'general-session'),
        chatRepository: chatRepository,
      );

      expect(
        tester.getTopLeft(find.text('First message')).dy,
        lessThan(tester.getTopLeft(find.text('Second message')).dy),
      );
    });

    testWidgets('conversation locks send while the first request is starting', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository()
        ..createSessionDelay = const Duration(milliseconds: 200)
        ..sendMessageDelay = const Duration(milliseconds: 200);

      await _pumpScreen(
        tester,
        const AiConversationScreen(),
        chatRepository: chatRepository,
      );

      await tester.enterText(find.byType(TextField), 'Need a quick workout');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      final sendButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(sendButton.onPressed, isNull);
      expect(chatRepository.createSessionCalls, 1);
      expect(find.text('AI IS THINKING'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(chatRepository.createSessionCalls, 1);
      expect(chatRepository.sendMessageCalls, 1);
      expect(
        find.textContaining('Handled: Need a quick workout'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpNamedRoute(
  WidgetTester tester,
  String routeName, {
  FakeUserRepository? userRepository,
  FakeStoreRepository? storeRepository,
  FakeCoachRepository? coachRepository,
  FakeMemberRepository? memberRepository,
  FakeSellerRepository? sellerRepository,
  FakeNewsRepository? newsRepository,
  FakeChatRepository? chatRepository,
  FakePlannerRepository? plannerRepository,
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
        storeRepositoryProvider.overrideWithValue(
          storeRepository ?? FakeStoreRepository(),
        ),
        newsRepositoryProvider.overrideWithValue(
          newsRepository ?? FakeNewsRepository(),
        ),
        coachRepositoryProvider.overrideWithValue(
          coachRepository ?? FakeCoachRepository(),
        ),
        memberRepositoryProvider.overrideWithValue(
          memberRepository ?? FakeMemberRepository(),
        ),
        sellerRepositoryProvider.overrideWithValue(
          sellerRepository ?? FakeSellerRepository(),
        ),
        chatRepositoryProvider.overrideWithValue(
          chatRepository ?? FakeChatRepository(),
        ),
        plannerRepositoryProvider.overrideWithValue(
          plannerRepository ?? FakePlannerRepository(),
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
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  FakeUserRepository? userRepository,
  FakeStoreRepository? storeRepository,
  FakeCoachRepository? coachRepository,
  FakeMemberRepository? memberRepository,
  FakeSellerRepository? sellerRepository,
  FakeNewsRepository? newsRepository,
  FakeChatRepository? chatRepository,
  FakePlannerRepository? plannerRepository,
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
        storeRepositoryProvider.overrideWithValue(
          storeRepository ?? FakeStoreRepository(),
        ),
        newsRepositoryProvider.overrideWithValue(
          newsRepository ?? FakeNewsRepository(),
        ),
        coachRepositoryProvider.overrideWithValue(
          coachRepository ?? FakeCoachRepository(),
        ),
        memberRepositoryProvider.overrideWithValue(
          memberRepository ?? FakeMemberRepository(),
        ),
        sellerRepositoryProvider.overrideWithValue(
          sellerRepository ?? FakeSellerRepository(),
        ),
        chatRepositoryProvider.overrideWithValue(
          chatRepository ?? FakeChatRepository(),
        ),
        plannerRepositoryProvider.overrideWithValue(
          plannerRepository ?? FakePlannerRepository(),
        ),
      ],
      child: MaterialApp(
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
