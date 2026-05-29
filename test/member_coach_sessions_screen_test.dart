import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/coach/domain/entities/coach_workspace_entity.dart';
import 'package:my_app/features/member/presentation/screens/member_coach_sessions_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('cancel opens confirmation and does not call repository', (
    tester,
  ) async {
    final repo = _repoWithBooking();
    await _pumpScreen(tester, repo);

    await _openCancelDialog(tester);

    expect(find.text('Cancel session?'), findsOneWidget);
    expect(repo.updateMemberBookingStatusCalls, 0);
  });

  testWidgets('keep session closes dialog without cancelling', (tester) async {
    final repo = _repoWithBooking();
    await _pumpScreen(tester, repo);

    await _openCancelDialog(tester);
    await tester.tap(find.text('Keep Session'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel session?'), findsNothing);
    expect(repo.updateMemberBookingStatusCalls, 0);
    expect(find.text('Strategy Call'), findsOneWidget);
  });

  testWidgets('confirm cancellation calls repository once with payload', (
    tester,
  ) async {
    final repo = _repoWithBooking();
    await _pumpScreen(tester, repo);

    await _openCancelDialog(tester);
    await tester.tap(
      find.byKey(const Key('member-confirm-cancel-session-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.updateMemberBookingStatusCalls, 1);
    expect(repo.lastUpdatedMemberBookingId, 'booking-1');
    expect(repo.lastUpdatedMemberBookingStatus, 'cancelled');
    expect(repo.lastUpdatedMemberBookingReason, 'Cancelled by member');
    expect(find.text('Session cancelled.'), findsOneWidget);
  });

  testWidgets('loading prevents duplicate cancellation', (tester) async {
    final repo = _repoWithBooking()
      ..updateMemberBookingStatusCompleter = Completer<void>();
    await _pumpScreen(tester, repo);

    await _openCancelDialog(tester);
    await tester.tap(
      find.byKey(const Key('member-confirm-cancel-session-button')),
    );
    await tester.pump();

    expect(repo.updateMemberBookingStatusCalls, 1);
    expect(find.text('Cancelling...'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('member-confirm-cancel-session-button')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(repo.updateMemberBookingStatusCalls, 1);

    repo.updateMemberBookingStatusCompleter!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Session cancelled.'), findsOneWidget);
  });

  testWidgets('failure shows error and keeps confirmation open', (
    tester,
  ) async {
    final repo = _repoWithBooking()
      ..updateMemberBookingStatusError = StateError('network down');
    await _pumpScreen(tester, repo);

    await _openCancelDialog(tester);
    await tester.tap(
      find.byKey(const Key('member-confirm-cancel-session-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.updateMemberBookingStatusCalls, 1);
    expect(
      find.textContaining('Session could not be cancelled:'),
      findsOneWidget,
    );
    expect(find.text('Cancel session?'), findsOneWidget);
    expect(find.text('Cancel Session'), findsOneWidget);
  });

  testWidgets('non-cancellable booking has no cancel action', (tester) async {
    final repo = _repoWithBooking(status: 'completed');
    await _pumpScreen(tester, repo);

    expect(
      find.byKey(const Key('member-session-cancel-action-booking-1')),
      findsNothing,
    );
  });
}

FakeMemberRepository _repoWithBooking({String status = 'scheduled'}) {
  return FakeMemberRepository()
    ..coachBookings = <CoachBookingEntity>[
      CoachBookingEntity(
        id: 'booking-1',
        coachId: 'coach-1',
        memberId: 'member-1',
        subscriptionId: 'sub-1',
        sessionTypeId: 'session-type-1',
        title: 'Strategy Call',
        startsAt: DateTime(2026, 6, 1, 10),
        endsAt: DateTime(2026, 6, 1, 10, 45),
        status: status,
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
      child: const MaterialApp(
        home: MemberCoachSessionsScreen(subscriptionId: 'sub-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openCancelDialog(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('member-session-cancel-action-booking-1')),
  );
  await tester.pumpAndSettle();
}
