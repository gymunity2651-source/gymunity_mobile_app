import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/member/domain/entities/coach_hub_entity.dart';
import 'package:my_app/features/member/presentation/screens/member_coach_resources_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('missing resource URL and storage path shows unavailable', (
    tester,
  ) async {
    final repo = _repoWithResource(
      const MemberAssignedResourceEntity(
        id: 'assignment-1',
        resourceId: 'resource-1',
        subscriptionId: 'sub-1',
        coachId: 'coach-1',
        memberId: 'member-1',
        title: 'Missing file',
      ),
    );
    await _pumpScreen(tester, repo);

    await _tapOpen(tester);

    expect(repo.createCoachResourceSignedUrlCalls, 0);
    expect(find.text('Resource file unavailable.'), findsOneWidget);
  });

  testWidgets('blank storage path is treated as unavailable', (tester) async {
    final repo = _repoWithResource(
      const MemberAssignedResourceEntity(
        id: 'assignment-1',
        resourceId: 'resource-1',
        subscriptionId: 'sub-1',
        coachId: 'coach-1',
        memberId: 'member-1',
        title: 'Blank file',
        storagePath: '   ',
      ),
    );
    await _pumpScreen(tester, repo);

    await _tapOpen(tester);

    expect(repo.createCoachResourceSignedUrlCalls, 0);
    expect(find.text('Resource file unavailable.'), findsOneWidget);
  });

  testWidgets('valid storage path requests signed URL with exact path', (
    tester,
  ) async {
    final repo = _repoWithResource(
      const MemberAssignedResourceEntity(
        id: 'assignment-1',
        resourceId: 'resource-1',
        subscriptionId: 'sub-1',
        coachId: 'coach-1',
        memberId: 'member-1',
        title: 'Meal plan PDF',
        storagePath: 'coach-resources/meal-plan.pdf',
      ),
    );
    await _pumpScreen(tester, repo);

    await _tapOpen(tester);

    expect(repo.createCoachResourceSignedUrlCalls, 1);
    expect(
      repo.lastCoachResourceSignedUrlPath,
      'coach-resources/meal-plan.pdf',
    );
    expect(find.text('Resource file unavailable.'), findsNothing);
  });

  testWidgets('valid external URL does not request signed URL', (tester) async {
    final repo = _repoWithResource(
      const MemberAssignedResourceEntity(
        id: 'assignment-1',
        resourceId: 'resource-1',
        subscriptionId: 'sub-1',
        coachId: 'coach-1',
        memberId: 'member-1',
        title: 'External guide',
        externalUrl: 'https://example.test/guide',
      ),
    );
    await _pumpScreen(tester, repo);

    await _tapOpen(tester);

    expect(repo.createCoachResourceSignedUrlCalls, 0);
    expect(find.text('Resource file unavailable.'), findsNothing);
  });
}

FakeMemberRepository _repoWithResource(MemberAssignedResourceEntity resource) {
  return FakeMemberRepository()
    ..assignedResources = <MemberAssignedResourceEntity>[resource];
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
        home: MemberCoachResourcesScreen(subscriptionId: 'sub-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapOpen(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Open'));
  await tester.pumpAndSettle();
}
