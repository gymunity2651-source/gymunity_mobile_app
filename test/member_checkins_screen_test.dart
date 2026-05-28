import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/member/presentation/screens/member_checkins_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('adherence outside 0 to 100 is rejected before submit', (
    tester,
  ) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterText(tester, 'Adherence %', '120');
    await _tapDialogSubmit(tester);

    expect(find.text('Check-in for Coach Lina'), findsOneWidget);
    expect(find.text('Adherence must be between 0 and 100.'), findsOneWidget);
    expect(repo.submitWeeklyCheckinCalls, 0);
  });

  testWidgets('soreness outside 1 to 10 is rejected before submit', (
    tester,
  ) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterText(tester, 'Adherence %', '80');
    await _enterText(tester, 'Soreness 1-10', '11');
    await _tapDialogSubmit(tester);

    expect(find.text('Soreness must be between 1 and 10.'), findsOneWidget);
    expect(repo.submitWeeklyCheckinCalls, 0);
  });

  testWidgets('fatigue outside 1 to 10 is rejected before submit', (
    tester,
  ) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterText(tester, 'Adherence %', '80');
    await _enterText(tester, 'Fatigue 1-10', '0');
    await _tapDialogSubmit(tester);

    expect(find.text('Fatigue must be between 1 and 10.'), findsOneWidget);
    expect(repo.submitWeeklyCheckinCalls, 0);
  });

  testWidgets('optional numeric fields reject non-numeric input', (
    tester,
  ) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterText(tester, 'Adherence %', '80');
    await _enterText(tester, 'Weight (kg)', 'eighty');
    await _tapDialogSubmit(tester);

    expect(find.text('Enter a realistic weight in kilograms.'), findsOneWidget);
    expect(repo.submitWeeklyCheckinCalls, 0);
  });

  testWidgets('nutrition and habit percentages are validated', (tester) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterText(tester, 'Adherence %', '80');
    await _enterText(tester, 'Nutrition %', '130');
    await _tapDialogSubmit(tester);

    expect(
      find.text('Nutrition adherence must be between 0 and 100.'),
      findsOneWidget,
    );
    expect(repo.submitWeeklyCheckinCalls, 0);

    await _enterText(tester, 'Nutrition %', '90');
    await _enterText(tester, 'Habits %', '-5');
    await _tapDialogSubmit(tester);

    expect(
      find.text('Habit adherence must be between 0 and 100.'),
      findsOneWidget,
    );
    expect(repo.submitWeeklyCheckinCalls, 0);
  });

  testWidgets('loading state prevents double submit', (tester) async {
    final repo = _repoWithActiveSubscription()
      ..submitWeeklyCheckinCompleter = Completer<void>();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterValidRequiredFields(tester);
    await _tapDialogSubmit(tester);
    await tester.pump();

    expect(repo.submitWeeklyCheckinCalls, 1);
    expect(find.text('Submitting...'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Submitting...'),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(repo.submitWeeklyCheckinCalls, 1);

    repo.submitWeeklyCheckinCompleter!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('submit failure keeps dialog open and preserves input', (
    tester,
  ) async {
    final repo = _repoWithActiveSubscription()
      ..submitWeeklyCheckinError = StateError('network down');
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterValidRequiredFields(tester);
    await _enterText(tester, 'Wins', 'Hit all sessions');
    await _tapDialogSubmit(tester);
    await tester.pumpAndSettle();

    expect(repo.submitWeeklyCheckinCalls, 1);
    expect(
      find.textContaining('Weekly check-in could not be submitted:'),
      findsOneWidget,
    );
    expect(find.text('Check-in for Coach Lina'), findsOneWidget);
    expect(find.text('Hit all sessions'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Submit'), findsOneWidget);
  });

  testWidgets('valid submit sends parsed values and shows success', (
    tester,
  ) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterText(tester, 'Weight (kg)', '82.5');
    await _enterText(tester, 'Waist (cm)', '90.2');
    await _enterText(tester, 'Adherence %', '85');
    await _enterText(tester, 'Workouts completed', '4');
    await _enterText(tester, 'Missed workouts', '1');
    await _enterText(tester, 'Reason for missed workouts', 'Travel');
    await _enterText(tester, 'Soreness 1-10', '3');
    await _enterText(tester, 'Fatigue 1-10', '4');
    await _enterText(tester, 'Nutrition %', '92');
    await _enterText(tester, 'Habits %', '88');
    await _enterText(tester, 'Pain or injury warning', 'None');
    await _enterText(tester, 'Biggest obstacle this week', 'Long workdays');
    await _enterText(tester, 'Support needed from coach', 'Meal timing');
    await _enterText(tester, 'Wins', 'Better sleep');
    await _enterText(tester, 'Blockers', 'Late meetings');
    await _enterText(tester, 'Questions', 'Adjust cardio?');
    await _tapDialogSubmit(tester);
    await tester.pumpAndSettle();

    expect(repo.submitWeeklyCheckinCalls, 1);
    expect(repo.lastWeeklyCheckinPayload?['subscriptionId'], 'sub-1');
    expect(repo.lastWeeklyCheckinPayload?['weightKg'], 82.5);
    expect(repo.lastWeeklyCheckinPayload?['waistCm'], 90.2);
    expect(repo.lastWeeklyCheckinPayload?['adherenceScore'], 85);
    expect(repo.lastWeeklyCheckinPayload?['workoutsCompleted'], 4);
    expect(repo.lastWeeklyCheckinPayload?['missedWorkouts'], 1);
    expect(repo.lastWeeklyCheckinPayload?['missedWorkoutsReason'], 'Travel');
    expect(repo.lastWeeklyCheckinPayload?['sorenessScore'], 3);
    expect(repo.lastWeeklyCheckinPayload?['fatigueScore'], 4);
    expect(repo.lastWeeklyCheckinPayload?['nutritionAdherenceScore'], 92);
    expect(repo.lastWeeklyCheckinPayload?['habitAdherenceScore'], 88);
    expect(repo.lastWeeklyCheckinPayload?['painWarning'], 'None');
    expect(repo.lastWeeklyCheckinPayload?['biggestObstacle'], 'Long workdays');
    expect(repo.lastWeeklyCheckinPayload?['supportNeeded'], 'Meal timing');
    expect(repo.lastWeeklyCheckinPayload?['wins'], 'Better sleep');
    expect(repo.lastWeeklyCheckinPayload?['blockers'], 'Late meetings');
    expect(repo.lastWeeklyCheckinPayload?['questions'], 'Adjust cardio?');
    expect(find.text('Check-in for Coach Lina'), findsNothing);
    expect(find.text('Weekly check-in submitted.'), findsOneWidget);
  });
}

FakeMemberRepository _repoWithActiveSubscription() {
  return FakeMemberRepository()
    ..subscriptions = const <SubscriptionEntity>[
      SubscriptionEntity(
        id: 'sub-1',
        memberId: 'member-1',
        coachId: 'coach-1',
        coachName: 'Coach Lina',
        packageTitle: 'Outcome Coaching',
        planName: 'Outcome Coaching',
        status: 'active',
        checkoutStatus: 'paid',
        amount: 1200,
      ),
    ];
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeMemberRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        memberRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: MemberCheckinsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.text('Submit this week'));
  await tester.pumpAndSettle();
}

Future<void> _enterValidRequiredFields(WidgetTester tester) async {
  await _enterText(tester, 'Adherence %', '80');
}

Future<void> _enterText(WidgetTester tester, String label, String value) async {
  await tester.enterText(find.widgetWithText(TextField, label), value);
  await tester.pump();
}

Future<void> _tapDialogSubmit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
  await tester.pump();
}
