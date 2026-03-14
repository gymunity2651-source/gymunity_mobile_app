import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/planner/data/services/planner_notification_ids.dart';

void main() {
  test(
    'planner notification ids are stable for the same task and reminder',
    () {
      final first = buildPlannerNotificationId(
        taskId: 'task-1',
        scheduledDate: DateTime(2026, 3, 13),
        reminderTime: '07:30',
      );
      final second = buildPlannerNotificationId(
        taskId: 'TASK-1',
        scheduledDate: DateTime(2026, 3, 13, 18, 45),
        reminderTime: '07:30',
      );

      expect(first, second);
    },
  );

  test('planner notification ids change when reminder inputs change', () {
    final base = buildPlannerNotificationId(
      taskId: 'task-1',
      scheduledDate: DateTime(2026, 3, 13),
      reminderTime: '07:30',
    );
    final differentTime = buildPlannerNotificationId(
      taskId: 'task-1',
      scheduledDate: DateTime(2026, 3, 13),
      reminderTime: '08:30',
    );
    final differentDate = buildPlannerNotificationId(
      taskId: 'task-1',
      scheduledDate: DateTime(2026, 3, 14),
      reminderTime: '07:30',
    );

    expect(differentTime, isNot(base));
    expect(differentDate, isNot(base));
  });
}
