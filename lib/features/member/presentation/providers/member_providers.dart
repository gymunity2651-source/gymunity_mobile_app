import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/member_home_summary_entity.dart';
import '../../domain/entities/coaching_engagement_entity.dart';
import '../../domain/entities/member_profile_entity.dart';
import '../../domain/entities/member_progress_entity.dart';
import '../../../coach/domain/entities/subscription_entity.dart';
import '../../../coach/domain/entities/workout_plan_entity.dart';
import '../../../store/domain/entities/order_entity.dart';

final memberProfileDetailsProvider = FutureProvider<MemberProfileEntity?>((
  ref,
) async {
  final repo = ref.watch(memberRepositoryProvider);
  return repo.getMemberProfile();
});

final memberPreferencesProvider = FutureProvider<UserPreferencesEntity>((ref) {
  final repo = ref.watch(memberRepositoryProvider);
  return repo.getPreferences();
});

final memberWeightEntriesProvider = FutureProvider<List<WeightEntryEntity>>((
  ref,
) async {
  final repo = ref.watch(memberRepositoryProvider);
  return repo.listWeightEntries();
});

final memberBodyMeasurementsProvider =
    FutureProvider<List<BodyMeasurementEntity>>((ref) async {
      final repo = ref.watch(memberRepositoryProvider);
      return repo.listBodyMeasurements();
    });

final memberWorkoutPlansProvider = FutureProvider<List<WorkoutPlanEntity>>((
  ref,
) async {
  final repo = ref.watch(memberRepositoryProvider);
  return repo.listWorkoutPlans();
});

final memberWorkoutSessionsProvider =
    FutureProvider<List<WorkoutSessionEntity>>((ref) async {
      final repo = ref.watch(memberRepositoryProvider);
      return repo.listWorkoutSessions();
    });

final memberSubscriptionsProvider = FutureProvider<List<SubscriptionEntity>>((
  ref,
) async {
  final repo = ref.watch(memberRepositoryProvider);
  return repo.listSubscriptions();
});

final memberCoachingThreadsProvider =
    FutureProvider<List<CoachingThreadEntity>>((ref) async {
      final repo = ref.watch(memberRepositoryProvider);
      return repo.listCoachingThreads();
    });

final memberCoachingMessagesProvider =
    FutureProvider.family<List<CoachingMessageEntity>, String>((
      ref,
      threadId,
    ) async {
      final repo = ref.watch(memberRepositoryProvider);
      return repo.listCoachingMessages(threadId);
    });

final memberWeeklyCheckinsProvider =
    FutureProvider.family<List<WeeklyCheckinEntity>, String?>((
      ref,
      subscriptionId,
    ) async {
      final repo = ref.watch(memberRepositoryProvider);
      return repo.listWeeklyCheckins(subscriptionId: subscriptionId);
    });

final memberOrdersProvider = FutureProvider<List<OrderEntity>>((ref) async {
  final repo = ref.watch(memberRepositoryProvider);
  return repo.listOrders();
});

final memberHomeSummaryProvider = FutureProvider<MemberHomeSummaryEntity>((
  ref,
) {
  final repo = ref.watch(memberRepositoryProvider);
  return repo.getHomeSummary();
});
