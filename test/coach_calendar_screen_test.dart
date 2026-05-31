import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/coach/domain/entities/coach_workspace_entity.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/coach/presentation/screens/coach_calendar_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('cancelling requires confirmation before updating', (
    tester,
  ) async {
    final repo = _repoWithBooking();
    await _pumpCalendar(tester, repo);

    await _openStatusSheet(tester);
    await _selectStatus(tester, 'Cancelled');
    await _tapSave(tester);

    expect(find.text('Cancel this booking?'), findsOneWidget);
    expect(find.text('Keep booking'), findsOneWidget);
    expect(find.text('Cancel booking'), findsOneWidget);
    expect(repo.updateBookingStatusCalls, 0);
  });

  testWidgets('dismissing cancellation confirmation does not cancel', (
    tester,
  ) async {
    final repo = _repoWithBooking();
    await _pumpCalendar(tester, repo);

    await _openStatusSheet(tester);
    await _selectStatus(tester, 'Cancelled');
    await _tapSave(tester);
    await tester.tap(find.text('Keep booking'));
    await tester.pumpAndSettle();

    expect(repo.updateBookingStatusCalls, 0);
    expect(find.text('Update booking'), findsOneWidget);
  });

  testWidgets('confirming cancellation updates status', (tester) async {
    final repo = _repoWithBooking();
    await _pumpCalendar(tester, repo);

    await _openStatusSheet(tester);
    await _selectStatus(tester, 'Cancelled');
    await _tapSave(tester);
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();

    expect(repo.updateBookingStatusCalls, 1);
    expect(repo.lastUpdatedBookingStatusPayload?['status'], 'cancelled');
    expect(find.text('Booking cancelled.'), findsOneWidget);
  });

  testWidgets('cancellation error keeps sheet open with friendly snackbar', (
    tester,
  ) async {
    final repo = _repoWithBooking()
      ..updateBookingStatusError = StateError('backend exploded');
    await _pumpCalendar(tester, repo);

    await _openStatusSheet(tester);
    await _selectStatus(tester, 'Cancelled');
    await _tapSave(tester);
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();

    expect(repo.updateBookingStatusCalls, 1);
    expect(find.text('Update booking'), findsOneWidget);
    expect(
      find.text('Booking status could not be updated. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('backend exploded'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('non-cancel status updates without confirmation', (tester) async {
    final repo = _repoWithBooking();
    await _pumpCalendar(tester, repo);

    await _openStatusSheet(tester);
    await _selectStatus(tester, 'Completed');
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(find.text('Cancel this booking?'), findsNothing);
    expect(repo.updateBookingStatusCalls, 1);
    expect(repo.lastUpdatedBookingStatusPayload?['status'], 'completed');
    expect(find.text('Booking updated.'), findsOneWidget);
  });

  testWidgets('loading prevents duplicate status update', (tester) async {
    final completer = Completer<CoachBookingEntity>();
    final repo = _repoWithBooking()..updateBookingStatusCompleter = completer;
    await _pumpCalendar(tester, repo);

    await _openStatusSheet(tester);
    await _selectStatus(tester, 'Completed');
    await _tapSave(tester);
    await tester.pump();

    expect(repo.updateBookingStatusCalls, 1);
    expect(find.text('Saving...'), findsOneWidget);

    await tester.tap(find.text('Saving...'), warnIfMissed: false);
    await tester.pump();

    expect(repo.updateBookingStatusCalls, 1);

    completer.complete(_booking(status: 'completed'));
    await tester.pumpAndSettle();

    expect(find.text('Update booking'), findsNothing);
  });
}

FakeCoachRepository _repoWithBooking({String status = 'scheduled'}) {
  return FakeCoachRepository()
    ..bookings = <CoachBookingEntity>[_booking(status: status)]
    ..sessionTypes = const <CoachSessionTypeEntity>[
      CoachSessionTypeEntity(
        id: 'session-type-1',
        title: 'Check-in call',
        sessionKind: 'weekly_checkin_call',
      ),
    ]
    ..subscriptions = const <SubscriptionEntity>[
      SubscriptionEntity(
        id: 'sub-1',
        memberId: 'member-1',
        coachId: 'coach-1',
        memberName: 'Member One',
        status: 'active',
        amount: 1200,
        planName: 'Starter',
      ),
    ];
}

CoachBookingEntity _booking({String status = 'scheduled'}) {
  return CoachBookingEntity(
    id: 'booking-1',
    coachId: 'coach-1',
    memberId: 'member-1',
    memberName: 'Member One',
    subscriptionId: 'sub-1',
    sessionTypeId: 'session-type-1',
    title: 'Weekly check-in',
    startsAt: DateTime(2026, 6, 3, 10),
    endsAt: DateTime(2026, 6, 3, 10, 45),
    status: status,
  );
}

Future<void> _pumpCalendar(
  WidgetTester tester,
  FakeCoachRepository repo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[coachRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: CoachCalendarScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openStatusSheet(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Update status'), 300);
  await tester.tap(find.text('Update status'));
  await tester.pumpAndSettle();
}

Future<void> _selectStatus(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
  await tester.pump();
}
