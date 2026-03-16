import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/planner/data/services/planner_reminder_bootstrap_service.dart';
import 'package:my_app/features/planner/domain/entities/planner_entities.dart';

void main() {
  test(
    'selectSchedulablePlannerTasks keeps only active pending AI reminders',
    () {
      final tasks = <PlanTaskEntity>[
        _task(
          id: 'active-ai',
          planSource: 'ai',
          planStatus: 'active',
          reminderTime: '07:00',
          completionStatus: TaskCompletionStatus.pending,
        ),
        _task(
          id: 'archived-ai',
          planSource: 'ai',
          planStatus: 'archived',
          reminderTime: '07:00',
          completionStatus: TaskCompletionStatus.pending,
        ),
        _task(
          id: 'completed-ai',
          planSource: 'ai',
          planStatus: 'active',
          reminderTime: '07:00',
          completionStatus: TaskCompletionStatus.completed,
        ),
        _task(
          id: 'coach-plan',
          planSource: 'coach',
          planStatus: 'active',
          reminderTime: '07:00',
          completionStatus: TaskCompletionStatus.pending,
        ),
        _task(
          id: 'no-reminder',
          planSource: 'ai',
          planStatus: 'active',
          reminderTime: null,
          completionStatus: TaskCompletionStatus.pending,
        ),
      ];

      final result = selectSchedulablePlannerTasks(tasks);

      expect(result.map((task) => task.taskId), <String>['active-ai']);
    },
  );

  test('selectSchedulablePlannerTasks sorts by date then reminder time', () {
    final result = selectSchedulablePlannerTasks(<PlanTaskEntity>[
      _task(
        id: 'later-time',
        scheduledDate: DateTime(2026, 3, 15),
        reminderTime: '09:00',
      ),
      _task(
        id: 'next-day',
        scheduledDate: DateTime(2026, 3, 16),
        reminderTime: '07:00',
      ),
      _task(
        id: 'earlier-time',
        scheduledDate: DateTime(2026, 3, 15),
        reminderTime: '07:00',
      ),
    ]);

    expect(result.map((task) => task.taskId), <String>[
      'earlier-time',
      'later-time',
      'next-day',
    ]);
  });
}

PlanTaskEntity _task({
  required String id,
  String planSource = 'ai',
  String planStatus = 'active',
  DateTime? scheduledDate,
  String? reminderTime = '07:00',
  TaskCompletionStatus completionStatus = TaskCompletionStatus.pending,
}) {
  return PlanTaskEntity(
    planId: 'plan-1',
    planTitle: 'Plan',
    planStatus: planStatus,
    planSource: planSource,
    dayId: 'day-1',
    weekNumber: 1,
    dayNumber: 1,
    dayIndex: 1,
    dayLabel: 'Day 1',
    scheduledDate: scheduledDate ?? DateTime(2026, 3, 15),
    taskId: id,
    taskType: 'workout',
    title: 'Task $id',
    instructions: 'Do the thing',
    reminderTime: reminderTime,
    isRequired: true,
    sortOrder: 0,
    completionStatus: completionStatus,
  );
}
