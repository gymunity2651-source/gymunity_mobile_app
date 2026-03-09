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

  Future<void> upsertCoachProfile({
    required String bio,
    required List<String> specialties,
    required int yearsExperience,
    required double hourlyRate,
  });

  Future<WorkoutPlanEntity> createWorkoutPlan({
    required String memberId,
    required String source,
    required String title,
    required Map<String, dynamic> planJson,
  });

  Future<List<SubscriptionEntity>> listSubscriptions();
}

