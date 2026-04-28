import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/ai_coach/domain/entities/ai_coach_entities.dart';
import 'package:my_app/features/ai_coach/presentation/screens/active_workout_session_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('active workout uses the Atelier home DNA', (tester) async {
    final repo = FakeAiCoachRepository()
      ..activeWorkoutSession = ActiveWorkoutSessionEntity(
        id: 'session-1',
        status: 'active',
        startedAt: DateTime(2026, 4, 25, 10),
        plannedMinutes: 35,
        readinessScore: 72,
        whyShort: 'TAIYO is pacing today around readiness.',
        wasShortened: false,
        wasSwapped: false,
        confidence: 0.9,
        summary: const <String, dynamic>{
          'plan_title': 'Strength Atelier',
          'day_label': 'Upper Strength',
          'day_focus': 'Pressing and posture',
          'tasks': [
            {
              'task_id': 'task-1',
              'title': 'Bench Press',
              'task_type': 'workout',
              'instructions': 'Keep the tempo controlled and smooth.',
              'sets': 3,
              'reps': 8,
              'sort_order': 0,
            },
          ],
          'completed_task_ids': [],
          'partial_task_ids': [],
          'skipped_task_ids': [],
        },
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          aiCoachRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: ActiveWorkoutSessionScreen(sessionId: 'session-1'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('ACTIVE RITUAL'), findsOneWidget);
    expect(find.text('Upper Strength'), findsOneWidget);
    expect(find.text('Session Flow'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Finish with context'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Finish with context'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
  });
}
