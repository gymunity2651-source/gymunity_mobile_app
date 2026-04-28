import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/planner/domain/entities/planner_entities.dart';
import 'package:my_app/features/planner/presentation/screens/workout_day_details_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('day details uses atelier surface and preserves task actions', (
    tester,
  ) async {
    final plan = _buildPlan();
    await _pumpDayDetails(tester, plan: plan);

    expect(find.text('Day Details'), findsOneWidget);
    expect(find.text('TRAINING DAY'), findsOneWidget);
    expect(find.text('Start guided workout'), findsOneWidget);
    expect(find.text('Dynamic Warm-up'), findsOneWidget);
    expect(find.text('Skip'), findsWidgets);
    expect(find.text('Partial'), findsWidgets);
    expect(find.text('Complete'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDayDetails(
  WidgetTester tester, {
  required PlanDetailEntity plan,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final plannerRepository = FakePlannerRepository()..plans[plan.planId] = plan;

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        plannerRepositoryProvider.overrideWithValue(plannerRepository),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: WorkoutDayDetailsScreen(planId: plan.planId, dayId: 'day-1'),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

PlanDetailEntity _buildPlan() {
  final scheduledDate = DateTime(2026, 4, 26);
  final tasks = <PlanTaskEntity>[
    _buildTask(
      id: 'task-1',
      dayId: 'day-1',
      scheduledDate: scheduledDate,
      title: 'Dynamic Warm-up',
      instructions:
          'Leg swings, ankle circles, hip circles, shoulder rolls, band pull-apart warm-up.',
      durationMinutes: 5,
      sets: null,
      reps: null,
      sortOrder: 0,
    ),
    _buildTask(
      id: 'task-2',
      dayId: 'day-1',
      scheduledDate: scheduledDate,
      title: 'Band Squat',
      instructions: 'Band around thighs just above knees. Keep knees tracking.',
      durationMinutes: 8,
      sets: 3,
      reps: 12,
      sortOrder: 1,
    ),
  ];

  return PlanDetailEntity(
    planId: 'plan-1',
    planTitle: '4-Week Strength-First Upper-Lower Split',
    planStatus: 'active',
    planSource: 'ai',
    days: <PlanDayEntity>[
      PlanDayEntity(
        id: 'day-1',
        weekNumber: 1,
        dayNumber: 1,
        dayIndex: 1,
        scheduledDate: scheduledDate,
        label: 'Tuesday',
        focus: 'Legs & Shoulders',
        tasks: tasks,
      ),
    ],
  );
}

PlanTaskEntity _buildTask({
  required String id,
  required String dayId,
  required DateTime scheduledDate,
  required String title,
  required String instructions,
  required int? durationMinutes,
  required int? sets,
  required int? reps,
  required int sortOrder,
}) {
  return PlanTaskEntity(
    planId: 'plan-1',
    planTitle: '4-Week Strength-First Upper-Lower Split',
    planStatus: 'active',
    planSource: 'ai',
    dayId: dayId,
    weekNumber: 1,
    dayNumber: 1,
    dayIndex: 1,
    dayLabel: 'Tuesday',
    scheduledDate: scheduledDate,
    taskId: id,
    taskType: 'workout',
    title: title,
    instructions: instructions,
    sets: sets,
    reps: reps,
    durationMinutes: durationMinutes,
    reminderTime: '07:00:00',
    isRequired: true,
    sortOrder: sortOrder,
    completionStatus: TaskCompletionStatus.pending,
  );
}
