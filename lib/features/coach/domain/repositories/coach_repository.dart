import '../../../../core/result/paged.dart';
import '../entities/coach_entity.dart';
import '../entities/subscription_entity.dart';
import '../entities/workout_plan_entity.dart';

abstract class CoachRepository {
  Future<Paged<CoachEntity>> listCoaches({
    String? specialty,
    String? cursor,
    int limit = 20,
  });

  Future<CoachEntity?> getCoachDetails(String coachId);

  Future<void> upsertCoachProfile({
    required String bio,
    required List<String> specialties,
    required int yearsExperience,
    required double hourlyRate,
    required String deliveryMode,
    required String serviceSummary,
  });

  Future<List<CoachPackageEntity>> listCoachPackages({
    String? coachId,
    bool activeOnly = false,
  });

  Future<void> saveCoachPackage({
    String? packageId,
    required String title,
    required String description,
    required String billingCycle,
    required double price,
    bool isActive = true,
  });

  Future<void> deleteCoachPackage(String packageId);

  Future<List<CoachAvailabilitySlotEntity>> listAvailability({String? coachId});

  Future<void> saveAvailabilitySlot({
    String? slotId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String timezone,
    bool isActive = true,
  });

  Future<void> deleteAvailabilitySlot(String slotId);

  Future<CoachDashboardSummaryEntity> getDashboardSummary();

  Future<List<CoachClientEntity>> listClients();

  Future<WorkoutPlanEntity> createWorkoutPlan({
    required String memberId,
    required String source,
    required String title,
    required Map<String, dynamic> planJson,
  });

  Future<List<WorkoutPlanEntity>> listWorkoutPlans({String? memberId});

  Future<void> updateWorkoutPlanStatus({
    required String planId,
    required String status,
  });

  Future<List<SubscriptionEntity>> listSubscriptions();

  Future<SubscriptionEntity> requestSubscription({
    required String packageId,
    String? note,
  });

  Future<void> updateSubscriptionStatus({
    required String subscriptionId,
    required String newStatus,
    String? note,
  });

  Future<List<CoachReviewEntity>> listCoachReviews(String coachId);

  Future<void> submitCoachReview({
    required String coachId,
    required String subscriptionId,
    required int rating,
    required String reviewText,
  });
}
