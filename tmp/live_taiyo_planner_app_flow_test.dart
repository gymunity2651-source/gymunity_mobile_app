import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/ai_chat/domain/entities/planner_turn_result.dart';
import 'package:my_app/features/member/domain/entities/member_profile_entity.dart';
import 'package:my_app/features/member/domain/entities/member_progress_entity.dart';
import 'package:my_app/features/planner/data/repositories/planner_repository_impl.dart';
import 'package:my_app/features/planner/presentation/screens/planner_builder_screen.dart';

import '../test/test_doubles.dart';

class _RecordingPlannerRepository extends PlannerRepositoryImpl {
  _RecordingPlannerRepository(super.client);

  int calls = 0;
  String? lastRequestType;
  Map<String, dynamic>? lastAnswers;
  PlannerTurnResult? lastResult;

  @override
  Future<PlannerTurnResult> requestTaiyoWorkoutPlanDraft({
    required Map<String, dynamic> plannerAnswers,
    String? sessionId,
    String? draftId,
    String requestType = 'workout_plan_draft',
  }) async {
    calls += 1;
    lastRequestType = requestType;
    lastAnswers = Map<String, dynamic>.from(plannerAnswers);
    final result = await super.requestTaiyoWorkoutPlanDraft(
      plannerAnswers: plannerAnswers,
      sessionId: sessionId,
      draftId: draftId,
      requestType: requestType,
    );
    lastResult = result;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const runLive = bool.fromEnvironment('RUN_LIVE_TAIYO_PLANNER_APP_FLOW');
  if (!runLive) {
    test(
      'live TAIYO planner app flow is skipped by default',
      () {},
      skip: 'Set RUN_LIVE_TAIYO_PLANNER_APP_FLOW=true to run this probe.',
    );
    return;
  }

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const memberEmail = String.fromEnvironment('MEMBER_EMAIL');
  const memberPassword = String.fromEnvironment('MEMBER_PASSWORD');

  testWidgets('builder generates and reviews a deployed TAIYO plan', (
    tester,
  ) async {
    expect(supabaseUrl, isNotEmpty);
    expect(supabaseAnonKey, isNotEmpty);
    expect(memberEmail, isNotEmpty);
    expect(memberPassword, isNotEmpty);

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    final client = Supabase.instance.client;
    final authResponse = await client.auth.signInWithPassword(
      email: memberEmail,
      password: memberPassword,
    );
    expect(authResponse.session, isNotNull);

    final plannerRepository = _RecordingPlannerRepository(client);
    final memberRepository = FakeMemberRepository()
      ..profile = const MemberProfileEntity(
        userId: 'live-member',
        goal: 'weight_loss',
        experienceLevel: 'beginner',
        trainingFrequency: '3_4_days_per_week',
        trainingPlace: 'home',
      )
      ..workoutSessions = <WorkoutSessionEntity>[
        WorkoutSessionEntity(
          id: 'recent-session',
          memberId: 'live-member',
          title: 'Recent workout',
          performedAt: DateTime(2026, 4, 25),
          durationMinutes: 45,
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          supabaseClientProvider.overrideWithValue(client),
          memberRepositoryProvider.overrideWithValue(memberRepository),
          plannerRepositoryProvider.overrideWithValue(plannerRepository),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: const PlannerBuilderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('planner-builder-start-button')),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 20; i += 1) {
      if (find.text('Review answers').evaluate().isNotEmpty) {
        await tester.ensureVisible(find.text('Review answers'));
        await tester.tap(find.text('Review answers'));
        await tester.pumpAndSettle();
        break;
      }
      if (find.text('Next').evaluate().isNotEmpty) {
        await tester.ensureVisible(find.text('Next'));
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
    }

    await tester.ensureVisible(find.text('Generate plan'));
    await tester.tap(find.text('Generate plan'));
    await tester.pump();

    await _pumpUntil(
      tester,
      () => plannerRepository.calls >= 1 &&
          plannerRepository.lastResult?.draftId != null,
      timeout: const Duration(seconds: 120),
    );

    expect(plannerRepository.lastRequestType, 'workout_plan_draft');
    expect(plannerRepository.lastAnswers?['session_minutes'], 45);
    expect(plannerRepository.lastResult?.status, 'plan_ready');
    expect(plannerRepository.lastResult?.draftId, isNotNull);

    await _pumpUntil(
      tester,
      () => find.text('TAIYO PLAN REVIEW').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 45),
    );

    await tester.ensureVisible(find.text('Improve plan'));
    await tester.tap(find.text('Improve plan'));
    await tester.pump();

    await _pumpUntil(
      tester,
      () => plannerRepository.calls >= 2 &&
          plannerRepository.lastRequestType == 'plan_review',
      timeout: const Duration(seconds: 120),
    );

    expect(plannerRepository.lastRequestType, 'plan_review');
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for live planner app flow condition.');
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
}
