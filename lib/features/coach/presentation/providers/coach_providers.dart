import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/workout_plan_entity.dart';

final coachProfileProvider = FutureProvider<CoachEntity?>((ref) async {
  final repo = ref.watch(coachRepositoryProvider);
  final currentUser = await ref.read(userRepositoryProvider).getCurrentUser();
  if (currentUser == null) {
    return null;
  }
  return repo.getCoachDetails(currentUser.id);
});

final coachDashboardSummaryProvider =
    FutureProvider<CoachDashboardSummaryEntity>((ref) async {
      final repo = ref.watch(coachRepositoryProvider);
      return repo.getDashboardSummary();
    });

final coachPackagesProvider = FutureProvider<List<CoachPackageEntity>>((
  ref,
) async {
  final repo = ref.watch(coachRepositoryProvider);
  return repo.listCoachPackages();
});

final coachAvailabilityProvider =
    FutureProvider<List<CoachAvailabilitySlotEntity>>((ref) async {
      final repo = ref.watch(coachRepositoryProvider);
      return repo.listAvailability();
    });

final coachClientsProvider = FutureProvider<List<CoachClientEntity>>((
  ref,
) async {
  final repo = ref.watch(coachRepositoryProvider);
  return repo.listClients();
});

final coachWorkoutPlansProvider = FutureProvider<List<WorkoutPlanEntity>>((
  ref,
) async {
  final repo = ref.watch(coachRepositoryProvider);
  return repo.listWorkoutPlans();
});

final coachManagedSubscriptionsProvider =
    FutureProvider<List<SubscriptionEntity>>((ref) async {
      final repo = ref.watch(coachRepositoryProvider);
      return repo.listSubscriptions();
    });

final coachDetailsProvider = FutureProvider.family<CoachEntity?, String>((
  ref,
  coachId,
) async {
  final repo = ref.watch(coachRepositoryProvider);
  return repo.getCoachDetails(coachId);
});
