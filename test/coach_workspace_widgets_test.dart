import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/coach/domain/entities/coach_workspace_entity.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/coach/presentation/screens/coach_billing_screen.dart';
import 'package:my_app/features/coach/presentation/screens/coach_client_workspace_screen.dart';
import 'package:my_app/features/member/domain/entities/coaching_engagement_entity.dart';
import 'package:my_app/features/member/presentation/screens/my_subscriptions_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('client workspace overview actions run for the selected client', (
    tester,
  ) async {
    await _useTallPhoneSurface(tester);
    final repo = FakeCoachRepository()
      ..programTemplates = const <CoachProgramTemplateEntity>[
        CoachProgramTemplateEntity(
          id: 'template-1',
          title: 'Build muscle starter',
          goalType: 'build_muscle',
        ),
      ]
      ..sessionTypes = const <CoachSessionTypeEntity>[
        CoachSessionTypeEntity(
          id: 'session-type-1',
          title: 'Weekly check-in',
          sessionKind: 'weekly_checkin_call',
        ),
      ]
      ..resources = const <CoachResourceEntity>[
        CoachResourceEntity(id: 'resource-1', title: 'Nutrition guide'),
      ]
      ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
        'sub-1': _workspace(
          status: 'active',
          checkoutStatus: 'paid',
          pipelineStage: 'active',
        ),
      };

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[coachRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: CoachClientWorkspaceScreen(subscriptionId: 'sub-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Schedule session'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule session'), findsWidgets);
    await tester.tap(find.text('Create booking'));
    await tester.pumpAndSettle();
    expect(repo.lastCreatedBookingPayload?['subscriptionId'], 'sub-1');
    expect(repo.lastCreatedBookingPayload?['sessionTypeId'], 'session-type-1');

    await tester.ensureVisible(find.text('Assign program'));
    await tester.tap(find.text('Assign program'));
    await tester.pumpAndSettle();
    expect(find.text('Assign program template'), findsOneWidget);
    await tester.tap(find.text('Assign').last);
    await tester.pumpAndSettle();
    expect(repo.lastAssignedProgramTemplatePayload?['subscriptionId'], 'sub-1');
    expect(
      repo.lastAssignedProgramTemplatePayload?['templateId'],
      'template-1',
    );

    await tester.ensureVisible(find.text('Assign resource'));
    await tester.tap(find.text('Assign resource'));
    await tester.pumpAndSettle();
    expect(find.text('Nutrition guide'), findsOneWidget);
    await tester.tap(find.text('Assign').last);
    await tester.pumpAndSettle();
    expect(repo.lastAssignedResourcePayload?['subscriptionId'], 'sub-1');
    expect(repo.lastAssignedResourcePayload?['resourceId'], 'resource-1');

  });

  testWidgets('client workspace review consent opens privacy tab', (
    tester,
  ) async {
    await _useTallPhoneSurface(tester);
    final repo = FakeCoachRepository()
      ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
        'sub-1': _workspace(),
      };

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[coachRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: CoachClientWorkspaceScreen(subscriptionId: 'sub-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Review consent'));
    await tester.tap(find.text('Review consent'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy locked'), findsOneWidget);
  });

  testWidgets('client workspace blocks booking for inactive clients', (
    tester,
  ) async {
    await _useTallPhoneSurface(tester);
    final repo = FakeCoachRepository()
      ..sessionTypes = const <CoachSessionTypeEntity>[
        CoachSessionTypeEntity(
          id: 'session-type-1',
          title: 'Weekly check-in',
          sessionKind: 'weekly_checkin_call',
        ),
      ]
      ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
        'sub-1': _workspace(),
      };

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[coachRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: CoachClientWorkspaceScreen(subscriptionId: 'sub-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule session'));
    await tester.pumpAndSettle();

    expect(
      find.text('Activate or unpause this client before scheduling.'),
      findsOneWidget,
    );
    expect(repo.lastCreatedBookingPayload, isNull);
  });

  testWidgets('client workspace check-in review submits coach feedback', (
    tester,
  ) async {
    await _useTallPhoneSurface(tester);
    final repo = FakeCoachRepository()
      ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
        'sub-1': _workspace(),
      };

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[coachRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: CoachClientWorkspaceScreen(subscriptionId: 'sub-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Check-ins'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Member-facing feedback message'),
      'Strong week. Add protein.',
    );
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();

    expect(repo.lastCheckinFeedbackPayload?['checkinId'], 'checkin-1');
    expect(repo.lastCheckinFeedbackPayload?['threadId'], 'thread-1');
    expect(
      repo.lastCheckinFeedbackPayload?['feedback'],
      'Strong week. Add protein.',
    );
  });

  testWidgets('coach workspace messages show thread history and send replies', (
    tester,
  ) async {
    await _useTallPhoneSurface(tester);
    final repo = FakeCoachRepository()
      ..coachMessages = <CoachMessageEntity>[
        CoachMessageEntity(
          id: 'message-1',
          threadId: 'thread-1',
          senderUserId: 'member-1',
          senderRole: 'member',
          content: 'Can we adjust leg day?',
          createdAt: DateTime(2026, 4, 25),
        ),
      ]
      ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
        'sub-1': _workspace(
          status: 'active',
          checkoutStatus: 'paid',
          pipelineStage: 'active',
        ),
      };

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[coachRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: CoachClientWorkspaceScreen(subscriptionId: 'sub-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Message client'));
    await tester.pumpAndSettle();
    expect(find.text('Can we adjust leg day?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Yes, I will update it.');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(repo.lastSentCoachMessagePayload?['threadId'], 'thread-1');
    expect(
      repo.lastSentCoachMessagePayload?['content'],
      'Yes, I will update it.',
    );
    expect(
      repo.coachMessages.any(
        (message) => message.content == 'Yes, I will update it.',
      ),
      isTrue,
    );
  });

  testWidgets('member coaching messages open the active thread and send', (
    tester,
  ) async {
    await _useTallPhoneSurface(tester);
    final repo = FakeMemberRepository()
      ..subscriptions = const <SubscriptionEntity>[
        SubscriptionEntity(
          id: 'sub-1',
          memberId: 'member-1',
          coachId: 'coach-1',
          coachName: 'Social Selling OS Egypt',
          packageTitle: 'Starter Coaching',
          status: 'active',
          checkoutStatus: 'paid',
          amount: 199,
          planName: 'Starter Coaching',
          threadId: 'thread-1',
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[memberRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: const MySubscriptionsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.text('Social Selling OS Egypt'), findsOneWidget);
    expect(find.text('Your coaching thread is ready.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Ready for my first workout.',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(repo.lastSentCoachingMessagePayload?['threadId'], 'thread-1');
    expect(
      repo.lastSentCoachingMessagePayload?['content'],
      'Ready for my first workout.',
    );
  });

  testWidgets('paused member coaching thread is readable but cannot send', (
    tester,
  ) async {
    await _useTallPhoneSurface(tester);
    final repo = FakeMemberRepository()
      ..subscriptions = const <SubscriptionEntity>[
        SubscriptionEntity(
          id: 'sub-1',
          memberId: 'member-1',
          coachId: 'coach-1',
          coachName: 'Paused Coach',
          packageTitle: 'Starter Coaching',
          status: 'paused',
          checkoutStatus: 'paid',
          amount: 199,
          planName: 'Starter Coaching',
          threadId: 'thread-1',
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[memberRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: const MySubscriptionsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();

    expect(find.text('Your coaching thread is ready.'), findsOneWidget);
    expect(
      find.textContaining('Message history remains available'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'paused subscriptions are hidden from member check-in submission',
    (tester) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeMemberRepository()
        ..subscriptions = const <SubscriptionEntity>[
          SubscriptionEntity(
            id: 'sub-1',
            memberId: 'member-1',
            coachId: 'coach-1',
            coachName: 'Paused Coach',
            packageTitle: 'Starter Coaching',
            status: 'paused',
            checkoutStatus: 'paid',
            amount: 199,
            planName: 'Starter Coaching',
            threadId: 'thread-1',
          ),
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            memberRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            onGenerateRoute: AppRoutes.onGenerateRoute,
            home: const MySubscriptionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Check-ins'));
      await tester.pumpAndSettle();

      expect(find.text('Submit this week'), findsNothing);
      expect(
        find.textContaining('Activate a coaching subscription first'),
        findsOneWidget,
      );
    },
  );

  testWidgets('billing details sheet renders audit events', (tester) async {
    final repo = FakeCoachRepository()
      ..paymentQueue = const <CoachPaymentReceiptEntity>[
        CoachPaymentReceiptEntity(
          id: 'receipt-1',
          subscriptionId: 'sub-1',
          memberId: 'member-1',
          memberName: 'Mona Ali',
          packageTitle: 'Starter Coaching',
          amount: 1200,
          paymentReference: 'REF-11',
          billingState: 'under_verification',
          status: 'receipt_uploaded',
        ),
      ]
      ..paymentAuditTrail = const <CoachPaymentAuditEntity>[
        CoachPaymentAuditEntity(
          id: 'audit-1',
          actorName: 'Coach',
          newState: 'under_verification',
          note: 'Receipt received',
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[coachRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: CoachBillingScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    expect(find.text('Receipt details'), findsOneWidget);
    expect(find.text('Audit trail'), findsOneWidget);
    expect(find.text('Receipt received'), findsOneWidget);
  });

  testWidgets('Paymob member subscription hides payment proof action', (
    tester,
  ) async {
    final repo = FakeMemberRepository()
      ..subscriptions = const <SubscriptionEntity>[
        SubscriptionEntity(
          id: 'sub-paymob',
          memberId: 'member-1',
          coachId: 'coach-1',
          coachName: 'Mona Coach',
          packageId: 'package-1',
          packageTitle: 'Starter Coaching',
          status: 'checkout_pending',
          checkoutStatus: 'checkout_pending',
          paymentGateway: 'paymob',
          paymentOrderId: 'order-1',
          amount: 1200,
          amountCents: 120000,
          planName: 'Starter Coaching',
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[memberRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: MySubscriptionsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('TEST PAYMENT'), findsOneWidget);
    expect(find.text('Payment pending'), findsWidgets);
    expect(find.text('Submit payment proof'), findsNothing);
  });

  testWidgets('Paymob coach billing hides approve and fail actions', (
    tester,
  ) async {
    final repo = FakeCoachRepository()
      ..paymentQueue = const <CoachPaymentReceiptEntity>[
        CoachPaymentReceiptEntity(
          id: 'order-1',
          subscriptionId: 'sub-1',
          memberId: 'member-1',
          memberName: 'Mona Ali',
          packageTitle: 'Starter Coaching',
          amount: 1200,
          paymentGateway: 'paymob',
          paymentOrderId: 'order-1',
          paymentOrderStatus: 'pending',
          payoutStatus: 'pending',
          billingState: 'payment_pending',
          status: 'pending',
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[coachRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: CoachBillingScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Paymob TEST'), findsOneWidget);
    expect(find.text('Order pending'), findsOneWidget);
    expect(find.text('Payout pending'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.byTooltip('Needs follow-up'), findsNothing);
  });
}

Future<void> _useTallPhoneSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

CoachClientWorkspaceEntity _workspace({
  String status = 'checkout_pending',
  String checkoutStatus = 'checkout_pending',
  String pipelineStage = 'pending_payment',
}) {
  final client = CoachClientPipelineEntry(
    subscriptionId: 'sub-1',
    memberId: 'member-1',
    memberName: 'GymUnity',
    packageTitle: 'Starter Coaching',
    status: status,
    checkoutStatus: checkoutStatus,
    billingCycle: 'monthly',
    amount: 1200,
    pipelineStage: pipelineStage,
    internalStatus: 'active',
    riskStatus: 'none',
    goal: 'build_muscle',
    startedAt: DateTime(2026, 4, 25),
  );

  return CoachClientWorkspaceEntity(
    client: client,
    threads: const <CoachThreadEntity>[
      CoachThreadEntity(
        id: 'thread-1',
        subscriptionId: 'sub-1',
        memberId: 'member-1',
        coachId: 'coach-1',
      ),
    ],
    checkins: <WeeklyCheckinEntity>[
      WeeklyCheckinEntity(
        id: 'checkin-1',
        subscriptionId: 'sub-1',
        threadId: 'thread-1',
        memberId: 'member-1',
        coachId: 'coach-1',
        weekStart: DateTime(2026, 4, 20),
        adherenceScore: 8,
        wins: 'Completed four workouts',
      ),
    ],
    billing: const <CoachPaymentReceiptEntity>[
      CoachPaymentReceiptEntity(
        id: 'receipt-1',
        subscriptionId: 'sub-1',
        memberId: 'member-1',
        memberName: 'GymUnity',
        packageTitle: 'Starter Coaching',
        amount: 1200,
        billingState: 'under_verification',
        status: 'receipt_uploaded',
      ),
    ],
  );
}
