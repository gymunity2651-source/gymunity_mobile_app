import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/coach/domain/entities/coach_entity.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/coach/presentation/screens/coach_client_pipeline_screen.dart';
import 'package:my_app/features/coach_member_insights/presentation/providers/insight_providers.dart';
import 'package:my_app/features/coaches/presentation/screens/coach_details_screen.dart';
import 'package:my_app/features/coaches/presentation/screens/subscription_packages_screen.dart';
import 'package:my_app/features/store/domain/entities/product_entity.dart';
import 'package:my_app/features/store/domain/entities/shipping_address_entity.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';
import 'package:my_app/features/store/presentation/screens/cart_screen.dart';
import 'package:my_app/features/store/presentation/screens/checkout_preview_screen.dart';
import 'package:my_app/features/store/presentation/screens/product_details_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('store routes show unavailable placeholder when flag is off', (
    tester,
  ) async {
    _overrideConfig(enableStorePurchases: false);

    for (final route in <_RouteCase>[
      const _RouteCase(AppRoutes.storeHome),
      const _RouteCase(AppRoutes.productList),
      _RouteCase(AppRoutes.productDetails, _product),
      const _RouteCase(AppRoutes.favorites),
      const _RouteCase(AppRoutes.cart),
      const _RouteCase(AppRoutes.checkout),
      const _RouteCase(AppRoutes.orders),
    ]) {
      await _pumpRoute(tester, route.name, arguments: route.arguments);
      await tester.pumpAndSettle();

      expect(find.text('Store purchases unavailable'), findsOneWidget);
      expect(find.text('Unknown Route'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'coach subscription routes show unavailable placeholder when flag is off',
    (tester) async {
      _overrideConfig(enableCoachSubscriptions: false);

      for (final route in <_RouteCase>[
        const _RouteCase(AppRoutes.coaches),
        _RouteCase(AppRoutes.coachDetails, _coach),
        _RouteCase(AppRoutes.subscriptionPackages, _coach),
        const _RouteCase(AppRoutes.mySubscriptions),
      ]) {
        await _pumpRoute(tester, route.name, arguments: route.arguments);
        await tester.pumpAndSettle();

        expect(find.text('Coach subscriptions unavailable'), findsOneWidget);
        expect(find.text('Unknown Route'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('coach dashboard blocks signed out users', (tester) async {
    _overrideConfig();
    final userRepository = FakeUserRepository();

    await _pumpRoute(
      tester,
      AppRoutes.coachDashboard,
      userRepository: userRepository,
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in required'), findsOneWidget);
    expect(
      find.text('Please sign in to access the Coach workspace.'),
      findsOneWidget,
    );
    expect(find.text('Coach workspace unavailable'), findsNothing);
  });

  testWidgets('coach operator routes block signed out users', (tester) async {
    _overrideConfig();
    final userRepository = FakeUserRepository();

    for (final route in _coachOperatorRoutes) {
      await _pumpRoute(
        tester,
        route.name,
        arguments: route.arguments,
        userRepository: userRepository,
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in required'), findsOneWidget);
      expect(find.text('Unknown Route'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('coach dashboard blocks member users', (tester) async {
    _overrideConfig();
    final userRepository = _userRepositoryForRole(AppRole.member);

    await _pumpRoute(
      tester,
      AppRoutes.coachDashboard,
      userRepository: userRepository,
    );
    await tester.pumpAndSettle();

    expect(find.text('Coach access required'), findsOneWidget);
    expect(
      find.text('This workspace is only available for coach accounts.'),
      findsOneWidget,
    );
  });

  testWidgets('coach clients route blocks member users', (tester) async {
    _overrideConfig();
    final userRepository = _userRepositoryForRole(AppRole.member);

    await _pumpRoute(
      tester,
      AppRoutes.clients,
      userRepository: userRepository,
      coachRepository: FakeCoachRepository(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coach access required'), findsOneWidget);
    expect(find.text('Client pipeline'), findsNothing);
  });

  testWidgets('coach client workspace route blocks member users', (
    tester,
  ) async {
    _overrideConfig();
    final userRepository = _userRepositoryForRole(AppRole.member);

    await _pumpRoute(
      tester,
      AppRoutes.coachClientWorkspace,
      arguments: const CoachClientWorkspaceArgs(subscriptionId: 'sub-1'),
      userRepository: userRepository,
      coachRepository: FakeCoachRepository(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coach access required'), findsOneWidget);
    expect(find.text('Client workspace'), findsNothing);
  });

  testWidgets('coach dashboard blocks incomplete coach setup', (tester) async {
    _overrideConfig();
    final userRepository = _userRepositoryForRole(
      AppRole.coach,
      onboardingCompleted: false,
    );

    await _pumpRoute(
      tester,
      AppRoutes.coachDashboard,
      userRepository: userRepository,
    );
    await tester.pumpAndSettle();

    expect(find.text('Complete coach setup'), findsOneWidget);
    expect(
      find.text('Finish your coach profile before accessing your workspace.'),
      findsOneWidget,
    );
  });

  testWidgets('completed coach can access dashboard', (tester) async {
    _overrideConfig();
    final userRepository = _userRepositoryForRole(AppRole.coach);

    await _pumpRoute(
      tester,
      AppRoutes.coachDashboard,
      userRepository: userRepository,
      coachRepository: FakeCoachRepository(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Sign in required'), findsNothing);
    expect(find.text('Coach access required'), findsNothing);
  });

  testWidgets('coach dashboard blocks when coach workspace flag is off', (
    tester,
  ) async {
    _overrideConfig(enableCoachSubscriptions: false);
    final userRepository = _userRepositoryForRole(AppRole.coach);

    await _pumpRoute(
      tester,
      AppRoutes.coachDashboard,
      userRepository: userRepository,
      coachRepository: FakeCoachRepository(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coach workspace unavailable'), findsOneWidget);
    expect(
      find.text('Coach features are currently unavailable.'),
      findsOneWidget,
    );
  });

  testWidgets('active coaching workspace routes remain available', (
    tester,
  ) async {
    _overrideConfig(enableCoachSubscriptions: false);
    final repo = FakeMemberRepository()
      ..subscriptions = const <SubscriptionEntity>[
        SubscriptionEntity(
          id: 'subscription-1',
          memberId: 'member-1',
          coachId: 'coach-1',
          coachName: 'Coach Alex',
          packageTitle: 'Starter Coaching',
          status: 'active',
          checkoutStatus: 'paid',
          amount: 200,
          planName: 'Starter',
          threadId: 'thread-1',
        ),
      ];

    await _pumpRoute(
      tester,
      AppRoutes.myCoach,
      arguments: 'subscription-1',
      memberRepository: repo,
    );
    await tester.pumpAndSettle();
    expect(find.text('Coach subscriptions unavailable'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpRoute(
      tester,
      AppRoutes.memberCoachSessions,
      arguments: 'subscription-1',
      memberRepository: repo,
    );
    await tester.pumpAndSettle();
    expect(find.text('Coach subscriptions unavailable'), findsNothing);
  });

  testWidgets('product details disables add to cart when store flag is off', (
    tester,
  ) async {
    _overrideConfig(enableStorePurchases: false);
    final storeRepository = FakeStoreRepository()
      ..products = const <ProductEntity>[_product];

    await _pumpScreen(
      tester,
      const ProductDetailsScreen(product: _product),
      storeRepository: storeRepository,
    );

    expect(
      find.text('Store purchases are currently unavailable.'),
      findsOneWidget,
    );
    expect(find.text('Add to cart'), findsNothing);
    expect(storeRepository.addToCartCalls, 0);
  });

  testWidgets('cart hides checkout action when store flag is off', (
    tester,
  ) async {
    _overrideConfig(enableStorePurchases: false);
    final storeRepository = FakeStoreRepository()
      ..products = const <ProductEntity>[_product];
    await storeRepository.addToCart(product: _product);
    storeRepository.addToCartCalls = 0;

    await _pumpScreen(
      tester,
      const CartScreen(),
      storeRepository: storeRepository,
    );

    expect(
      find.text('Store purchases are currently unavailable.'),
      findsOneWidget,
    );
    expect(find.text('Proceed to checkout'), findsNothing);
  });

  testWidgets('checkout is unavailable and does not place orders when off', (
    tester,
  ) async {
    _overrideConfig(enableStorePurchases: false);
    final storeRepository = FakeStoreRepository()
      ..products = const <ProductEntity>[_product];
    await storeRepository.addToCart(product: _product);
    await storeRepository.saveShippingAddress(_address);
    storeRepository.placeOrderFromCartCalls = 0;

    await _pumpScreen(
      tester,
      const CheckoutScreen(),
      storeRepository: storeRepository,
    );

    expect(find.text('Store purchases unavailable'), findsOneWidget);
    expect(find.text('Place Order'), findsNothing);
    expect(storeRepository.placeOrderFromCartCalls, 0);
  });

  testWidgets('coach details hides offers when subscriptions flag is off', (
    tester,
  ) async {
    _overrideConfig(enableCoachSubscriptions: false);
    final coachRepository = FakeCoachRepository()
      ..coaches = const <CoachEntity>[_coach]
      ..packages = const <CoachPackageEntity>[_package];

    await _pumpScreen(
      tester,
      const CoachDetailsScreen(coach: _coach),
      coachRepository: coachRepository,
    );

    expect(
      find.text('Coach subscriptions are currently unavailable.'),
      findsOneWidget,
    );
    expect(find.text('View full offers'), findsNothing);
  });

  testWidgets('subscription packages screen is unavailable when flag is off', (
    tester,
  ) async {
    _overrideConfig(enableCoachSubscriptions: false);
    final coachRepository = FakeCoachRepository()
      ..coaches = const <CoachEntity>[_coach]
      ..packages = const <CoachPackageEntity>[_package];

    await _pumpScreen(
      tester,
      const SubscriptionPackagesScreen(coach: _coach),
      coachRepository: coachRepository,
    );

    expect(find.text('Coach subscriptions unavailable'), findsOneWidget);
    expect(find.text('Start paid checkout'), findsNothing);
    expect(find.text('Start secure payment'), findsNothing);
    expect(coachRepository.lastRequestedSubscription, isNull);
  });
}

void _overrideConfig({
  bool enableStorePurchases = true,
  bool enableCoachSubscriptions = true,
}) {
  AppConfig.debugOverrideForTests(
    AppConfig.fromMap(<String, String>{
      'SUPABASE_URL': 'https://example.supabase.co',
      'SUPABASE_ANON_KEY': 'anon',
      'ENABLE_STORE_PURCHASES': enableStorePurchases.toString(),
      'ENABLE_COACH_SUBSCRIPTIONS': enableCoachSubscriptions.toString(),
    }),
  );
  addTearDown(AppConfig.clearDebugOverride);
}

Future<void> _pumpRoute(
  WidgetTester tester,
  String routeName, {
  Object? arguments,
  FakeStoreRepository? storeRepository,
  FakeMemberRepository? memberRepository,
  FakeCoachRepository? coachRepository,
  FakeUserRepository? userRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        if (storeRepository != null)
          storeRepositoryProvider.overrideWithValue(storeRepository),
        if (memberRepository != null)
          memberRepositoryProvider.overrideWithValue(memberRepository),
        if (coachRepository != null)
          coachRepositoryProvider.overrideWithValue(coachRepository),
        if (userRepository != null)
          userRepositoryProvider.overrideWithValue(userRepository),
      ],
      child: MaterialApp(
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushNamed(context, routeName, arguments: arguments);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  FakeStoreRepository? storeRepository,
  FakeCoachRepository? coachRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        if (storeRepository != null)
          storeRepositoryProvider.overrideWithValue(storeRepository),
        if (coachRepository != null)
          coachRepositoryProvider.overrideWithValue(coachRepository),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

class _RouteCase {
  const _RouteCase(this.name, [this.arguments]);

  final String name;
  final Object? arguments;
}

const _coachOperatorRoutes = <_RouteCase>[
  _RouteCase(AppRoutes.coachDashboard),
  _RouteCase(AppRoutes.clients),
  _RouteCase(AppRoutes.coachClientWorkspace, _workspaceArgs),
  _RouteCase(AppRoutes.coachCheckins),
  _RouteCase(AppRoutes.coachCalendar),
  _RouteCase(AppRoutes.coachBilling),
  _RouteCase(AppRoutes.coachProgramLibrary),
  _RouteCase(AppRoutes.coachOnboardingFlows),
  _RouteCase(AppRoutes.coachResources),
  _RouteCase(AppRoutes.packages),
  _RouteCase(AppRoutes.addPackage),
  _RouteCase(AppRoutes.coachProfile),
  _RouteCase(AppRoutes.coachMemberInsights, _insightArgs),
];

const _workspaceArgs = CoachClientWorkspaceArgs(subscriptionId: 'sub-1');

const _insightArgs = InsightDetailArgs(
  memberId: 'member-1',
  subscriptionId: 'sub-1',
  memberName: 'Member One',
);

const _product = ProductEntity(
  id: 'product-1',
  sellerId: 'seller-1',
  name: 'Protein Bar',
  description: 'Test product',
  category: 'Snacks',
  price: 25,
  stockQty: 10,
);

const _package = CoachPackageEntity(
  id: 'package-1',
  coachId: 'coach-1',
  title: 'Starter package',
  description: 'Test package',
  billingCycle: 'monthly',
  price: 200,
);

const _coach = CoachEntity(
  id: 'coach-1',
  name: 'Coach Alex',
  specialties: <String>['Strength'],
  activePackageCount: 1,
  packages: <CoachPackageEntity>[_package],
);

const _address = ShippingAddressEntity(
  id: '',
  userId: 'member-1',
  recipientName: 'Member One',
  phone: '+10000000000',
  line1: '1 Test Street',
  city: 'Cairo',
  stateRegion: 'Cairo',
  postalCode: '12345',
  countryCode: 'EG',
);

FakeUserRepository _userRepositoryForRole(
  AppRole role, {
  bool onboardingCompleted = true,
}) {
  return FakeUserRepository()
    ..currentUser = const UserEntity(id: 'user-1', email: 'user@gymunity.test')
    ..profile = ProfileEntity(
      userId: 'user-1',
      email: 'user@gymunity.test',
      role: role,
      onboardingCompleted: onboardingCompleted,
    );
}
