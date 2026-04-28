import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/planner/domain/entities/planner_entities.dart';
import 'package:my_app/features/planner/presentation/screens/ai_generated_plan_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('AI generated plan review renders editorial review controls', (
    tester,
  ) async {
    final plannerRepository = FakePlannerRepository()
      ..drafts['draft-1'] = PlannerDraftEntity(
        id: 'draft-1',
        userId: 'member-1',
        sessionId: 'session-1',
        status: 'plan_ready',
        assistantMessage: 'Your plan is ready to review.',
        plan: GeneratedPlanEntity(
          title: 'Curated Strength Ritual',
          summary: 'A calm four-week strength plan shaped around recovery.',
          durationWeeks: 4,
          level: 'beginner',
          startDateSuggestion: DateTime(2026, 4, 26),
          restGuidance: 'Keep one full recovery day between strength sessions.',
          hydrationGuidance: 'Start each session hydrated.',
          safetyNotes: const <String>['Stop if sharp pain appears.'],
          weeklyStructure: const <GeneratedPlanWeekEntity>[
            GeneratedPlanWeekEntity(
              weekNumber: 1,
              days: <GeneratedPlanDayEntity>[
                GeneratedPlanDayEntity(
                  weekNumber: 1,
                  dayNumber: 1,
                  label: 'Upper Strength',
                  focus: 'Controlled pressing and posture.',
                  tasks: <GeneratedPlanTaskEntity>[
                    GeneratedPlanTaskEntity(
                      type: 'workout',
                      title: 'Incline press',
                      instructions: 'Move with control.',
                      reminderTime: '07:00',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        createdAt: DateTime(2026, 4, 25),
        updatedAt: DateTime(2026, 4, 25),
      );

    await _pumpReview(tester, plannerRepository);

    expect(find.text('TAIYO PLAN REVIEW'), findsOneWidget);
    expect(find.text('Curated Strength Ritual'), findsOneWidget);
    expect(find.text('Activation settings'), findsOneWidget);
    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('Default reminder'), findsOneWidget);

    await tester.ensureVisible(find.text('Improve plan'));
    expect(find.text('Improve plan'), findsOneWidget);
    expect(find.text('Edit builder answers'), findsOneWidget);

    await tester.ensureVisible(find.text('Approve and activate'));
    expect(find.text('Approve and activate'), findsOneWidget);
  });
}

Future<void> _pumpReview(
  WidgetTester tester,
  FakePlannerRepository plannerRepository,
) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        plannerRepositoryProvider.overrideWithValue(plannerRepository),
        chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AiGeneratedPlanScreen(
          sessionId: 'session-1',
          draftId: 'draft-1',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
