import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/features/coach/domain/entities/coach_entity.dart';
import 'package:my_app/features/coach/presentation/screens/coach_client_pipeline_screen.dart';
import 'package:my_app/features/coach_member_insights/presentation/providers/insight_providers.dart';
import 'package:my_app/features/member/domain/entities/coaching_engagement_entity.dart';
import 'package:my_app/features/news/domain/entities/news_article.dart';
import 'package:my_app/features/planner/presentation/route_args.dart';
import 'package:my_app/features/store/domain/entities/product_entity.dart';

void main() {
  group('AppRoutes smoke coverage', () {
    test('all configured routes resolve to a MaterialPageRoute', () {
      for (final routeCase in _configuredRoutes) {
        final route = AppRoutes.onGenerateRoute(
          RouteSettings(name: routeCase.name, arguments: routeCase.arguments),
        );

        expect(
          route,
          isA<MaterialPageRoute<dynamic>>(),
          reason: '${routeCase.name} should resolve to a concrete route.',
        );
      }
    });

    testWidgets('malformed argument routes show explicit placeholders', (
      tester,
    ) async {
      for (final routeCase in _malformedArgumentRoutes) {
        await _pumpRoute(
          tester,
          routeCase.name,
          arguments: routeCase.arguments,
        );
        await tester.pumpAndSettle();

        expect(find.text(routeCase.expectedTitle), findsOneWidget);
        expect(find.text('Unknown Route'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('unknown routes remain explicitly classified as unknown', (
      tester,
    ) async {
      await _pumpRoute(tester, '/not-a-real-route');
      await tester.pumpAndSettle();

      expect(find.text('Unknown Route'), findsOneWidget);
      expect(find.textContaining('/not-a-real-route'), findsOneWidget);
    });
  });
}

Future<void> _pumpRoute(
  WidgetTester tester,
  String routeName, {
  Object? arguments,
}) async {
  await tester.pumpWidget(
    MaterialApp(
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
  );
  await tester.pump();
}

class _RouteCase {
  const _RouteCase(this.name, [this.arguments]);

  final String name;
  final Object? arguments;
}

class _MalformedRouteCase {
  const _MalformedRouteCase({
    required this.name,
    required this.expectedTitle,
    this.arguments,
  });

  final String name;
  final String expectedTitle;
  final Object? arguments;
}

final _configuredRoutes = <_RouteCase>[
  const _RouteCase(AppRoutes.splash),
  const _RouteCase(AppRoutes.welcome),
  const _RouteCase(AppRoutes.login),
  const _RouteCase(AppRoutes.register),
  const _RouteCase(AppRoutes.forgotPassword),
  const _RouteCase(AppRoutes.resetPassword),
  const _RouteCase(AppRoutes.otp, 'member@gymunity.test'),
  const _RouteCase(AppRoutes.authCallback),
  const _RouteCase('/?code=test-auth-code'),
  const _RouteCase(AppRoutes.roleSelection),
  const _RouteCase(AppRoutes.adminDashboard),
  const _RouteCase(AppRoutes.memberOnboarding),
  const _RouteCase(AppRoutes.sellerOnboarding),
  const _RouteCase(AppRoutes.coachOnboarding),
  const _RouteCase(AppRoutes.memberHome),
  const _RouteCase(AppRoutes.memberProfile),
  const _RouteCase(AppRoutes.editProfile),
  const _RouteCase(AppRoutes.progress),
  const _RouteCase(AppRoutes.workoutPlan, WorkoutPlanArgs(planId: 'plan-1')),
  const _RouteCase(
    AppRoutes.workoutDetails,
    WorkoutDayArgs(planId: 'plan-1', dayId: 'day-1'),
  ),
  const _RouteCase(AppRoutes.aiChatHome),
  const _RouteCase(AppRoutes.aiConversation, 'session-1'),
  const _RouteCase(
    AppRoutes.aiPlannerBuilder,
    PlannerBuilderArgs(seedPrompt: 'Build strength'),
  ),
  const _RouteCase(
    AppRoutes.aiGeneratedPlan,
    AiGeneratedPlanArgs(sessionId: 'session-1', draftId: 'draft-1'),
  ),
  const _RouteCase(
    AppRoutes.activeWorkoutSession,
    ActiveWorkoutSessionArgs(sessionId: 'session-1'),
  ),
  const _RouteCase(AppRoutes.aiPremiumPaywall),
  const _RouteCase(AppRoutes.subscriptionManagement),
  const _RouteCase(
    AppRoutes.nutrition,
    NutritionRouteArgs(initialHydrationAmountMl: 250),
  ),
  const _RouteCase(AppRoutes.nutritionSetup),
  const _RouteCase(
    AppRoutes.nutritionMealPlan,
    MealPlanRouteArgs(openQuickAddOnLaunch: true),
  ),
  const _RouteCase(AppRoutes.nutritionPreferences),
  const _RouteCase(AppRoutes.nutritionInsights),
  const _RouteCase(AppRoutes.newsFeed),
  _RouteCase(AppRoutes.newsArticleDetails, _sampleArticle),
  const _RouteCase(AppRoutes.storeHome),
  const _RouteCase(AppRoutes.productList),
  _RouteCase(AppRoutes.productDetails, _sampleProduct),
  const _RouteCase(AppRoutes.favorites),
  const _RouteCase(AppRoutes.cart),
  const _RouteCase(AppRoutes.checkout),
  const _RouteCase(AppRoutes.orders),
  const _RouteCase(AppRoutes.coaches),
  _RouteCase(AppRoutes.coachDetails, _sampleCoach),
  _RouteCase(AppRoutes.subscriptionPackages, _sampleCoach),
  const _RouteCase(AppRoutes.mySubscriptions),
  const _RouteCase(AppRoutes.myCoach, 'subscription-1'),
  const _RouteCase(AppRoutes.memberCoachKickoff, 'subscription-1'),
  const _RouteCase(AppRoutes.memberCoachHabits, 'subscription-1'),
  const _RouteCase(AppRoutes.memberCoachResources, 'subscription-1'),
  const _RouteCase(AppRoutes.memberCoachSessions, 'subscription-1'),
  const _RouteCase(AppRoutes.memberCheckins),
  const _RouteCase(AppRoutes.memberMessages),
  _RouteCase(AppRoutes.memberThread, _sampleThread),
  const _RouteCase(AppRoutes.sellerDashboard),
  const _RouteCase(AppRoutes.productManagement),
  const _RouteCase(AppRoutes.addProduct),
  _RouteCase(AppRoutes.editProduct, _sampleProduct),
  const _RouteCase(AppRoutes.sellerOrders),
  const _RouteCase(AppRoutes.sellerProfile),
  const _RouteCase(AppRoutes.coachDashboard),
  const _RouteCase(AppRoutes.clients),
  const _RouteCase(AppRoutes.packages),
  _RouteCase(AppRoutes.addPackage, _samplePackage),
  const _RouteCase(AppRoutes.coachProfile),
  const _RouteCase(
    AppRoutes.coachClientWorkspace,
    CoachClientWorkspaceArgs(subscriptionId: 'subscription-1'),
  ),
  const _RouteCase(AppRoutes.coachCheckins),
  const _RouteCase(AppRoutes.coachCalendar),
  const _RouteCase(AppRoutes.coachBilling),
  const _RouteCase(AppRoutes.coachProgramLibrary),
  const _RouteCase(AppRoutes.coachOnboardingFlows),
  const _RouteCase(AppRoutes.coachResources),
  const _RouteCase(
    AppRoutes.coachMemberInsights,
    InsightDetailArgs(
      memberId: 'member-1',
      subscriptionId: 'subscription-1',
      memberName: 'Member One',
    ),
  ),
  const _RouteCase(
    AppRoutes.memberCoachVisibility,
    VisibilitySettingsArgs(
      subscriptionId: 'subscription-1',
      coachId: 'coach-1',
      coachName: 'Coach Alex',
    ),
  ),
  const _RouteCase(AppRoutes.notifications),
  const _RouteCase(AppRoutes.settings),
  const _RouteCase(AppRoutes.deleteAccount),
  const _RouteCase(AppRoutes.helpSupport),
  const _RouteCase(AppRoutes.privacyPolicy),
  const _RouteCase(AppRoutes.terms),
];

const _malformedArgumentRoutes = <_MalformedRouteCase>[
  _MalformedRouteCase(
    name: AppRoutes.workoutDetails,
    arguments: 'bad-args',
    expectedTitle: 'Workout Details',
  ),
  _MalformedRouteCase(
    name: AppRoutes.aiGeneratedPlan,
    arguments: 'bad-args',
    expectedTitle: 'AI Generated Plan',
  ),
  _MalformedRouteCase(
    name: AppRoutes.memberCoachKickoff,
    expectedTitle: 'Coach Kickoff',
  ),
  _MalformedRouteCase(
    name: AppRoutes.memberCoachSessions,
    expectedTitle: 'Coach Sessions',
  ),
  _MalformedRouteCase(
    name: AppRoutes.memberThread,
    arguments: 'bad-args',
    expectedTitle: 'Messages',
  ),
  _MalformedRouteCase(
    name: AppRoutes.coachClientWorkspace,
    arguments: 42,
    expectedTitle: 'Client workspace',
  ),
  _MalformedRouteCase(
    name: AppRoutes.coachMemberInsights,
    arguments: 'bad-args',
    expectedTitle: 'Member Insights',
  ),
  _MalformedRouteCase(
    name: AppRoutes.memberCoachVisibility,
    arguments: 'bad-args',
    expectedTitle: 'Privacy Settings',
  ),
];

const _sampleProduct = ProductEntity(
  id: 'product-1',
  sellerId: 'seller-1',
  name: 'Protein Bar',
  description: 'Test product',
  category: 'SNACKS',
  price: 25,
);

const _samplePackage = CoachPackageEntity(
  id: 'package-1',
  coachId: 'coach-1',
  title: 'Starter package',
  description: 'Test package',
  billingCycle: 'monthly',
  price: 200,
);

const _sampleCoach = CoachEntity(
  id: 'coach-1',
  name: 'Coach Alex',
  specialties: <String>['Strength'],
  packages: <CoachPackageEntity>[_samplePackage],
);

final _sampleArticle = NewsArticleEntity(
  id: 'article-1',
  sourceId: 'source-1',
  sourceName: 'GymUnity Editorial',
  sourceBaseUrl: 'https://example.com',
  canonicalUrl: 'https://example.com/article-1',
  title: 'Recovery basics',
  summary: 'A short test article.',
  publishedAt: DateTime(2026, 3, 15),
);

final _sampleThread = CoachingThreadEntity(
  id: 'thread-1',
  subscriptionId: 'subscription-1',
  memberId: 'member-1',
  coachId: 'coach-1',
  updatedAt: DateTime(2026, 3, 15),
);
