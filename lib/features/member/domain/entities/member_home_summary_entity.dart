import '../../../coach/domain/entities/subscription_entity.dart';
import '../../../coach/domain/entities/workout_plan_entity.dart';
import 'member_progress_entity.dart';

enum MemberWeightTrendDirection { down, up, stable, neutral }

enum MemberPlanConsistencyState { consistent, inconsistent, pending }

enum MemberPlanConsistencySource { aiSummary, weeklyCheckin, taskLogs, none }

class MemberPlanConsistencyWeek {
  const MemberPlanConsistencyWeek({
    required this.weekStart,
    this.adherenceScore,
    required this.state,
    this.source = MemberPlanConsistencySource.none,
  });

  final DateTime weekStart;
  final int? adherenceScore;
  final MemberPlanConsistencyState state;
  final MemberPlanConsistencySource source;

  bool get isConsistent => state == MemberPlanConsistencyState.consistent;
}

class MemberPlanConsistencySummary {
  const MemberPlanConsistencySummary({
    this.weeks = const <MemberPlanConsistencyWeek>[],
    this.currentStreakWeeks = 0,
    this.totalConsistentWeeks = 0,
    this.consistencyThreshold = 70,
    this.visualCap = 6,
  });

  final List<MemberPlanConsistencyWeek> weeks;
  final int currentStreakWeeks;
  final int totalConsistentWeeks;
  final int consistencyThreshold;
  final int visualCap;

  List<MemberPlanConsistencyWeek> get visibleWeeks {
    if (weeks.length <= visualCap) {
      return weeks;
    }
    return weeks.sublist(weeks.length - visualCap);
  }
}

class MemberDailyStreakEntity {
  const MemberDailyStreakEntity({this.currentCount = 0, this.lastActivityDate});

  final int currentCount;
  final DateTime? lastActivityDate;

  bool get hasActivity => currentCount > 0 || lastActivityDate != null;
}

class MemberHomeSummaryEntity {
  const MemberHomeSummaryEntity({
    this.latestWeightEntry,
    this.previousWeightEntry,
    this.latestMeasurement,
    this.activePlan,
    this.activeAiPlan,
    this.latestSession,
    this.latestSubscription,
    this.activeCoachCount = 0,
    this.hasPendingCoachCheckout = false,
    this.planConsistency = const MemberPlanConsistencySummary(),
    this.dailyStreak = const MemberDailyStreakEntity(),
  });

  final WeightEntryEntity? latestWeightEntry;
  final WeightEntryEntity? previousWeightEntry;
  final BodyMeasurementEntity? latestMeasurement;
  final WorkoutPlanEntity? activePlan;
  final WorkoutPlanEntity? activeAiPlan;
  final WorkoutSessionEntity? latestSession;
  final SubscriptionEntity? latestSubscription;
  final int activeCoachCount;
  final bool hasPendingCoachCheckout;
  final MemberPlanConsistencySummary planConsistency;
  final MemberDailyStreakEntity dailyStreak;

  MemberWeightTrendDirection get weightTrendDirection {
    final latest = latestWeightEntry;
    final previous = previousWeightEntry;
    if (latest == null) {
      return MemberWeightTrendDirection.neutral;
    }
    if (previous == null) {
      return MemberWeightTrendDirection.neutral;
    }
    final delta = latest.weightKg - previous.weightKg;
    if (delta.abs() < 0.05) {
      return MemberWeightTrendDirection.stable;
    }
    return delta < 0
        ? MemberWeightTrendDirection.down
        : MemberWeightTrendDirection.up;
  }

  double? get weightDeltaKg {
    final latest = latestWeightEntry;
    final previous = previousWeightEntry;
    if (latest == null || previous == null) {
      return null;
    }
    return latest.weightKg - previous.weightKg;
  }
}
