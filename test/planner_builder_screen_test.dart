import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/ai_chat/domain/entities/planner_turn_result.dart';
import 'package:my_app/features/member/domain/entities/member_profile_entity.dart';
import 'package:my_app/features/member/domain/entities/member_progress_entity.dart';
import 'package:my_app/features/planner/presentation/screens/planner_builder_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('start scans context and opens structured question cards', (
    tester,
  ) async {
    final memberRepository = FakeMemberRepository()
      ..profile = const MemberProfileEntity(
        userId: 'member-1',
        goal: 'weight_loss',
        experienceLevel: 'beginner',
        trainingFrequency: '3_4_days_per_week',
        trainingPlace: 'home',
      );

    await _pumpBuilder(tester, memberRepository: memberRepository);

    await tester.tap(
      find.byKey(const ValueKey<String>('planner-builder-start-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Is this still your main goal?'), findsOneWidget);
    expect(find.text('Pre-filled from your data'), findsOneWidget);
    expect(find.textContaining('Step 1 of'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('needs more info keeps the member inside the builder', (
    tester,
  ) async {
    final memberRepository = FakeMemberRepository()
      ..profile = const MemberProfileEntity(
        userId: 'member-1',
        goal: 'weight_loss',
        experienceLevel: 'beginner',
        trainingFrequency: '3_4_days_per_week',
        trainingPlace: 'home',
      )
      ..workoutSessions = <WorkoutSessionEntity>[
        WorkoutSessionEntity(
          id: 'session-1',
          memberId: 'member-1',
          title: 'Full body',
          performedAt: DateTime(2026, 3, 8),
          durationMinutes: 45,
        ),
      ];
    final plannerRepository = FakePlannerRepository()
      ..nextTaiyoPlanResult = const PlannerTurnResult(
        assistantMessage: 'I need your equipment before generating.',
        status: 'needs_more_info',
        draftId: 'draft-1',
        missingFields: <String>['equipment'],
      );

    await _pumpBuilder(
      tester,
      memberRepository: memberRepository,
      plannerRepository: plannerRepository,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('planner-builder-start-button')),
    );
    await tester.pumpAndSettle();

    // Jump through the guided UI using visible actions; critical values are
    // preselected from profile, inferred equipment, and recent session length.
    while (find.text('Review answers').evaluate().isEmpty) {
      if (find.text('Next').evaluate().isNotEmpty) {
        await tester.ensureVisible(find.text('Next'));
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      } else {
        break;
      }
    }
    if (find.text('Review answers').evaluate().isNotEmpty) {
      await tester.ensureVisible(find.text('Review answers'));
      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Generate plan'));
    await tester.tap(find.text('Generate plan'));
    await tester.pumpAndSettle();

    expect(find.text('Review available equipment'), findsOneWidget);
    expect(find.byType(PlannerBuilderScreen), findsOneWidget);
    expect(plannerRepository.requestTaiyoWorkoutPlanDraftCalls, 1);
    expect(plannerRepository.lastTaiyoPlannerRequestType, 'workout_plan_draft');
    expect(plannerRepository.lastTaiyoPlannerAnswers?['goal'], 'weight_loss');
  });
}

Future<void> _pumpBuilder(
  WidgetTester tester, {
  required FakeMemberRepository memberRepository,
  FakeChatRepository? chatRepository,
  FakePlannerRepository? plannerRepository,
}) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        memberRepositoryProvider.overrideWithValue(memberRepository),
        chatRepositoryProvider.overrideWithValue(
          chatRepository ?? FakeChatRepository(),
        ),
        plannerRepositoryProvider.overrideWithValue(
          plannerRepository ?? FakePlannerRepository(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const PlannerBuilderScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
