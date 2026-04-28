import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/ai_coach/presentation/providers/ai_coach_providers.dart';

import '../../../../test_doubles.dart';

void main() {
  group('ai coach providers', () {
    test('daily brief provider refreshes when cache is empty', () async {
      final fakeRepository = FakeAiCoachRepository();
      final container = ProviderContainer(
        overrides: [
          aiCoachRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final brief = await container.read(
        aiCoachDailyBriefProvider(DateTime(2026, 4, 21)).future,
      );

      expect(brief, isNotNull);
      expect(brief!.workoutTitle, 'Upper strength');
    });

    test('action controller starts an active workout session', () async {
      final fakeRepository = FakeAiCoachRepository();
      final container = ProviderContainer(
        overrides: [
          aiCoachRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final sessionId = await container
          .read(aiCoachActionControllerProvider.notifier)
          .startWorkout(planId: 'plan-1', dayId: 'day-1');

      expect(sessionId, 'session-1');
      expect(
        container.read(aiCoachActionControllerProvider).lastSessionId,
        'session-1',
      );
    });
  });
}
