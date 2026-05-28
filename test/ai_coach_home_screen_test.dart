import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/app/routes.dart';
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

  testWidgets('specialist agent cards open their owned workflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final openedRoutes = <RouteSettings>[];
    final chatRepository = FakeChatRepository();
    final fakeRepository = FakeAiCoachRepository()
      ..dailyBrief = AiDailyBriefEntity(
        id: 'brief-1',
        briefDate: DateTime(2026, 4, 25),
        planId: 'plan-1',
        readinessScore: 72,
        intensityBand: 'green',
        coachMode: false,
        recommendedWorkout: const <String, dynamic>{
          'title': 'Foundation strength',
          'duration_minutes': 35,
        },
        whyShort: 'TAIYO matched this to your recent rhythm.',
        confidence: 0.85,
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiCoachRepositoryProvider.overrideWithValue(fakeRepository),
          chatRepositoryProvider.overrideWithValue(chatRepository),
        ],
        child: MaterialApp(
          home: const AiCoachHomeScreen(),
          onGenerateRoute: (settings) {
            openedRoutes.add(settings);
            return PageRouteBuilder<void>(
              settings: settings,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (context, animation, secondaryAnimation) =>
                  Scaffold(body: Text(settings.name ?? 'route')),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final expectedRoutes = <String, String>{
      'Plan Builder': AppRoutes.aiPlannerBuilder,
      'AI Chatbot': AppRoutes.aiConversation,
      'Nutrition Copilot': AppRoutes.nutrition,
      'Store Optimizer': AppRoutes.storeHome,
    };

    for (final entry in expectedRoutes.entries) {
      final finder = find.text(entry.key);
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(openedRoutes.last.name, entry.value);
      if (entry.key == 'AI Chatbot') {
        expect(openedRoutes.last.arguments, isA<AiConversationArgs>());
        expect(chatRepository.sessions, hasLength(1));
        expect(chatRepository.sessions.single.type.name, 'general');
      }

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
    }
  });

  testWidgets('today readiness submits selected signals', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeRepository = FakeAiCoachRepository()
      ..dailyBrief = AiDailyBriefEntity(
        id: 'brief-1',
        briefDate: DateTime(2026, 4, 25),
        planId: 'plan-1',
        readinessScore: 72,
        intensityBand: 'green',
        coachMode: false,
        recommendedWorkout: const <String, dynamic>{
          'title': 'Foundation strength',
          'duration_minutes': 35,
        },
        whyShort: 'TAIYO matched this to your recent rhythm.',
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

    await tester.ensureVisible(find.text('60 min'));
    await tester.tap(find.text('60 min'));
    await tester.tap(find.text('HOME'));
    await tester.tap(find.text('Update today'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fakeRepository.readinessLog, isNotNull);
    expect(fakeRepository.readinessLog!.energyLevel, 3);
    expect(fakeRepository.readinessLog!.sorenessLevel, 3);
    expect(fakeRepository.readinessLog!.stressLevel, 3);
    expect(fakeRepository.readinessLog!.availableMinutes, 60);
    expect(fakeRepository.readinessLog!.locationMode, 'home');
    expect(
      find.textContaining('Updated: YELLOW readiness at 61'),
      findsOneWidget,
    );
  });
}
