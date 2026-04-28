import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/ai_coach/domain/entities/ai_coach_entities.dart';
import 'package:my_app/features/coach/domain/entities/workout_plan_entity.dart';
import 'package:my_app/features/member/domain/entities/member_home_summary_entity.dart';
import 'package:my_app/features/member/domain/entities/member_progress_entity.dart';
import 'package:my_app/features/member/presentation/screens/member_home_content.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';

import 'test_doubles.dart';

void main() {
  group('Member home summary cards', () {
    testWidgets('show clean empty states when no live member data exists', (
      tester,
    ) async {
      final memberRepository = FakeMemberRepository()
        ..homeSummary = const MemberHomeSummaryEntity(activeCoachCount: 0);

      await _pumpMemberHomeContent(tester, memberRepository: memberRepository);

      expect(
        find.byKey(const Key('member-summary-active-coaches-value')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('member-summary-active-coaches-value')),
            )
            .data,
        '0',
      );
      expect(find.text('No weight data yet'), findsOneWidget);
      expect(find.text('No active plan'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('member-daily-streak-value')))
            .data,
        '0 Days Active',
      );

      for (var index = 0; index < 4; index++) {
        expect(
          find.byKey(ValueKey('member-summary-plan-dot-$index-pending')),
          findsOneWidget,
        );
      }
    });

    testWidgets(
      'show live coach count, real weight trend, and consistency dots',
      (tester) async {
        final activeAiPlan = const WorkoutPlanEntity(
          id: 'plan-ai-1',
          memberId: 'member-1',
          source: 'ai',
          title: 'Momentum Plan',
          status: 'active',
        );
        final memberRepository = FakeMemberRepository()
          ..homeSummary = MemberHomeSummaryEntity(
            activeCoachCount: 1,
            latestWeightEntry: WeightEntryEntity(
              id: 'weight-2',
              memberId: 'member-1',
              weightKg: 78.5,
              recordedAt: DateTime(2026, 4, 20),
            ),
            previousWeightEntry: WeightEntryEntity(
              id: 'weight-1',
              memberId: 'member-1',
              weightKg: 80.0,
              recordedAt: DateTime(2026, 4, 13),
            ),
            activePlan: activeAiPlan,
            activeAiPlan: activeAiPlan,
            dailyStreak: MemberDailyStreakEntity(
              currentCount: 12,
              lastActivityDate: DateTime(2026, 4, 21),
            ),
            planConsistency: MemberPlanConsistencySummary(
              currentStreakWeeks: 4,
              totalConsistentWeeks: 4,
              weeks: <MemberPlanConsistencyWeek>[
                MemberPlanConsistencyWeek(
                  weekStart: DateTime(2026, 3, 24),
                  adherenceScore: 83,
                  state: MemberPlanConsistencyState.consistent,
                ),
                MemberPlanConsistencyWeek(
                  weekStart: DateTime(2026, 3, 31),
                  adherenceScore: 79,
                  state: MemberPlanConsistencyState.consistent,
                ),
                MemberPlanConsistencyWeek(
                  weekStart: DateTime(2026, 4, 7),
                  adherenceScore: 88,
                  state: MemberPlanConsistencyState.consistent,
                ),
                MemberPlanConsistencyWeek(
                  weekStart: DateTime(2026, 4, 14),
                  adherenceScore: 81,
                  state: MemberPlanConsistencyState.consistent,
                ),
                MemberPlanConsistencyWeek(
                  weekStart: DateTime(2026, 4, 21),
                  state: MemberPlanConsistencyState.pending,
                ),
              ],
            ),
          );

        await _pumpMemberHomeContent(
          tester,
          memberRepository: memberRepository,
        );

        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('member-summary-active-coaches-value')),
              )
              .data,
          '1',
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const Key('member-summary-latest-weight-value')),
              )
              .data,
          '78.5 kg',
        );
        expect(find.textContaining('1.5 kg down'), findsOneWidget);
        expect(find.text('Live'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const Key('member-daily-streak-value')))
              .data,
          '12 Days Active',
        );
        expect(
          find.text('Momentum Plan. Tap to open your workout plan.'),
          findsOneWidget,
        );

        for (var index = 0; index < 4; index++) {
          expect(
            find.byKey(ValueKey('member-summary-plan-dot-$index-consistent')),
            findsOneWidget,
          );
        }
        expect(
          find.byKey(const ValueKey('member-summary-plan-dot-4-pending')),
          findsOneWidget,
        );
      },
    );

    testWidgets('current plan card only goes live for active AI plans', (
      tester,
    ) async {
      final nonAiPlan = const WorkoutPlanEntity(
        id: 'plan-coach-1',
        memberId: 'member-1',
        source: 'coach',
        title: 'Coach Plan',
        status: 'active',
      );
      final memberRepository = FakeMemberRepository()
        ..homeSummary = MemberHomeSummaryEntity(
          activeCoachCount: 1,
          activePlan: nonAiPlan,
        );

      await _pumpMemberHomeContent(tester, memberRepository: memberRepository);

      expect(find.text('No active plan'), findsOneWidget);
      expect(find.text('Live'), findsNothing);
    });

    testWidgets('daily streak pill pluralizes singular values correctly', (
      tester,
    ) async {
      final memberRepository = FakeMemberRepository()
        ..homeSummary = MemberHomeSummaryEntity(
          dailyStreak: const MemberDailyStreakEntity(
            currentCount: 1,
            lastActivityDate: null,
          ),
        );

      await _pumpMemberHomeContent(tester, memberRepository: memberRepository);

      expect(
        tester
            .widget<Text>(find.byKey(const Key('member-daily-streak-value')))
            .data,
        '1 Day Active',
      );
    });

    testWidgets('featured TAIYO card tolerates malformed brief payloads', (
      tester,
    ) async {
      final memberRepository = FakeMemberRepository()
        ..homeSummary = const MemberHomeSummaryEntity(activeCoachCount: 0);
      final aiCoachRepository = FakeAiCoachRepository()
        ..dailyBrief = AiDailyBriefEntity(
          id: 'brief-1',
          briefDate: DateTime(2026, 4, 22),
          planId: 'plan-1',
          dayId: 'day-1',
          primaryTaskId: 'task-1',
          readinessScore: 60,
          intensityBand: 'yellow',
          coachMode: false,
          recommendedWorkout: const <String, dynamic>{
            'title': <String, dynamic>{'unexpected': true},
          },
          whyShort: '',
          confidence: 0.9,
        );

      await _pumpMemberHomeContent(
        tester,
        memberRepository: memberRepository,
        aiCoachRepository: aiCoachRepository,
      );

      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.text('Today\'s plan'), findsOneWidget);
      expect(
        find.text('Daily AI coaching and workout guidance'),
        findsOneWidget,
      );
    });

    testWidgets('renders on a phone-sized viewport without layout errors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final memberRepository = FakeMemberRepository()
        ..homeSummary = const MemberHomeSummaryEntity(activeCoachCount: 0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            userRepositoryProvider.overrideWithValue(
              FakeUserRepository()
                ..profile = const ProfileEntity(
                  userId: 'member-1',
                  email: 'member@gymunity.com',
                  fullName: 'GymUnity Member',
                  role: AppRole.member,
                  onboardingCompleted: true,
                ),
            ),
            memberRepositoryProvider.overrideWithValue(memberRepository),
            aiCoachRepositoryProvider.overrideWithValue(
              FakeAiCoachRepository(),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: MemberHomeContent())),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('member-daily-streak-card')), findsOneWidget);
    });
  });
}

Future<void> _pumpMemberHomeContent(
  WidgetTester tester, {
  required FakeMemberRepository memberRepository,
  FakeAiCoachRepository? aiCoachRepository,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final userRepository = FakeUserRepository()
    ..profile = const ProfileEntity(
      userId: 'member-1',
      email: 'member@gymunity.com',
      fullName: 'GymUnity Member',
      role: AppRole.member,
      onboardingCompleted: true,
    );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        userRepositoryProvider.overrideWithValue(userRepository),
        memberRepositoryProvider.overrideWithValue(memberRepository),
        aiCoachRepositoryProvider.overrideWithValue(
          aiCoachRepository ?? FakeAiCoachRepository(),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: MemberHomeContent())),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}
