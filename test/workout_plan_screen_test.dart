import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/planner/domain/entities/planner_entities.dart';
import 'package:my_app/features/planner/presentation/providers/planner_providers.dart';
import 'package:my_app/features/planner/presentation/screens/workout_plan_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets(
    'compact reminder card stacks the action below content without overflow',
    (WidgetTester tester) async {
      await _pumpWorkoutPlanScreen(
        tester,
        size: const Size(320, 640),
        plan: _buildPlan(reminderTime: '07:00:00'),
      );

      expect(find.text('7:00 AM'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final timeRect = tester.getRect(
        find.byKey(const ValueKey<String>('workout-plan-reminder-time')),
      );
      final buttonRect = tester.getRect(
        find.byKey(const ValueKey<String>('workout-plan-reminder-button')),
      );

      expect(buttonRect.top, greaterThan(timeRect.bottom));
    },
  );

  testWidgets('wide reminder card keeps the action beside the content', (
    WidgetTester tester,
  ) async {
    await _pumpWorkoutPlanScreen(
      tester,
      size: const Size(412, 915),
      plan: _buildPlan(reminderTime: '07:00:00'),
    );

    final timeRect = tester.getRect(
      find.byKey(const ValueKey<String>('workout-plan-reminder-time')),
    );
    final buttonRect = tester.getRect(
      find.byKey(const ValueKey<String>('workout-plan-reminder-button')),
    );

    expect(buttonRect.left, greaterThan(timeRect.left));
    expect(buttonRect.top, lessThan(timeRect.bottom));
  });

  testWidgets('reminder card shows not set state with set reminder action', (
    WidgetTester tester,
  ) async {
    await _pumpWorkoutPlanScreen(
      tester,
      size: const Size(390, 844),
      plan: _buildPlan(reminderTime: null),
    );

    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('Set reminder'), findsOneWidget);
  });

  testWidgets('active future plan exposes next workout actions', (
    WidgetTester tester,
  ) async {
    await _pumpWorkoutPlanScreen(
      tester,
      size: const Size(390, 844),
      plan: _buildPlan(reminderTime: '07:00:00'),
      scrollToReminder: false,
    );

    await tester.dragUntilVisible(
      find.text('Your plan is active'),
      find.byType(Scrollable),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your plan is active'), findsOneWidget);
    expect(find.text('Start next workout'), findsOneWidget);
    expect(find.text('Review day'), findsOneWidget);
  });

  testWidgets('reminder card shows saving state with disabled action', (
    WidgetTester tester,
  ) async {
    await _pumpWorkoutPlanScreen(
      tester,
      size: const Size(390, 844),
      plan: _buildPlan(reminderTime: '07:00:00'),
      actionState: const PlannerActionState(isUpdatingReminder: true),
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey<String>('workout-plan-reminder-button')),
    );

    expect(find.text('Saving...'), findsOneWidget);
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpWorkoutPlanScreen(
  WidgetTester tester, {
  required Size size,
  required PlanDetailEntity plan,
  PlannerActionState actionState = const PlannerActionState(),
  bool scrollToReminder = true,
}) async {
  tester.view.physicalSize = size;
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
        plannerActionControllerProvider.overrideWith(
          (ref) => _FakePlannerActionController(ref, actionState),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: WorkoutPlanScreen(planId: plan.planId),
      ),
    ),
  );

  await tester.pumpAndSettle();
  if (scrollToReminder) {
    await tester.dragUntilVisible(
      find.byKey(const ValueKey<String>('workout-plan-reminder-button')),
      find.byType(Scrollable),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
  }
}

PlanDetailEntity _buildPlan({required String? reminderTime}) {
  final firstDayDate = DateTime.now().add(const Duration(days: 1));
  final secondDayDate = DateTime.now().add(const Duration(days: 2));

  final firstDayTasks = <PlanTaskEntity>[
    _buildTask(
      id: 'task-1',
      dayId: 'day-1',
      dayLabel: 'Day 1',
      scheduledDate: firstDayDate,
      title: 'Dynamic Warm-up',
      reminderTime: reminderTime,
      sortOrder: 0,
    ),
    _buildTask(
      id: 'task-2',
      dayId: 'day-1',
      dayLabel: 'Day 1',
      scheduledDate: firstDayDate,
      title: 'Treadmill Run',
      reminderTime: reminderTime,
      sortOrder: 1,
    ),
  ];

  final secondDayTasks = <PlanTaskEntity>[
    _buildTask(
      id: 'task-3',
      dayId: 'day-2',
      dayLabel: 'Day 2',
      scheduledDate: secondDayDate,
      title: 'Stretching',
      reminderTime: reminderTime,
      sortOrder: 0,
    ),
  ];

  return PlanDetailEntity(
    planId: 'plan-1',
    planTitle: '4-Week Beginner Weight-Loss Program',
    planStatus: 'active',
    planSource: 'ai',
    defaultReminderTime: reminderTime,
    days: <PlanDayEntity>[
      PlanDayEntity(
        id: 'day-1',
        weekNumber: 1,
        dayNumber: 1,
        dayIndex: 1,
        scheduledDate: firstDayDate,
        label: 'Day 1',
        tasks: firstDayTasks,
      ),
      PlanDayEntity(
        id: 'day-2',
        weekNumber: 1,
        dayNumber: 2,
        dayIndex: 2,
        scheduledDate: secondDayDate,
        label: 'Day 2',
        tasks: secondDayTasks,
      ),
    ],
  );
}

PlanTaskEntity _buildTask({
  required String id,
  required String dayId,
  required String dayLabel,
  required DateTime scheduledDate,
  required String title,
  required String? reminderTime,
  required int sortOrder,
}) {
  return PlanTaskEntity(
    planId: 'plan-1',
    planTitle: '4-Week Beginner Weight-Loss Program',
    planStatus: 'active',
    planSource: 'ai',
    dayId: dayId,
    weekNumber: 1,
    dayNumber: dayId == 'day-1' ? 1 : 2,
    dayIndex: dayId == 'day-1' ? 1 : 2,
    dayLabel: dayLabel,
    scheduledDate: scheduledDate,
    taskId: id,
    taskType: 'workout',
    title: title,
    instructions: 'Do the thing.',
    reminderTime: reminderTime,
    isRequired: true,
    sortOrder: sortOrder,
    completionStatus: TaskCompletionStatus.pending,
  );
}

class _FakePlannerActionController extends PlannerActionController {
  _FakePlannerActionController(super.ref, PlannerActionState initialState) {
    state = initialState;
  }
}
