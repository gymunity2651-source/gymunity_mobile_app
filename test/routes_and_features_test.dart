import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/ai_chat/presentation/screens/ai_conversation_screen.dart';
import 'package:my_app/features/ai_chat/presentation/screens/ai_chat_home_screen.dart';
import 'package:my_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_app/features/auth/presentation/screens/auth_callback_screen.dart';
import 'package:my_app/features/coach/presentation/screens/coach_dashboard_screen.dart';
import 'package:my_app/features/seller/presentation/screens/seller_dashboard_screen.dart';
import 'package:my_app/features/seller/presentation/screens/seller_product_editor_screen.dart';
import 'package:my_app/features/store/presentation/screens/cart_screen.dart';
import 'package:my_app/features/store/domain/entities/product_entity.dart';
import 'package:my_app/features/store/presentation/screens/store_home_screen.dart';

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
              initialRoute: '/?code=test-auth-code',
            ),
          ),
        );
        await tester.pump();

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

      await tester.tap(find.text('Build a workout plan'));
      await tester.pumpAndSettle();

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.sessions, hasLength(1));
      expect(
        chatRepository.messagesFor(chatRepository.sessions.single.id),
        isNotEmpty,
      );
    });
  });
}

Future<void> _pumpNamedRoute(
  WidgetTester tester,
  String routeName, {
  FakeStoreRepository? storeRepository,
  FakeCoachRepository? coachRepository,
  FakeSellerRepository? sellerRepository,
  FakeChatRepository? chatRepository,
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
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        authCallbackIngressProvider.overrideWithValue(
          FakeAuthCallbackIngress(),
        ),
        storeRepositoryProvider.overrideWithValue(
          storeRepository ?? FakeStoreRepository(),
        ),
        coachRepositoryProvider.overrideWithValue(
          coachRepository ?? FakeCoachRepository(),
        ),
        sellerRepositoryProvider.overrideWithValue(
          sellerRepository ?? FakeSellerRepository(),
        ),
        chatRepositoryProvider.overrideWithValue(
          chatRepository ?? FakeChatRepository(),
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
  FakeStoreRepository? storeRepository,
  FakeCoachRepository? coachRepository,
  FakeSellerRepository? sellerRepository,
  FakeChatRepository? chatRepository,
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
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        authCallbackIngressProvider.overrideWithValue(
          FakeAuthCallbackIngress(),
        ),
        storeRepositoryProvider.overrideWithValue(
          storeRepository ?? FakeStoreRepository(),
        ),
        coachRepositoryProvider.overrideWithValue(
          coachRepository ?? FakeCoachRepository(),
        ),
        sellerRepositoryProvider.overrideWithValue(
          sellerRepository ?? FakeSellerRepository(),
        ),
        chatRepositoryProvider.overrideWithValue(
          chatRepository ?? FakeChatRepository(),
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
