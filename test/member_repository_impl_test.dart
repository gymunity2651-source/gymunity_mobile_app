import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:my_app/core/error/app_failure.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/coach/domain/entities/workout_plan_entity.dart';
import 'package:my_app/features/member/data/repositories/member_repository_impl.dart';
import 'package:my_app/features/member/domain/entities/member_home_summary_entity.dart';
import 'package:my_app/features/member/domain/entities/member_progress_entity.dart';

void main() {
  group('MemberRepositoryImpl.getHomeSummary', () {
    test(
      'keeps loading the home summary when daily streak recording fails',
      () async {
        final repository = _DailyStreakFailureRepository();

        final summary = await repository.getHomeSummary();

        expect(summary.dailyStreak.currentCount, 0);
        expect(summary.latestWeightEntry?.weightKg, 82.4);
        expect(summary.activeCoachCount, 1);
      },
    );
  });
}

class _DailyStreakFailureRepository extends MemberRepositoryImpl {
  _DailyStreakFailureRepository()
    : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  @override
  Future<MemberDailyStreakEntity> recordDailyActivity({
    DateTime? occurredAt,
    String source = 'app_open',
  }) async {
    throw const NetworkFailure(message: 'touch_member_daily_streak failed');
  }

  @override
  Future<List<WeightEntryEntity>> listWeightEntries() async {
    return <WeightEntryEntity>[
      WeightEntryEntity(
        id: 'weight-1',
        memberId: 'member-1',
        weightKg: 82.4,
        recordedAt: DateTime(2026, 4, 22),
      ),
    ];
  }

  @override
  Future<List<BodyMeasurementEntity>> listBodyMeasurements() async {
    return const <BodyMeasurementEntity>[];
  }

  @override
  Future<List<WorkoutPlanEntity>> listWorkoutPlans() async {
    return const <WorkoutPlanEntity>[];
  }

  @override
  Future<List<WorkoutSessionEntity>> listWorkoutSessions() async {
    return const <WorkoutSessionEntity>[];
  }

  @override
  Future<List<SubscriptionEntity>> listSubscriptions() async {
    return const <SubscriptionEntity>[
      SubscriptionEntity(
        id: 'subscription-1',
        memberId: 'member-1',
        coachId: 'coach-1',
        status: 'active',
        amount: 1200,
        planName: 'Coach Plan',
      ),
    ];
  }
}
