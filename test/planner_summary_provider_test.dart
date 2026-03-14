import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/planner/domain/entities/planner_entities.dart';
import 'package:my_app/features/planner/presentation/providers/planner_providers.dart';

void main() {
  test(
    'today agenda summary counts pending, completed, and missed tasks',
    () async {
      final container = ProviderContainer(
        overrides: <Override>[
          todayAgendaProvider.overrideWith((ref) async {
            return <PlanTaskEntity>[
              _task('pending', TaskCompletionStatus.pending),
              _task('completed', TaskCompletionStatus.completed),
              _task('missed', TaskCompletionStatus.missed),
              _task('partial', TaskCompletionStatus.partial),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(todayAgendaProvider.future);
      final summary = container.read(todayAgendaSummaryProvider);

      expect(summary.tasks, hasLength(4));
      expect(summary.pendingCount, 1);
      expect(summary.completedCount, 1);
      expect(summary.missedCount, 1);
    },
  );
}

PlanTaskEntity _task(String id, TaskCompletionStatus status) {
  return PlanTaskEntity(
    planId: 'plan-1',
    planTitle: 'Plan',
    planStatus: 'active',
    planSource: 'ai',
    dayId: 'day-1',
    weekNumber: 1,
    dayNumber: 1,
    dayIndex: 1,
    dayLabel: 'Day 1',
    scheduledDate: DateTime(2026, 3, 13),
    taskId: id,
    taskType: 'workout',
    title: 'Task $id',
    instructions: 'Do the thing',
    isRequired: true,
    sortOrder: 0,
    completionStatus: status,
  );
}
