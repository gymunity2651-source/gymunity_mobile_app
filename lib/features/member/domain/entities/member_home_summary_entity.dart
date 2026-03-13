import '../../../coach/domain/entities/subscription_entity.dart';
import '../../../coach/domain/entities/workout_plan_entity.dart';
import 'member_progress_entity.dart';

class MemberHomeSummaryEntity {
  const MemberHomeSummaryEntity({
    this.latestWeightEntry,
    this.latestMeasurement,
    this.activePlan,
    this.latestSession,
    this.latestSubscription,
  });

  final WeightEntryEntity? latestWeightEntry;
  final BodyMeasurementEntity? latestMeasurement;
  final WorkoutPlanEntity? activePlan;
  final WorkoutSessionEntity? latestSession;
  final SubscriptionEntity? latestSubscription;
}
