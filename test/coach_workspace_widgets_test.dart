import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/coach/domain/entities/coach_workspace_entity.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/coach/presentation/providers/coach_providers.dart';
import 'package:my_app/features/coach/presentation/screens/coach_billing_screen.dart';
import 'package:my_app/features/coach/presentation/screens/coach_client_workspace_screen.dart';
import 'package:my_app/features/coach_member_insights/domain/entities/visibility_settings_entity.dart';
import 'package:my_app/features/member/domain/entities/coaching_engagement_entity.dart';
import 'package:my_app/features/member/presentation/screens/my_subscriptions_screen.dart';

import 'test_doubles.dart';

void main() {
  group('manual TAIYO coach brief', () {
    setUp(debugClearTaiyoCoachClientBriefCacheForTests);

    testWidgets('opening client workspace does not call TAIYO', (tester) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(visibility: _sharedVisibility),
        };

      await _pumpClientWorkspace(tester, repo);

      expect(find.text('TAIYO Coach Brief'), findsOneWidget);
      expect(find.text('Generate AI Brief'), findsOneWidget);
      expect(repo.requestTaiyoCoachClientBriefCalls, 0);
    });

    testWidgets('tapping generate calls TAIYO once and shows timestamp', (
      tester,
    ) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(visibility: _sharedVisibility),
        };

      await _pumpClientWorkspace(tester, repo);
      await _tapWorkspaceText(tester, 'Generate AI Brief');
      await tester.pumpAndSettle();

      expect(repo.requestTaiyoCoachClientBriefCalls, 1);
      expect(find.textContaining('Last generated:'), findsOneWidget);
      expect(find.text('Refresh Brief'), findsOneWidget);
    });

    testWidgets('cached brief does not regenerate on rebuild', (tester) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(visibility: _sharedVisibility),
        };

      await _pumpClientWorkspace(tester, repo);
      await _tapWorkspaceText(tester, 'Generate AI Brief');
      await tester.pumpAndSettle();
      await _pumpClientWorkspace(tester, repo);

      expect(repo.requestTaiyoCoachClientBriefCalls, 1);
      await _ensureWorkspaceTextVisible(tester, 'Refresh Brief');
      expect(find.textContaining('Client is steady.'), findsOneWidget);
      expect(find.textContaining('Last generated:'), findsOneWidget);
    });

    testWidgets('refresh intentionally regenerates the cached brief', (
      tester,
    ) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(visibility: _sharedVisibility),
        };

      await _pumpClientWorkspace(tester, repo);
      await _tapWorkspaceText(tester, 'Generate AI Brief');
      await tester.pumpAndSettle();
      await _tapWorkspaceText(tester, 'Refresh Brief');
      await tester.pumpAndSettle();

      expect(repo.requestTaiyoCoachClientBriefCalls, 2);
      expect(find.textContaining('Last generated:'), findsOneWidget);
    });

    testWidgets('no sharing consent blocks TAIYO generation', (tester) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(visibility: _lockedVisibility),
        };

      await _pumpClientWorkspace(tester, repo);
      expect(find.textContaining('member has not shared'), findsOneWidget);
      final generate = find.text('Generate AI Brief');
      expect(generate, findsOneWidget);
      await _tapWorkspaceText(tester, 'Generate AI Brief', warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repo.requestTaiyoCoachClientBriefCalls, 0);
    });

    testWidgets('TAIYO errors show a friendly retry state', (tester) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(visibility: _sharedVisibility),
        }
        ..taiyoCoachBriefError = Exception('backend exploded');

      await _pumpClientWorkspace(tester, repo);
      await _tapWorkspaceText(tester, 'Generate AI Brief');
      await tester.pumpAndSettle();

      expect(repo.requestTaiyoCoachClientBriefCalls, 1);
      expect(find.text('Brief unavailable'), findsOneWidget);
      expect(
        find.text('TAIYO could not prepare this client brief right now.'),
        findsOneWidget,
      );
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('backend'), findsNothing);
    });
  });

  group('coach check-in visibility privacy', () {
    testWidgets('locked visibility hides sensitive check-in details', (
      tester,
    ) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(
            visibility: _lockedVisibility,
            includeSensitiveCheckin: true,
          ),
        };

      await _pumpClientWorkspace(tester, repo);
      await _openCheckinReview(tester);

      expect(_sheetText('Energy'), findsNothing);
      expect(_sheetText('Sleep'), findsNothing);
      expect(_sheetText('Soreness'), findsNothing);
      expect(_sheetText('Fatigue'), findsNothing);
      expect(_sheetText('Pain warning'), findsNothing);
      expect(_sheetText('Nutrition'), findsNothing);
      expect(_sheetText('Photos'), findsNothing);
      expect(_sheetText('Workouts completed'), findsNothing);
      expect(_sheetText('Missed workouts'), findsNothing);
      expect(_sheetText('Missed reason'), findsNothing);
      expect(_sheetText('Wins'), findsNothing);
      expect(_sheetText('Blockers'), findsNothing);
      expect(_sheetText('Questions'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining(
            'hidden because the member has not shared',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('workout visibility shows only workout check-in fields', (
      tester,
    ) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(
            visibility: _workoutVisibility,
            includeSensitiveCheckin: true,
          ),
        };

      await _pumpClientWorkspace(tester, repo);
      await _openCheckinReview(tester);

      expect(_sheetText('Adherence'), findsOneWidget);
      expect(_sheetText('Workouts completed'), findsOneWidget);
      expect(_sheetText('Missed workouts'), findsOneWidget);
      expect(_sheetText('Missed reason'), findsOneWidget);
      expect(_sheetText('Habits'), findsOneWidget);
      expect(_sheetText('Energy'), findsNothing);
      expect(_sheetText('Sleep'), findsNothing);
      expect(_sheetText('Soreness'), findsNothing);
      expect(_sheetText('Fatigue'), findsNothing);
      expect(_sheetText('Pain warning'), findsNothing);
      expect(_sheetText('Nutrition'), findsNothing);
      expect(_sheetText('Photos'), findsNothing);
      expect(_sheetText('Weight'), findsNothing);
      expect(_sheetText('Waist'), findsNothing);
      expect(_sheetText('Wins'), findsNothing);
      expect(_sheetText('Blockers'), findsNothing);
      expect(_sheetText('Questions'), findsNothing);
    });

    testWidgets('progress visibility shows body and health check-in fields', (
      tester,
    ) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(
            visibility: _progressVisibility,
            includeSensitiveCheckin: true,
          ),
        };

      await _pumpClientWorkspace(tester, repo);
      await _openCheckinReview(tester);

      expect(_sheetText('Weight'), findsOneWidget);
      expect(_sheetText('Waist'), findsOneWidget);
      expect(_sheetText('Energy'), findsOneWidget);
      expect(_sheetText('Sleep'), findsOneWidget);
      expect(_sheetText('Soreness'), findsOneWidget);
      expect(_sheetText('Fatigue'), findsOneWidget);
      expect(_sheetText('Pain warning'), findsOneWidget);
      expect(_sheetText('Photos'), findsOneWidget);
      expect(_sheetText('Nutrition'), findsNothing);
      expect(_sheetText('Wins'), findsNothing);
      expect(_sheetText('Blockers'), findsNothing);
      expect(_sheetText('Questions'), findsNothing);
    });

    testWidgets('nutrition visibility shows only nutrition check-in field', (
      tester,
    ) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(
            visibility: _nutritionVisibility,
            includeSensitiveCheckin: true,
          ),
        };

      await _pumpClientWorkspace(tester, repo);
      await _openCheckinReview(tester);

      expect(_sheetText('Nutrition'), findsOneWidget);
      expect(_sheetText('Energy'), findsNothing);
      expect(_sheetText('Sleep'), findsNothing);
      expect(_sheetText('Soreness'), findsNothing);
      expect(_sheetText('Fatigue'), findsNothing);
      expect(_sheetText('Pain warning'), findsNothing);
      expect(_sheetText('Workouts completed'), findsNothing);
      expect(_sheetText('Photos'), findsNothing);
      expect(_sheetText('Wins'), findsNothing);
      expect(_sheetText('Blockers'), findsNothing);
      expect(_sheetText('Questions'), findsNothing);
    });

    testWidgets('AI plan visibility shows general check-in context only', (
      tester,
    ) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(
            visibility: _aiPlanVisibility,
            includeSensitiveCheckin: true,
          ),
        };

      await _pumpClientWorkspace(tester, repo);
      await _openCheckinReview(tester);

      expect(_sheetText('Biggest obstacle'), findsOneWidget);
      expect(_sheetText('Support needed'), findsOneWidget);
      expect(_sheetText('Wins'), findsOneWidget);
      expect(_sheetText('Blockers'), findsOneWidget);
      expect(_sheetText('Questions'), findsOneWidget);
      expect(_sheetText('Energy'), findsNothing);
      expect(_sheetText('Sleep'), findsNothing);
      expect(_sheetText('Nutrition'), findsNothing);
      expect(_sheetText('Photos'), findsNothing);
      expect(_sheetText('Workouts completed'), findsNothing);
    });

    testWidgets('check-in row subtitle does not leak adherence when locked', (
      tester,
    ) async {
      await _useTallPhoneSurface(tester);
      final repo = FakeCoachRepository()
        ..clientWorkspaces = <String, CoachClientWorkspaceEntity>{
          'sub-1': _workspace(
            visibility: _lockedVisibility,
            includeSensitiveCheckin: true,
          ),
        };

      await _pumpClientWorkspace(tester, repo);
      await tester.tap(find.text('Check-ins'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Adherence'), findsNothing);
      expect(find.textContaining('/10'), findsNothing);
      expect(find.textContaining('Check-in submitted'), findsOneWidget);
    });
  });

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

  testWidgets('failed Paymob subscription keeps coach workspace locked', (
    tester,
  ) async {
    final repo = FakeMemberRepository()
      ..subscriptions = const <SubscriptionEntity>[
        SubscriptionEntity(
          id: 'sub-failed',
          memberId: 'member-1',
          coachId: 'coach-1',
          coachName: 'Mona Coach',
          packageId: 'package-1',
          packageTitle: 'Starter Coaching',
          status: 'checkout_pending',
          checkoutStatus: 'failed',
          paymentGateway: 'paymob',
          paymentOrderId: 'order-1',
          amount: 1200,
          amountCents: 120000,
          planName: 'Starter Coaching',
          threadId: 'thread-1',
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[memberRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: MySubscriptionsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Payment failed'), findsOneWidget);
    expect(find.text('Payment was not completed'), findsOneWidget);
    expect(find.text('Retry payment'), findsOneWidget);
    expect(find.text('Open Coach Hub'), findsNothing);
    expect(find.text('Messages'), findsNothing);
    expect(find.text('Check-ins'), findsNothing);
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
  tester.view.physicalSize = const Size(390, 1600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

CoachClientWorkspaceEntity _workspace({
  String status = 'checkout_pending',
  String checkoutStatus = 'checkout_pending',
  String pipelineStage = 'pending_payment',
  VisibilitySettingsEntity? visibility,
  bool includeSensitiveCheckin = false,
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
        weightKg: includeSensitiveCheckin ? 82 : null,
        waistCm: includeSensitiveCheckin ? 92 : null,
        energyScore: includeSensitiveCheckin ? 7 : null,
        sleepScore: includeSensitiveCheckin ? 6 : null,
        sorenessScore: includeSensitiveCheckin ? 4 : null,
        fatigueScore: includeSensitiveCheckin ? 5 : null,
        painWarning: includeSensitiveCheckin ? 'Knee pain' : null,
        nutritionAdherenceScore: includeSensitiveCheckin ? 70 : null,
        habitAdherenceScore: includeSensitiveCheckin ? 80 : null,
        workoutsCompleted: includeSensitiveCheckin ? 4 : null,
        missedWorkouts: includeSensitiveCheckin ? 1 : null,
        missedWorkoutsReason: includeSensitiveCheckin ? 'Travel' : null,
        biggestObstacle: includeSensitiveCheckin ? 'Late work nights' : null,
        supportNeeded: includeSensitiveCheckin ? 'Need plan adjustment' : null,
        wins: 'Completed four workouts',
        blockers: includeSensitiveCheckin ? 'Low sleep' : null,
        questions: includeSensitiveCheckin ? 'Can we reduce leg volume?' : null,
        photos: includeSensitiveCheckin
            ? const <ProgressPhotoEntity>[
                ProgressPhotoEntity(
                  id: 'photo-1',
                  storagePath: 'member-1/front.jpg',
                ),
              ]
            : const <ProgressPhotoEntity>[],
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
    visibility: visibility,
  );
}

Finder _sheetText(String text) {
  return find.descendant(
    of: find.byType(BottomSheet),
    matching: find.text(text),
  );
}

Future<void> _openCheckinReview(WidgetTester tester) async {
  await tester.tap(find.text('Check-ins'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Review'));
  await tester.pumpAndSettle();
}

Future<void> _pumpClientWorkspace(
  WidgetTester tester,
  FakeCoachRepository repo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[coachRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        home: CoachClientWorkspaceScreen(subscriptionId: 'sub-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapWorkspaceText(
  WidgetTester tester,
  String text, {
  bool warnIfMissed = true,
}) async {
  final finder = find.text(text);
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(finder, warnIfMissed: warnIfMissed);
}

Future<void> _ensureWorkspaceTextVisible(
  WidgetTester tester,
  String text,
) async {
  await tester.scrollUntilVisible(
    find.text(text),
    250,
    scrollable: find.byType(Scrollable).first,
  );
}

const _sharedVisibility = VisibilitySettingsEntity(
  id: 'visibility-1',
  memberId: 'member-1',
  coachId: 'coach-1',
  subscriptionId: 'sub-1',
  shareWorkoutAdherence: true,
);

const _workoutVisibility = VisibilitySettingsEntity(
  id: 'visibility-workout',
  memberId: 'member-1',
  coachId: 'coach-1',
  subscriptionId: 'sub-1',
  shareWorkoutAdherence: true,
);

const _progressVisibility = VisibilitySettingsEntity(
  id: 'visibility-progress',
  memberId: 'member-1',
  coachId: 'coach-1',
  subscriptionId: 'sub-1',
  shareProgressMetrics: true,
);

const _nutritionVisibility = VisibilitySettingsEntity(
  id: 'visibility-nutrition',
  memberId: 'member-1',
  coachId: 'coach-1',
  subscriptionId: 'sub-1',
  shareNutritionSummary: true,
);

const _aiPlanVisibility = VisibilitySettingsEntity(
  id: 'visibility-ai-plan',
  memberId: 'member-1',
  coachId: 'coach-1',
  subscriptionId: 'sub-1',
  shareAiPlanSummary: true,
);

const _lockedVisibility = VisibilitySettingsEntity(
  id: 'visibility-1',
  memberId: 'member-1',
  coachId: 'coach-1',
  subscriptionId: 'sub-1',
);
