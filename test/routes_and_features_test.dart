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
import 'package:my_app/features/auth/presentation/screens/login_screen.dart';
import 'package:my_app/features/coach/domain/entities/coach_entity.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/coach/presentation/screens/coach_dashboard_screen.dart';
import 'package:my_app/features/coach/presentation/screens/coach_package_editor_screen.dart';
import 'package:my_app/features/coaches/presentation/screens/subscription_packages_screen.dart';
import 'package:my_app/features/member/presentation/screens/edit_profile_screen.dart';
import 'package:my_app/features/planner/presentation/screens/planner_builder_screen.dart';
import 'package:my_app/features/seller/presentation/screens/seller_dashboard_screen.dart';
import 'package:my_app/features/seller/presentation/screens/seller_product_editor_screen.dart';
import 'package:my_app/features/store/presentation/screens/cart_screen.dart';
import 'package:my_app/features/store/domain/entities/product_entity.dart';
import 'package:my_app/features/store/domain/entities/store_recommendation_entity.dart';
import 'package:my_app/features/store/presentation/screens/store_home_screen.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';

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
      final userRepository = FakeUserRepository()
        ..currentUser = const UserEntity(
          id: 'coach-1',
          email: 'coach@gymunity.com',
        );
      final coachRepository = FakeCoachRepository()
        ..coaches = const <CoachEntity>[
          CoachEntity(
            id: 'coach-1',
            name: 'Coach Alex',
            specialties: <String>['Strength'],
          ),
        ];

      await _pumpScreen(
        tester,
        const CoachDashboardScreen(),
        userRepository: userRepository,
        coachRepository: coachRepository,
      );

      await tester.ensureVisible(find.text('Create Package'));
      await tester.tap(find.text('Create Package'));
      await tester.pumpAndSettle();

      expect(find.byType(CoachPackageEditorScreen), findsOneWidget);
      expect(find.text('Create coaching offer'), findsOneWidget);
    });

    testWidgets('new coach offers are published by default', (tester) async {
      final coachRepository = FakeCoachRepository();

      await _pumpScreen(
        tester,
        const CoachPackageEditorScreen(),
        coachRepository: coachRepository,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Offer title'),
        'Strength accountability',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Price'),
        '250',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Weekly strength coaching with practical programming support.',
      );
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Outcome summary'),
        'Build stronger training habits with a coach-led weekly plan.',
      );

      await tester.tap(find.text('Create offer'));
      await tester.pumpAndSettle();

      expect(
        coachRepository.lastSavedPackagePayload?['visibilityStatus'],
        'published',
      );
      expect(coachRepository.lastSavedPackagePayload?['isActive'], isTrue);
    });

    testWidgets('member request dialog submits structured intake', (
      tester,
    ) async {
      final package = CoachPackageEntity(
        id: 'package-1',
        coachId: 'coach-1',
        title: 'Starter coaching offer',
        description: 'A hands-on coaching relationship.',
        billingCycle: 'monthly',
        price: 199,
        subtitle: 'Accountability-first remote coaching',
        outcomeSummary: 'Build momentum and consistency.',
        durationWeeks: 8,
        sessionsPerWeek: 3,
        includedFeatures: const <String>['Weekly check-ins'],
        checkInFrequency: 'Weekly',
        planPreviewJson: const <String, dynamic>{
          'title': 'Starter Plan',
          'summary': 'A coach-led starter plan.',
          'duration_weeks': 8,
          'level': 'beginner',
          'weekly_structure': <Map<String, dynamic>>[
            <String, dynamic>{
              'week_number': 1,
              'days': <Map<String, dynamic>>[
                <String, dynamic>{
                  'week_number': 1,
                  'day_number': 1,
                  'label': 'Session 1',
                  'focus': 'Strength',
                  'tasks': <Map<String, dynamic>>[],
                },
              ],
            },
          ],
        },
        visibilityStatus: 'published',
        isActive: true,
      );
      final coach = CoachEntity(
        id: 'coach-1',
        name: 'Coach Alex',
        pricingCurrency: 'USD',
        packages: <CoachPackageEntity>[package],
      );
      final coachRepository = FakeCoachRepository()
        ..coaches = <CoachEntity>[coach]
        ..packages = <CoachPackageEntity>[package];

      await _pumpScreen(
        tester,
        SubscriptionPackagesScreen(coach: coach),
        coachRepository: coachRepository,
      );

      await tester.tap(find.text('Start paid checkout'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Lose fat');
      await tester.enterText(fields.at(1), '4');
      await tester.enterText(fields.at(2), '50');
      await tester.enterText(fields.at(3), '1800');
      await tester.enterText(fields.at(4), 'Cairo');
      await tester.enterText(fields.at(5), 'Dumbbells, bands');
      await tester.enterText(fields.at(6), 'Knee discomfort');
      await tester.enterText(fields.at(7), 'I need accountability.');

      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();

      final requested = coachRepository.lastRequestedSubscription;
      expect(requested, isNotNull);
      expect(requested!.intakeSnapshot.goal, 'Lose fat');
      expect(requested.intakeSnapshot.daysPerWeek, 4);
      expect(requested.intakeSnapshot.sessionMinutes, 50);
      expect(requested.intakeSnapshot.budgetEgp, 1800);
      expect(requested.intakeSnapshot.city, 'Cairo');
      expect(requested.intakeSnapshot.equipment, contains('Dumbbells'));
      expect(requested.memberNote, 'I need accountability.');
    });

    testWidgets('coach clients screen approves pending starter plan request', (
      tester,
    ) async {
      final coachRepository = FakeCoachRepository()
        ..subscriptions = const <SubscriptionEntity>[
          SubscriptionEntity(
            id: 'subscription-1',
            memberId: 'member-1',
            coachId: 'coach-1',
            packageId: 'package-1',
            packageTitle: 'Starter coaching offer',
            memberName: 'Member One',
            memberNote: 'Please help me restart.',
            intakeSnapshot: CoachSubscriptionIntakeEntity(
              goal: 'Build consistency',
              experienceLevel: 'beginner',
              daysPerWeek: 3,
              sessionMinutes: 45,
            ),
            status: 'pending_payment',
            amount: 199,
            planName: 'Starter coaching offer',
          ),
        ];

      await _pumpNamedRoute(
        tester,
        AppRoutes.clients,
        coachRepository: coachRepository,
      );
      await tester.pumpAndSettle();

      expect(find.text('Assign starter plan'), findsOneWidget);

      await tester.tap(find.text('Assign starter plan'));
      await tester.pumpAndSettle();

      expect(coachRepository.lastActivatedSubscription?.status, 'active');
      expect(coachRepository.plans, isNotEmpty);
    });

    testWidgets('seller dashboard quick action opens add product screen', (
      tester,
    ) async {
      await _pumpScreen(tester, const SellerDashboardScreen());

      expect(
        find.textContaining('Seller dashboard is steady.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Add Product'));
      await tester.pumpAndSettle();

      expect(find.byType(SellerProductEditorScreen), findsOneWidget);
      expect(find.text('Create Product'), findsOneWidget);
    });

    testWidgets('seller dashboard logout returns to login', (tester) async {
      final authRepository = FakeAuthRepository();

      await _pumpScreen(
        tester,
        const SellerDashboardScreen(),
        authRepository: authRepository,
      );

      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(authRepository.logoutCalls, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SellerDashboardScreen), findsNothing);
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

    testWidgets('store home renders TAIYO recommendations', (tester) async {
      final storeRepository = FakeStoreRepository()
        ..products = const <ProductEntity>[
          ProductEntity(
            id: 'rec-1',
            sellerId: 'seller-1',
            name: 'Resistance Band',
            description: 'Portable training support',
            category: 'Equipment',
            price: 30,
            stockQty: 10,
          ),
        ]
        ..taiyoRecommendations = const StoreRecommendationsEntity(
          status: 'success',
          recommendationType: 'equipment_gap',
          reason: 'TAIYO found a practical training support item.',
          products: <StoreRecommendationProductEntity>[
            StoreRecommendationProductEntity(
              productId: 'rec-1',
              name: 'Resistance Band',
              category: 'Equipment',
              whyRecommended: 'Supports warm-ups and travel workouts.',
              priority: 'high',
              price: 30,
              currency: 'EGP',
            ),
          ],
          disclaimer:
              'Recommendations are based on fitness context, not medical advice.',
        );

      await _pumpScreen(
        tester,
        const StoreHomeScreen(),
        storeRepository: storeRepository,
      );

      expect(find.text('Recommended for you'), findsOneWidget);
      expect(find.text('Resistance Band'), findsWidgets);
      expect(find.textContaining('not medical advice'), findsOneWidget);
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

    testWidgets('AI home planner quick chip opens guided builder', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository();

      await _pumpScreen(
        tester,
        const AiChatHomeScreen(),
        chatRepository: chatRepository,
      );

      await tester.scrollUntilVisible(find.text('Strength plan'), 320);
      await tester.tap(find.text('Strength plan'));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerBuilderScreen), findsOneWidget);
      expect(chatRepository.sessions, isEmpty);
    });

    testWidgets('AI home general quick chip still opens conversation flow', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository();

      await _pumpScreen(
        tester,
        const AiChatHomeScreen(),
        chatRepository: chatRepository,
      );

      await tester.scrollUntilVisible(find.text('Nutrition tips'), 320);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -140));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nutrition tips'));
      await tester.pumpAndSettle();

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.sessions, hasLength(1));
      expect(
        chatRepository.messagesFor(chatRepository.sessions.single.id),
        isNotEmpty,
      );
    });

    testWidgets('AI home planner session row opens guided builder', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository();
      chatRepository.sessions.add(
        ChatSessionEntity(
          id: 'planner-session',
          userId: 'user-1',
          title: 'TAIYO Planner',
          updatedAt: DateTime(2026, 3, 8),
          type: ChatSessionType.planner,
          plannerStatus: 'collecting_info',
        ),
      );

      await _pumpScreen(
        tester,
        const AiChatHomeScreen(),
        chatRepository: chatRepository,
      );

      await tester.scrollUntilVisible(find.text('TAIYO Planner'), 320);
      await tester.tap(find.text('TAIYO Planner'));
      await tester.pumpAndSettle();

      expect(find.byType(PlannerBuilderScreen), findsOneWidget);
      expect(find.byType(AiConversationScreen), findsNothing);
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
      await tester.tap(find.byIcon(Icons.north_rounded));
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
      await tester.tap(find.byIcon(Icons.north_rounded));
      await tester.pump();

      final sendButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.north_rounded),
      );
      expect(sendButton.onPressed, isNull);
      expect(chatRepository.createSessionCalls, 1);
      expect(find.textContaining('TAIYO IS SCULPTING'), findsOneWidget);

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
  FakeAuthRepository? authRepository,
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
        authRepositoryProvider.overrideWithValue(
          authRepository ?? FakeAuthRepository(),
        ),
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
