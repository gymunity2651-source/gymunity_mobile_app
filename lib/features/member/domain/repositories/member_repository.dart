import '../../../coach/domain/entities/subscription_entity.dart';
import '../../../coach/domain/entities/workout_plan_entity.dart';
import '../../../store/domain/entities/order_entity.dart';
import '../entities/member_home_summary_entity.dart';
import '../entities/member_profile_entity.dart';
import '../entities/member_progress_entity.dart';

abstract class MemberRepository {
  Future<MemberProfileEntity?> getMemberProfile();

  Future<void> upsertMemberProfile({
    required String goal,
    required int age,
    required String gender,
    required double heightCm,
    required double currentWeightKg,
    required String trainingFrequency,
    required String experienceLevel,
  });

  Future<UserPreferencesEntity> getPreferences();

  Future<void> upsertPreferences(UserPreferencesEntity preferences);

  Future<List<WeightEntryEntity>> listWeightEntries();

  Future<void> saveWeightEntry({
    String? entryId,
    required double weightKg,
    required DateTime recordedAt,
    String? note,
  });

  Future<void> deleteWeightEntry(String entryId);

  Future<List<BodyMeasurementEntity>> listBodyMeasurements();

  Future<void> saveBodyMeasurement({
    String? entryId,
    required DateTime recordedAt,
    double? waistCm,
    double? chestCm,
    double? hipsCm,
    double? armCm,
    double? thighCm,
    double? bodyFatPercent,
    String? note,
  });

  Future<void> deleteBodyMeasurement(String entryId);

  Future<List<WorkoutPlanEntity>> listWorkoutPlans();

  Future<List<WorkoutSessionEntity>> listWorkoutSessions();

  Future<void> saveWorkoutSession({
    String? sessionId,
    required String title,
    required DateTime performedAt,
    required int durationMinutes,
    String? workoutPlanId,
    String? coachId,
    String? note,
  });

  Future<void> deleteWorkoutSession(String sessionId);

  Future<List<SubscriptionEntity>> listSubscriptions();

  Future<List<OrderEntity>> listOrders();

  Future<MemberHomeSummaryEntity> getHomeSummary();
}
