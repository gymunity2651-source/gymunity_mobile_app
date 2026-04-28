import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/ai_coach/domain/entities/ai_coach_entities.dart';
import 'package:my_app/features/ai_coach/presentation/screens/ai_coach_home_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('disables workout day actions when brief has no linked day', (
    tester,
  ) async {
    final fakeRepository = FakeAiCoachRepository()
      ..dailyBrief = AiDailyBriefEntity(
        id: 'brief-1',
        briefDate: DateTime(2026, 4, 25),
        planId: 'plan-1',
        primaryTaskId: 'task-1',
        readinessScore: 55,
        intensityBand: 'yellow',
        coachMode: false,
        recommendedWorkout: const <String, dynamic>{
          'title': 'Today\'s plan',
          'duration_minutes': 35,
        },
        whyShort: 'TAIYO picked a finishable session for today.',
        confidence: 0.85,
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiCoachRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const MaterialApp(home: AiCoachHomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Today\'s plan'), findsOneWidget);

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start workout'),
    );
    final shortenButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Shorten'),
    );
    final moveButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Move to tomorrow'),
    );

    expect(startButton.onPressed, isNull);
    expect(shortenButton.onPressed, isNull);
    expect(moveButton.onPressed, isNull);
  });
}
