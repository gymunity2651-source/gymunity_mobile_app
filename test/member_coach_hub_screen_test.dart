import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/member/domain/entities/coach_hub_entity.dart';
import 'package:my_app/features/member/presentation/screens/member_coach_hub_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('active subscription renders Coach Hub agenda and actions', (
    tester,
  ) async {
    final repo = FakeMemberRepository()
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
          threadId: 'thread-1',
        ),
      ]
      ..coachAgenda = <MemberCoachAgendaItemEntity>[
        MemberCoachAgendaItemEntity(
          id: 'agenda-1',
          type: 'habit',
          title: 'Walk 8k steps',
          subscriptionId: 'sub-1',
          status: 'pending',
        ),
      ]
      ..assignedHabits = const <MemberAssignedHabitEntity>[
        MemberAssignedHabitEntity(
          id: 'habit-1',
          subscriptionId: 'sub-1',
          coachId: 'coach-1',
          memberId: 'member-1',
          title: 'Protein target',
          adherencePercent: 70,
        ),
      ]
      ..assignedResources = const <MemberAssignedResourceEntity>[
        MemberAssignedResourceEntity(
          id: 'resource-assignment-1',
          resourceId: 'resource-1',
          subscriptionId: 'sub-1',
          coachId: 'coach-1',
          memberId: 'member-1',
          title: 'Meal guide',
          resourceType: 'link',
          externalUrl: 'https://example.test/meal-guide',
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[memberRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: const MemberCoachHubScreen(subscriptionId: 'sub-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Coach Lina'), findsOneWidget);
    expect(find.text('Today from your coach'), findsOneWidget);
    expect(find.text('Walk 8k steps'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Protein target'),
      400,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Protein target'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Meal guide'),
      400,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Meal guide'), findsWidgets);
  });
}
