import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/auth/logout_coordinator.dart';
import 'package:my_app/core/auth/logout_providers.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/error/app_failure.dart';
import 'package:my_app/core/navigation/app_navigator.dart';
import 'package:my_app/core/routing/route_guard_policy.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_message_entity.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_session_entity.dart';
import 'package:my_app/features/ai_chat/presentation/providers/chat_providers.dart';
import 'package:my_app/features/ai_chat/presentation/screens/ai_conversation_screen.dart';
import 'package:my_app/features/ai_chat/presentation/screens/ai_chat_home_screen.dart';
import 'package:my_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_app/features/auth/presentation/screens/auth_callback_screen.dart';
import 'package:my_app/features/coach/domain/entities/coach_entity.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/coach/presentation/screens/coach_dashboard_screen.dart';
import 'package:my_app/features/coach/presentation/screens/coach_package_editor_screen.dart';
import 'package:my_app/features/coaches/presentation/screens/subscription_packages_screen.dart';
import 'package:my_app/features/member/domain/entities/member_profile_entity.dart';
import 'package:my_app/features/member/domain/entities/member_progress_entity.dart';
import 'package:my_app/features/member/presentation/screens/edit_profile_screen.dart';
import 'package:my_app/features/planner/presentation/screens/planner_builder_screen.dart';
import 'package:my_app/features/seller/domain/entities/seller_profile_entity.dart';
import 'package:my_app/features/seller/domain/entities/seller_taiyo_entity.dart';
import 'package:my_app/features/seller/presentation/screens/seller_dashboard_screen.dart';
import 'package:my_app/features/seller/presentation/screens/seller_orders_screen.dart';
import 'package:my_app/features/seller/presentation/screens/seller_product_management_screen.dart';
import 'package:my_app/features/seller/presentation/screens/seller_profile_screen.dart';
import 'package:my_app/features/seller/presentation/screens/seller_product_editor_screen.dart';
import 'package:my_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:my_app/features/store/presentation/screens/cart_screen.dart';
import 'package:my_app/features/store/domain/entities/product_entity.dart';
import 'package:my_app/features/store/domain/entities/order_entity.dart';
import 'package:my_app/features/store/domain/entities/store_recommendation_entity.dart';
import 'package:my_app/features/store/presentation/screens/order_details_screen.dart';
import 'package:my_app/features/store/presentation/screens/store_home_screen.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
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

    testWidgets('edit profile presents friendly labels for profile choices', (
      tester,
    ) async {
      final userRepository = FakeUserRepository()
        ..profile = const ProfileEntity(
          userId: 'member-1',
          email: 'member@gymunity.com',
          fullName: 'GymUnity Member',
        );
      final memberRepository = FakeMemberRepository()
        ..profile = const MemberProfileEntity(
          userId: 'member-1',
          goal: 'weight_loss',
          age: 26,
          gender: 'male',
          heightCm: 170,
          currentWeightKg: 82,
          trainingFrequency: '1_2_days_per_week',
          experienceLevel: 'beginner',
        );

      await _pumpNamedRoute(
        tester,
        AppRoutes.editProfile,
        userRepository: userRepository,
        memberRepository: memberRepository,
      );
      await tester.pumpAndSettle();

      expect(find.text('Lose weight'), findsOneWidget);
      expect(find.text('1-2 days per week'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('weight_loss'), findsNothing);
      expect(find.text('1_2_days_per_week'), findsNothing);
    });

    testWidgets('progress measurement dialog validates empty saves', (
      tester,
    ) async {
      final memberRepository = FakeMemberRepository()
        ..weightEntries = <WeightEntryEntity>[
          WeightEntryEntity(
            id: 'weight-1',
            memberId: 'member-1',
            weightKg: 82,
            recordedAt: DateTime(2026, 4, 26),
          ),
        ];

      await _pumpNamedRoute(
        tester,
        AppRoutes.progress,
        memberRepository: memberRepository,
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add measurement'));
      await tester.tap(find.text('Add measurement'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Add Measurement'), findsOneWidget);
      expect(
        find.text('Enter at least one measurement before saving.'),
        findsOneWidget,
      );
      expect(memberRepository.measurements, isEmpty);
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
        )
        ..profile = const ProfileEntity(
          userId: 'coach-1',
          email: 'coach@gymunity.com',
          fullName: 'Coach One',
          role: AppRole.coach,
          onboardingCompleted: true,
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
      final userRepository = FakeUserRepository()
        ..currentUser = const UserEntity(
          id: 'coach-1',
          email: 'coach@gymunity.com',
        )
        ..profile = const ProfileEntity(
          userId: 'coach-1',
          email: 'coach@gymunity.com',
          fullName: 'Coach One',
          role: AppRole.coach,
          onboardingCompleted: true,
        );
      final coachRepository = FakeCoachRepository()
        ..coaches = const <CoachEntity>[
          CoachEntity(
            id: 'coach-1',
            name: 'Coach One',
            specialties: <String>['Strength'],
          ),
        ]
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
        userRepository: userRepository,
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

    testWidgets('seller dashboard opens seller work areas', (tester) async {
      await _pumpScreen(tester, const SellerDashboardScreen());

      await tester.tap(find.text('Inventory').first);
      await tester.pumpAndSettle();
      expect(find.byType(SellerProductManagementScreen), findsOneWidget);

      _popCurrentRoute(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orders').first);
      await tester.pumpAndSettle();
      expect(find.byType(SellerOrdersScreen), findsOneWidget);

      _popCurrentRoute(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      _popCurrentRoute(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byType(SellerProfileScreen), findsOneWidget);
    });

    testWidgets('seller dashboard refreshes counts after inventory changes', (
      tester,
    ) async {
      final sellerRepository = FakeSellerRepository()
        ..products = const <ProductEntity>[
          ProductEntity(
            id: 'product-1',
            sellerId: 'seller-1',
            name: 'Keep Me',
            description: 'Remaining product',
            category: 'supplements',
            price: 50,
            stockQty: 5,
          ),
          ProductEntity(
            id: 'product-2',
            sellerId: 'seller-1',
            name: 'Remove Me',
            description: 'Temporary product',
            category: 'supplements',
            price: 10,
            stockQty: 1,
          ),
        ];

      await _pumpScreen(
        tester,
        const SellerDashboardScreen(),
        sellerRepository: sellerRepository,
      );
      await tester.pumpAndSettle();

      expect(find.text('2 total'), findsOneWidget);

      await tester.tap(find.text('Inventory').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete or Archive'));
      await tester.pumpAndSettle();

      _popCurrentRoute(tester);
      await tester.pumpAndSettle();

      expect(find.text('1 total'), findsOneWidget);
      expect(sellerRepository.deleteOrArchiveProductCalls, 1);
      expect(
        sellerRepository.getDashboardSummaryCalls,
        greaterThanOrEqualTo(2),
      );
      expect(
        sellerRepository.requestSellerCopilotCalls,
        greaterThanOrEqualTo(2),
      );
    });

    testWidgets('seller dashboard refresh reloads dashboard data', (
      tester,
    ) async {
      final sellerRepository = FakeSellerRepository();

      await _pumpScreen(
        tester,
        const SellerDashboardScreen(),
        sellerRepository: sellerRepository,
      );

      final initialProfileCalls = sellerRepository.getSellerProfileCalls;
      final initialSummaryCalls = sellerRepository.getDashboardSummaryCalls;
      final initialOrderCalls = sellerRepository.listOrdersCalls;
      final initialTaiyoCalls = sellerRepository.requestSellerCopilotCalls;

      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 700),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        sellerRepository.getSellerProfileCalls,
        greaterThan(initialProfileCalls),
      );
      expect(
        sellerRepository.getDashboardSummaryCalls,
        greaterThan(initialSummaryCalls),
      );
      expect(sellerRepository.listOrdersCalls, greaterThan(initialOrderCalls));
      expect(
        sellerRepository.requestSellerCopilotCalls,
        greaterThan(initialTaiyoCalls),
      );
    });

    testWidgets('seller dashboard renders TAIYO seller brief details', (
      tester,
    ) async {
      final sellerRepository = FakeSellerRepository()
        ..sellerCopilotBrief = const SellerTaiyoCopilotEntity(
          requestType: 'seller_dashboard_brief',
          status: 'success',
          summary: 'Orders are steady but bands are low.',
          priorityActions: <String>['Restock resistance bands.'],
          productOpportunities: <String>['Bundle bands with protein packs.'],
          riskLevel: 'high',
          recommendedNextStep: 'Review low stock products.',
          confidence: 'high',
        );

      await _pumpScreen(
        tester,
        const SellerDashboardScreen(),
        sellerRepository: sellerRepository,
      );

      expect(find.text('TAIYO SELLER'), findsOneWidget);
      expect(find.text('Orders are steady but bands are low.'), findsOneWidget);
      expect(find.text('Restock resistance bands.'), findsOneWidget);
      expect(find.text('Bundle bands with protein packs.'), findsOneWidget);
      expect(sellerRepository.requestSellerCopilotCalls, 1);
    });

    testWidgets('seller dashboard shows TAIYO error message', (tester) async {
      final sellerRepository = FakeSellerRepository()
        ..sellerCopilotError = const NetworkFailure(
          message: 'TAIYO seller copilot is temporarily unavailable.',
        );

      await _pumpScreen(
        tester,
        const SellerDashboardScreen(),
        sellerRepository: sellerRepository,
      );

      expect(
        find.text('TAIYO seller copilot is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(sellerRepository.requestSellerCopilotCalls, 1);
    });

    testWidgets('seller settings opens store profile for seller role', (
      tester,
    ) async {
      final userRepository = FakeUserRepository()
        ..profile = const ProfileEntity(
          userId: 'seller-1',
          email: 'seller@gymunity.com',
          fullName: 'Seller One',
          role: AppRole.seller,
          onboardingCompleted: true,
        );

      await _pumpNamedRoute(
        tester,
        AppRoutes.settings,
        userRepository: userRepository,
        sellerRepository: FakeSellerRepository(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Store Profile'), findsOneWidget);
      expect(find.text('Edit Profile'), findsNothing);

      await tester.tap(find.text('Store Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(SellerProfileScreen), findsOneWidget);
    });

    testWidgets('seller settings logout returns to welcome', (tester) async {
      final authRepository = FakeAuthRepository();
      final userRepository = FakeUserRepository()
        ..profile = const ProfileEntity(
          userId: 'seller-1',
          email: 'seller@gymunity.com',
          fullName: 'Seller One',
          role: AppRole.seller,
          onboardingCompleted: true,
        );

      await _pumpNamedRoute(
        tester,
        AppRoutes.settings,
        authRepository: authRepository,
        userRepository: userRepository,
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Log Out'));
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log Out').last);
      await tester.pumpAndSettle();

      expect(authRepository.logoutCalls, 1);
      expect(find.text('Log out?'), findsNothing);
    });

    testWidgets(
      'seller store profile saves edited values and normalizes shipping scope',
      (tester) async {
        final sellerRepository = FakeSellerRepository()
          ..profile = const SellerProfileEntity(
            userId: 'seller-1',
            storeName: 'Legacy Store',
            storeDescription: 'Old description',
            primaryCategory: 'equipment',
            shippingScope: 'regional',
            supportEmail: 'old@store.com',
          );

        await _pumpNamedRoute(
          tester,
          AppRoutes.sellerProfile,
          sellerRepository: sellerRepository,
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 'FitGear Pro');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Updated seller store profile.',
        );
        await tester.enterText(
          find.byType(TextFormField).at(2),
          'support@fitgear.test',
        );
        await tester.ensureVisible(find.text('Save Store Profile'));
        await tester.tap(find.text('Save Store Profile'));
        await tester.pumpAndSettle();

        expect(sellerRepository.upsertSellerProfileCalls, 1);
        expect(
          sellerRepository.lastUpsertSellerProfilePayload,
          containsPair('storeName', 'FitGear Pro'),
        );
        expect(
          sellerRepository.lastUpsertSellerProfilePayload,
          containsPair('storeDescription', 'Updated seller store profile.'),
        );
        expect(
          sellerRepository.lastUpsertSellerProfilePayload,
          containsPair('primaryCategory', 'equipment'),
        );
        expect(
          sellerRepository.lastUpsertSellerProfilePayload,
          containsPair('shippingScope', 'national'),
        );
        expect(
          sellerRepository.lastUpsertSellerProfilePayload,
          containsPair('supportEmail', 'support@fitgear.test'),
        );
      },
    );

    testWidgets('seller product editor validates and creates product', (
      tester,
    ) async {
      final sellerRepository = FakeSellerRepository();

      await _pumpNamedRoute(
        tester,
        AppRoutes.addProduct,
        sellerRepository: sellerRepository,
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create Product'));
      await tester.tap(find.text('Create Product'));
      await tester.pumpAndSettle();
      expect(find.text('Title is required.'), findsOneWidget);
      expect(find.text('Description is required.'), findsOneWidget);
      expect(find.text('Category is required.'), findsOneWidget);
      expect(find.text('Enter a valid price.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Protein Pack');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'A starter supplement bundle.',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'supplements');
      await tester.enterText(find.byType(TextFormField).at(3), '49.99');
      await tester.enterText(find.byType(TextFormField).at(4), '12');
      await tester.enterText(find.byType(TextFormField).at(5), '3');
      await tester.ensureVisible(find.text('Create Product'));
      await tester.tap(find.text('Create Product'));
      await tester.pumpAndSettle();

      expect(sellerRepository.saveProductCalls, 1);
      expect(sellerRepository.products, hasLength(1));
      expect(sellerRepository.products.single.name, 'Protein Pack');
      expect(
        sellerRepository.lastSavedProductPayload,
        containsPair('price', 49.99),
      );
      expect(
        sellerRepository.lastSavedProductPayload,
        containsPair('stockQty', 12),
      );
      expect(
        sellerRepository.lastSavedProductPayload,
        containsPair('lowStockThreshold', 3),
      );
    });

    testWidgets('seller inventory lists and edits product', (tester) async {
      final sellerRepository = FakeSellerRepository()
        ..products = const <ProductEntity>[
          ProductEntity(
            id: 'product-1',
            sellerId: 'seller-1',
            name: 'Starter Protein',
            description: 'Original description',
            category: 'supplements',
            price: 25,
            stockQty: 8,
            lowStockThreshold: 2,
          ),
        ];

      await _pumpNamedRoute(
        tester,
        AppRoutes.productManagement,
        sellerRepository: sellerRepository,
      );
      await tester.pumpAndSettle();

      expect(find.text('Starter Protein'), findsOneWidget);
      expect(find.textContaining('Stock: 8'), findsOneWidget);

      await tester.tap(find.text('Starter Protein'));
      await tester.pumpAndSettle();
      expect(find.byType(SellerProductEditorScreen), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Updated Protein',
      );
      await tester.enterText(find.byType(TextFormField).at(3), '31.50');
      await tester.enterText(find.byType(TextFormField).at(4), '14');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(sellerRepository.saveProductCalls, 1);
      expect(
        sellerRepository.lastSavedProductPayload,
        containsPair('productId', 'product-1'),
      );
      expect(sellerRepository.products.single.name, 'Updated Protein');
      expect(sellerRepository.products.single.price, 31.50);
      expect(sellerRepository.products.single.stockQty, 14);
    });

    testWidgets('seller inventory deletes product with no linked orders', (
      tester,
    ) async {
      final sellerRepository = FakeSellerRepository()
        ..products = const <ProductEntity>[
          ProductEntity(
            id: 'product-1',
            sellerId: 'seller-1',
            name: 'Delete Me',
            description: 'Removable product',
            category: 'equipment',
            price: 20,
            stockQty: 5,
          ),
        ];

      await _pumpNamedRoute(
        tester,
        AppRoutes.productManagement,
        sellerRepository: sellerRepository,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete or Archive'));
      await tester.pumpAndSettle();

      expect(sellerRepository.deleteOrArchiveProductCalls, 1);
      expect(sellerRepository.lastDeletedOrArchivedProductId, 'product-1');
      expect(sellerRepository.products, isEmpty);
      expect(find.text('Delete Me was deleted.'), findsOneWidget);
    });

    testWidgets('seller inventory archives product with linked orders', (
      tester,
    ) async {
      final sellerRepository = FakeSellerRepository()
        ..archiveProductsOnDelete = true
        ..products = const <ProductEntity>[
          ProductEntity(
            id: 'product-1',
            sellerId: 'seller-1',
            name: 'Archive Me',
            description: 'Ordered product',
            category: 'equipment',
            price: 20,
            stockQty: 5,
          ),
        ];

      await _pumpNamedRoute(
        tester,
        AppRoutes.productManagement,
        sellerRepository: sellerRepository,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete or Archive'));
      await tester.pumpAndSettle();

      expect(sellerRepository.deleteOrArchiveProductCalls, 1);
      expect(sellerRepository.products, hasLength(1));
      expect(sellerRepository.products.single.isActive, isFalse);
      expect(
        find.text('Archive Me was archived because previous orders exist.'),
        findsOneWidget,
      );
      expect(find.textContaining('Archived'), findsOneWidget);
    });

    testWidgets('seller orders list opens order details in seller mode', (
      tester,
    ) async {
      final sellerRepository = FakeSellerRepository()
        ..orders = <OrderEntity>[_sellerOrder(status: 'pending')];

      await _pumpNamedRoute(
        tester,
        AppRoutes.sellerOrders,
        sellerRepository: sellerRepository,
      );
      await tester.pumpAndSettle();

      expect(find.text('Mona Member'), findsOneWidget);
      expect(find.text('#ORDER-12'), findsOneWidget);
      expect(find.textContaining('2 items'), findsOneWidget);
      expect(find.textContaining('USD 89.50'), findsWidgets);

      await tester.tap(find.text('Mona Member'));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailsScreen), findsOneWidget);
      expect(find.text('Buyer'), findsOneWidget);
      expect(find.text('Mona Member'), findsWidgets);
      expect(find.text('Update Status'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Protein Pack'), findsOneWidget);
      expect(find.text('Shipping'), findsOneWidget);
      expect(find.textContaining('Cairo'), findsOneWidget);
    });

    testWidgets('seller order details updates pending order status', (
      tester,
    ) async {
      final sellerRepository = FakeSellerRepository()
        ..orders = <OrderEntity>[_sellerOrder(status: 'pending')];

      await _pumpScreen(
        tester,
        OrderDetailsScreen(
          order: sellerRepository.orders.single,
          sellerMode: true,
        ),
        sellerRepository: sellerRepository,
      );

      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();

      expect(sellerRepository.updateOrderStatusCalls, 1);
      expect(
        sellerRepository.lastOrderStatusUpdatePayload,
        containsPair('orderId', 'order-12345678'),
      );
      expect(
        sellerRepository.lastOrderStatusUpdatePayload,
        containsPair('newStatus', 'paid'),
      );
      expect(sellerRepository.orders.single.status, 'paid');
      expect(find.text('Order marked as paid.'), findsOneWidget);
      expect(find.text('Processing'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('seller delivered order has no status actions', (tester) async {
      final sellerRepository = FakeSellerRepository()
        ..orders = <OrderEntity>[_sellerOrder(status: 'delivered')];

      await _pumpScreen(
        tester,
        OrderDetailsScreen(
          order: sellerRepository.orders.single,
          sellerMode: true,
        ),
        sellerRepository: sellerRepository,
      );

      expect(find.text('Delivered'), findsWidgets);
      expect(find.text('Update Status'), findsNothing);
      expect(find.text('Paid'), findsNothing);
      expect(find.text('Cancelled'), findsNothing);
    });

    testWidgets('seller dashboard logout returns to welcome', (tester) async {
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
      expect(find.text('Log out?'), findsNothing);
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

    testWidgets('TAIYO home planner quick chip starts planner conversation', (
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
      await _pumpRouteFrames(tester);

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.sessions, hasLength(1));
      expect(chatRepository.sessions.single.type, ChatSessionType.planner);
      expect(
        chatRepository.messagesFor(chatRepository.sessions.single.id),
        isNotEmpty,
      );
    });

    testWidgets('TAIYO home general quick chip still opens conversation flow', (
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
      await _pumpRouteFrames(tester);
      await tester.tap(find.text('Nutrition tips'));
      await _pumpRouteFrames(tester);

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(chatRepository.sessions, hasLength(1));
      expect(
        chatRepository.messagesFor(chatRepository.sessions.single.id),
        isNotEmpty,
      );
    });

    testWidgets('TAIYO home planner session row opens planner conversation', (
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
      await _pumpRouteFrames(tester);

      expect(find.byType(AiConversationScreen), findsOneWidget);
      expect(find.byType(PlannerBuilderScreen), findsNothing);
      expect(chatRepository.sendMessageCalls, 0);
      expect(chatRepository.messagesFor('planner-session'), isEmpty);
    });

    testWidgets('conversation send shows the streamed TAIYO reply', (
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
      await _pumpRouteFrames(tester);

      expect(
        find.textContaining('Handled: Test recovery question'),
        findsOneWidget,
      );
    });

    testWidgets('saved conversation does not auto-send stale pending prompt', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository();
      chatRepository.sessions.add(
        ChatSessionEntity(
          id: 'saved-session',
          userId: 'user-1',
          title: 'Saved chat',
          updatedAt: DateTime(2026, 3, 8),
        ),
      );

      await _pumpScreen(
        tester,
        const AiConversationScreen(sessionId: 'saved-session'),
        chatRepository: chatRepository,
        pendingChatPrompt: 'stale prompt that must not send',
      );
      await _pumpRouteFrames(tester);

      expect(chatRepository.sendMessageCalls, 0);
      expect(chatRepository.messagesFor('saved-session'), isEmpty);
    });

    testWidgets('conversation shows the user message while reply is pending', (
      tester,
    ) async {
      final chatRepository = FakeChatRepository()
        ..sendMessageDelay = const Duration(milliseconds: 300);

      await _pumpScreen(
        tester,
        const AiConversationScreen(),
        chatRepository: chatRepository,
      );

      await tester.enterText(find.byType(TextField), 'Make it visible now');
      await tester.tap(find.byIcon(Icons.north_rounded));
      await tester.pump();

      expect(find.text('Make it visible now'), findsOneWidget);
      expect(find.textContaining('Handled: Make it visible now'), findsNothing);

      await tester.pump(const Duration(milliseconds: 350));
      await _pumpRouteFrames(tester);

      expect(
        find.textContaining('Handled: Make it visible now'),
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
          title: 'General TAIYO',
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
      await _pumpRouteFrames(tester);

      expect(chatRepository.createSessionCalls, 1);
      expect(chatRepository.sendMessageCalls, 1);
      expect(
        find.textContaining('Handled: Need a quick workout'),
        findsOneWidget,
      );
    });
  });
}

FakeUserRepository _userRepositoryForRoute(
  String routeName,
  FakeUserRepository? provided,
) {
  final repository = provided ?? FakeUserRepository();
  if (!RouteAccessPolicy.shouldGuard(routeName)) {
    return repository;
  }
  return _ensureAuthenticatedRepository(
    repository,
    _defaultRoleForRoute(routeName),
  );
}

FakeUserRepository _userRepositoryForScreen(
  Widget screen,
  FakeUserRepository? provided,
) {
  final role = switch (screen) {
    SellerDashboardScreen() || SellerProfileScreen() => AppRole.seller,
    CoachDashboardScreen() || CoachPackageEditorScreen() => AppRole.coach,
    _ => AppRole.member,
  };
  return _ensureAuthenticatedRepository(provided ?? FakeUserRepository(), role);
}

FakeUserRepository _ensureAuthenticatedRepository(
  FakeUserRepository repository,
  AppRole role,
) {
  if (repository.profileError != null) {
    repository.currentUser ??= const UserEntity(
      id: 'guarded-user',
      email: 'guarded@gymunity.test',
    );
    return repository;
  }

  final userId = repository.profile?.userId ?? '${role.name}-1';
  final email = repository.profile?.email ?? '${role.name}@gymunity.test';
  repository.currentUser ??= UserEntity(id: userId, email: email);
  repository.profile = (repository.profile ??
          ProfileEntity(
            userId: userId,
            email: email,
            fullName: '${role.name} User',
          ))
      .copyWith(
        role: repository.profile?.role ?? role,
        onboardingCompleted: true,
      );
  return repository;
}

AppRole _defaultRoleForRoute(String routeName) {
  final allowedRoles = RouteAccessPolicy.ruleFor(routeName)?.allowedRoles;
  if (allowedRoles == null || allowedRoles.isEmpty) {
    return AppRole.member;
  }
  if (allowedRoles.contains(AppRole.member)) {
    return AppRole.member;
  }
  return allowedRoles.first;
}

class _TestLogoutNavigator implements LogoutNavigator {
  const _TestLogoutNavigator(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  void navigateToWelcomeAndClearStack() {
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.welcome,
        (route) => false,
      );
    });
    binding.scheduleFrame();
  }
}

class _NoopLogoutServiceStopper implements LogoutServiceStopper {
  const _NoopLogoutServiceStopper();

  @override
  Future<void> stopUserScopedServices() async {}
}

Future<void> _pumpNamedRoute(
  WidgetTester tester,
  String routeName, {
  FakeAuthRepository? authRepository,
  FakeUserRepository? userRepository,
  FakeStoreRepository? storeRepository,
  FakeCoachRepository? coachRepository,
  FakeMemberRepository? memberRepository,
  FakeSellerRepository? sellerRepository,
  FakeNewsRepository? newsRepository,
  FakeChatRepository? chatRepository,
  FakePlannerRepository? plannerRepository,
  String? pendingChatPrompt,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appNavigatorKeyProvider.overrideWithValue(navigatorKey),
        logoutCoordinatorProvider.overrideWith(
          (ref) => LogoutCoordinator(
            ref,
            serviceStopper: const _NoopLogoutServiceStopper(),
            navigator: _TestLogoutNavigator(navigatorKey),
          ),
        ),
        logoutNavigatorProvider.overrideWithValue(
          _TestLogoutNavigator(navigatorKey),
        ),
        authRepositoryProvider.overrideWithValue(
          authRepository ?? FakeAuthRepository(),
        ),
        userRepositoryProvider.overrideWithValue(
          _userRepositoryForRoute(routeName, userRepository),
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
        if (pendingChatPrompt != null)
          pendingChatPromptProvider.overrideWith((ref) => pendingChatPrompt),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
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
  String? pendingChatPrompt,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        appNavigatorKeyProvider.overrideWithValue(navigatorKey),
        logoutCoordinatorProvider.overrideWith(
          (ref) => LogoutCoordinator(
            ref,
            serviceStopper: const _NoopLogoutServiceStopper(),
            navigator: _TestLogoutNavigator(navigatorKey),
          ),
        ),
        logoutNavigatorProvider.overrideWithValue(
          _TestLogoutNavigator(navigatorKey),
        ),
        authRepositoryProvider.overrideWithValue(
          authRepository ?? FakeAuthRepository(),
        ),
        userRepositoryProvider.overrideWithValue(
          _userRepositoryForScreen(screen, userRepository),
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
        if (pendingChatPrompt != null)
          pendingChatPromptProvider.overrideWith((ref) => pendingChatPrompt),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: screen,
      ),
    ),
  );
  await _pumpRouteFrames(tester);
}

Future<void> _pumpRouteFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void _popCurrentRoute(WidgetTester tester) {
  Navigator.of(tester.element(find.byType(Navigator))).pop();
}

OrderEntity _sellerOrder({required String status}) {
  return OrderEntity(
    id: 'order-12345678',
    memberId: 'member-1',
    sellerId: 'seller-1',
    status: status,
    totalAmount: 89.50,
    currency: 'USD',
    paymentMethod: 'card',
    memberName: 'Mona Member',
    sellerName: 'FitGear Pro',
    itemCount: 2,
    shippingAddress: const <String, dynamic>{
      'recipient_name': 'Mona Member',
      'phone': '+201000000000',
      'line1': '10 Nile Street',
      'city': 'Cairo',
      'country_code': 'EG',
    },
    items: const <OrderItemEntity>[
      OrderItemEntity(
        id: 'item-1',
        orderId: 'order-12345678',
        productId: 'product-1',
        sellerId: 'seller-1',
        productTitle: 'Protein Pack',
        unitPrice: 44.75,
        quantity: 2,
        lineTotal: 89.50,
      ),
    ],
    statusHistory: <OrderStatusHistoryEntry>[
      OrderStatusHistoryEntry(
        id: 'history-1',
        orderId: 'order-12345678',
        status: status,
        note: 'Order created',
        createdAt: DateTime(2026, 5, 28, 10),
      ),
    ],
    createdAt: DateTime(2026, 5, 28, 9, 30),
  );
}
