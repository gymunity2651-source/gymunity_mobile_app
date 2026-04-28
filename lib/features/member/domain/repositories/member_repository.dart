import '../../../coach/domain/entities/subscription_entity.dart';
import '../../../coach/domain/entities/coach_workspace_entity.dart';
import '../../../coach/domain/entities/workout_plan_entity.dart';
import '../../../store/domain/entities/order_entity.dart';
import '../entities/coach_hub_entity.dart';
import '../entities/coaching_engagement_entity.dart';
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
    int? budgetEgp,
    String? city,
    String? coachingPreference,
    String? trainingPlace,
    String? preferredLanguage,
    String? preferredCoachGender,
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

  Future<SubscriptionEntity> confirmCoachPayment({
    required String subscriptionId,
    String? paymentReference,
  });

  Future<String> uploadCoachPaymentReceipt({
    required String subscriptionId,
    required List<int> bytes,
    required String fileName,
  });

  Future<void> submitCoachPaymentReceipt({
    required String subscriptionId,
    String? paymentReference,
    String? receiptStoragePath,
    double? amount,
  });

  Future<SubscriptionEntity> pauseSubscription({
    required String subscriptionId,
    bool pauseNow = true,
  });

  Future<List<CoachingThreadEntity>> listCoachingThreads();

  Future<List<CoachingMessageEntity>> listCoachingMessages(String threadId);

  Future<void> sendCoachingMessage({
    required String threadId,
    required String content,
  });

  Future<List<WeeklyCheckinEntity>> listWeeklyCheckins({
    String? subscriptionId,
  });

  Future<WeeklyCheckinEntity> submitWeeklyCheckin({
    required String subscriptionId,
    required DateTime weekStart,
    double? weightKg,
    double? waistCm,
    int adherenceScore = 0,
    int? energyScore,
    int? sleepScore,
    String? wins,
    String? blockers,
    String? questions,
    List<Map<String, dynamic>> photos = const <Map<String, dynamic>>[],
    int? workoutsCompleted,
    int? missedWorkouts,
    String? missedWorkoutsReason,
    int? sorenessScore,
    int? fatigueScore,
    String? painWarning,
    int? nutritionAdherenceScore,
    int? habitAdherenceScore,
    String? biggestObstacle,
    String? supportNeeded,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  });

  Future<List<OrderEntity>> listOrders();

  Future<MemberDailyStreakEntity> recordDailyActivity({
    DateTime? occurredAt,
    String source = 'app_open',
  });

  Future<MemberHomeSummaryEntity> getHomeSummary();

  Future<MemberCoachHubEntity> getCoachHub({String? subscriptionId});

  Future<List<MemberCoachAgendaItemEntity>> listCoachAgenda({
    required String subscriptionId,
    required DateTime dateFrom,
    required DateTime dateTo,
  });

  Future<MemberCoachKickoffEntity> submitCoachKickoff({
    required String subscriptionId,
    required String primaryGoal,
    required String trainingLevel,
    required List<String> preferredTrainingDays,
    required List<String> availableEquipment,
    required String injuriesLimitations,
    required String scheduleConstraints,
    required String nutritionSituation,
    required String sleepRecoveryNotes,
    required String biggestObstacle,
    required String coachExpectations,
    String memberNote,
    bool shareProgressSummary,
    bool shareNutritionSummary,
    bool shareAiSummary,
    bool shareWorkoutAdherence,
    bool shareProductContext,
  });

  Future<List<MemberAssignedHabitEntity>> listAssignedHabits({
    String? subscriptionId,
    DateTime? date,
  });

  Future<MemberAssignedHabitEntity?> logAssignedHabit({
    required String assignmentId,
    required String completionStatus,
    DateTime? logDate,
    double? value,
    String? note,
  });

  Future<List<MemberAssignedResourceEntity>> listAssignedResources({
    String? subscriptionId,
  });

  Future<MemberAssignedResourceEntity?> markResourceProgress({
    required String assignmentId,
    bool markViewed,
    bool markCompleted,
    String? memberNote,
  });

  Future<String> createCoachResourceSignedUrl(String storagePath);

  Future<List<CoachSessionTypeEntity>> listBookableSessionTypes({
    required String subscriptionId,
  });

  Future<List<MemberBookableSlotEntity>> listBookableSlots({
    required String coachId,
    required String sessionTypeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  });

  Future<List<CoachBookingEntity>> listMemberBookings({
    required String subscriptionId,
    DateTime? from,
    DateTime? to,
  });

  Future<CoachBookingEntity> createMemberBooking({
    required String subscriptionId,
    required String sessionTypeId,
    required DateTime startsAt,
    String timezone,
    String? note,
  });

  Future<CoachBookingEntity> updateMemberBookingStatus({
    required String bookingId,
    required String status,
    String? reason,
  });
}
