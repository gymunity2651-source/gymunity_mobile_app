import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/member/presentation/screens/member_checkins_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('quick step is shown first', (tester) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    expect(find.text('Quick Check-in'), findsOneWidget);
    expect(find.text('Adherence %'), findsOneWidget);
    expect(find.text('Energy 1-10'), findsOneWidget);
    expect(find.text('Sleep 1-10'), findsOneWidget);
    expect(find.text('Pain or injury warning'), findsOneWidget);
    expect(find.text('Biggest obstacle this week'), findsOneWidget);
    expect(find.text('Support needed from coach'), findsOneWidget);
    expect(find.text('Weight (kg)'), findsNothing);
    expect(find.text('Nutrition %'), findsNothing);
    expect(find.text('Wins'), findsNothing);
  });

  testWidgets('quick required validation blocks next and submit', (
    tester,
  ) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterText(tester, 'Adherence %', '120');
    await _tapButton(tester, 'Next: Advanced Details');

    expect(find.text('Adherence must be between 0 and 100.'), findsOneWidget);
    expect(find.text('Advanced Details'), findsNothing);
    expect(repo.submitWeeklyCheckinCalls, 0);

    await _enterText(tester, 'Adherence %', '80');
    await _enterText(tester, 'Energy 1-10', '11');
    await _tapButton(tester, 'Submit Quick Check-in');

    expect(find.text('Energy must be between 1 and 10.'), findsOneWidget);
    expect(repo.submitWeeklyCheckinCalls, 0);

    await _enterText(tester, 'Energy 1-10', '7');
    await _enterText(tester, 'Sleep 1-10', '0');
    await _tapButton(tester, 'Submit Quick Check-in');

    expect(find.text('Sleep must be between 1 and 10.'), findsOneWidget);
    expect(repo.submitWeeklyCheckinCalls, 0);
  });

  testWidgets('next validates quick fields before showing advanced', (
    tester,
  ) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterQuickRequired(tester);
    await _tapButton(tester, 'Next: Advanced Details');

    expect(find.text('Advanced Details'), findsOneWidget);
    expect(find.text('Weight (kg)'), findsOneWidget);
    expect(find.text('Nutrition %'), findsOneWidget);
    expect(find.text('Wins'), findsOneWidget);
  });

  testWidgets('submit quick check-in sends only quick fields', (tester) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterText(tester, 'Adherence %', '85');
    await _enterText(tester, 'Energy 1-10', '7');
    await _enterText(tester, 'Sleep 1-10', '6');
    await _enterText(tester, 'Pain or injury warning', 'None');
    await _enterText(tester, 'Biggest obstacle this week', 'Long workdays');
    await _enterText(tester, 'Support needed from coach', 'Meal timing');
    await _tapButton(tester, 'Submit Quick Check-in');
    await tester.pumpAndSettle();

    expect(repo.submitWeeklyCheckinCalls, 1);
    expect(repo.lastWeeklyCheckinPayload?['subscriptionId'], 'sub-1');
    expect(repo.lastWeeklyCheckinPayload?['adherenceScore'], 85);
    expect(repo.lastWeeklyCheckinPayload?['energyScore'], 7);
    expect(repo.lastWeeklyCheckinPayload?['sleepScore'], 6);
    expect(repo.lastWeeklyCheckinPayload?['painWarning'], 'None');
    expect(repo.lastWeeklyCheckinPayload?['biggestObstacle'], 'Long workdays');
    expect(repo.lastWeeklyCheckinPayload?['supportNeeded'], 'Meal timing');
    expect(repo.lastWeeklyCheckinPayload?['weightKg'], isNull);
    expect(repo.lastWeeklyCheckinPayload?['nutritionAdherenceScore'], isNull);
    expect(find.text('Weekly check-in submitted.'), findsOneWidget);
  });

  testWidgets('advanced submit sends quick and advanced fields', (
    tester,
  ) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterText(tester, 'Adherence %', '85');
    await _enterText(tester, 'Energy 1-10', '7');
    await _enterText(tester, 'Sleep 1-10', '6');
    await _enterText(tester, 'Pain or injury warning', 'None');
    await _enterText(tester, 'Biggest obstacle this week', 'Long workdays');
    await _enterText(tester, 'Support needed from coach', 'Meal timing');
    await _goToAdvanced(tester);
    await _enterText(tester, 'Weight (kg)', '82.5');
    await _enterText(tester, 'Waist (cm)', '90.2');
    await _enterText(tester, 'Nutrition %', '92');
    await _enterText(tester, 'Habits %', '88');
    await _enterText(tester, 'Workouts completed', '4');
    await _enterText(tester, 'Missed workouts', '1');
    await _enterText(tester, 'Reason for missed workouts', 'Travel');
    await _enterText(tester, 'Soreness 1-10', '3');
    await _enterText(tester, 'Fatigue 1-10', '4');
    await _enterText(tester, 'Wins', 'Better sleep');
    await _enterText(tester, 'Blockers', 'Late meetings');
    await _enterText(tester, 'Questions', 'Adjust cardio?');
    await _tapButton(tester, 'Submit Check-in');
    await tester.pumpAndSettle();

    expect(repo.submitWeeklyCheckinCalls, 1);
    expect(repo.lastWeeklyCheckinPayload?['adherenceScore'], 85);
    expect(repo.lastWeeklyCheckinPayload?['energyScore'], 7);
    expect(repo.lastWeeklyCheckinPayload?['sleepScore'], 6);
    expect(repo.lastWeeklyCheckinPayload?['weightKg'], 82.5);
    expect(repo.lastWeeklyCheckinPayload?['waistCm'], 90.2);
    expect(repo.lastWeeklyCheckinPayload?['nutritionAdherenceScore'], 92);
    expect(repo.lastWeeklyCheckinPayload?['habitAdherenceScore'], 88);
    expect(repo.lastWeeklyCheckinPayload?['workoutsCompleted'], 4);
    expect(repo.lastWeeklyCheckinPayload?['missedWorkouts'], 1);
    expect(repo.lastWeeklyCheckinPayload?['missedWorkoutsReason'], 'Travel');
    expect(repo.lastWeeklyCheckinPayload?['sorenessScore'], 3);
    expect(repo.lastWeeklyCheckinPayload?['fatigueScore'], 4);
    expect(repo.lastWeeklyCheckinPayload?['painWarning'], 'None');
    expect(repo.lastWeeklyCheckinPayload?['biggestObstacle'], 'Long workdays');
    expect(repo.lastWeeklyCheckinPayload?['supportNeeded'], 'Meal timing');
    expect(repo.lastWeeklyCheckinPayload?['wins'], 'Better sleep');
    expect(repo.lastWeeklyCheckinPayload?['blockers'], 'Late meetings');
    expect(repo.lastWeeklyCheckinPayload?['questions'], 'Adjust cardio?');
    expect(find.text('Weekly check-in submitted.'), findsOneWidget);
  });

  testWidgets('advanced validation blocks final submit', (tester) async {
    final repo = _repoWithActiveSubscription();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterQuickRequired(tester);
    await _goToAdvanced(tester);
    await _enterText(tester, 'Nutrition %', '130');
    await _tapButton(tester, 'Submit Check-in');

    expect(
      find.text('Nutrition adherence must be between 0 and 100.'),
      findsOneWidget,
    );
    expect(repo.submitWeeklyCheckinCalls, 0);
  });

  testWidgets('quick loading state prevents double submit', (tester) async {
    final repo = _repoWithActiveSubscription()
      ..submitWeeklyCheckinCompleter = Completer<void>();
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterQuickRequired(tester);
    await _tapButton(tester, 'Submit Quick Check-in');
    await tester.pump();

    expect(repo.submitWeeklyCheckinCalls, 1);
    expect(find.text('Submitting...'), findsOneWidget);

    await tester.tap(find.text('Submitting...'), warnIfMissed: false);
    await tester.pump();

    expect(repo.submitWeeklyCheckinCalls, 1);

    repo.submitWeeklyCheckinCompleter!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('advanced submit failure keeps step and preserves input', (
    tester,
  ) async {
    final repo = _repoWithActiveSubscription()
      ..submitWeeklyCheckinError = StateError('network down');
    await _pumpScreen(tester, repo);
    await _openDialog(tester);

    await _enterQuickRequired(tester);
    await _goToAdvanced(tester);
    await _enterText(tester, 'Wins', 'Hit all sessions');
    await _tapButton(tester, 'Submit Check-in');
    await tester.pumpAndSettle();

    expect(repo.submitWeeklyCheckinCalls, 1);
    expect(find.text('Advanced Details'), findsOneWidget);
    expect(
      find.textContaining('Weekly check-in could not be submitted:'),
      findsOneWidget,
    );
    expect(find.text('Hit all sessions'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'Submit Check-in'),
      findsOneWidget,
    );
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

Future<void> _enterQuickRequired(WidgetTester tester) async {
  await _enterText(tester, 'Adherence %', '80');
  await _enterText(tester, 'Energy 1-10', '7');
  await _enterText(tester, 'Sleep 1-10', '6');
}

Future<void> _goToAdvanced(WidgetTester tester) async {
  await _tapButton(tester, 'Next: Advanced Details');
}

Future<void> _enterText(WidgetTester tester, String label, String value) async {
  final finder = find.widgetWithText(TextField, label);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pump();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}
