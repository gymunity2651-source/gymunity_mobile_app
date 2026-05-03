import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/entities/coach_payment_entity.dart';
import '../../domain/entities/coach_taiyo_entity.dart';
import '../../domain/entities/coach_workspace_entity.dart';
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

final coachWorkspaceSummaryProvider = FutureProvider<CoachWorkspaceEntity>((
  ref,
) async {
  final repo = ref.watch(coachRepositoryProvider);
  return repo.getWorkspaceSummary();
});

final coachActionItemsProvider = FutureProvider<List<CoachActionItemEntity>>((
  ref,
) async {
  final repo = ref.watch(coachRepositoryProvider);
  return repo.listActionItems();
});

final coachClientPipelineFilterProvider =
    StateProvider<CoachClientPipelineFilter>((ref) {
      return const CoachClientPipelineFilter();
    });

final coachClientPipelineProvider =
    FutureProvider<List<CoachClientPipelineEntry>>((ref) async {
      final repo = ref.watch(coachRepositoryProvider);
      final filter = ref.watch(coachClientPipelineFilterProvider);
      return repo.listClientPipeline(filter);
    });

final coachClientWorkspaceProvider =
    FutureProvider.family<CoachClientWorkspaceEntity, String>((
      ref,
      subscriptionId,
    ) async {
      final repo = ref.watch(coachRepositoryProvider);
      return repo.getClientWorkspace(subscriptionId);
    });

final taiyoCoachClientBriefProvider =
    FutureProvider.family<CoachTaiyoClientBriefEntity, String>((
      ref,
      subscriptionId,
    ) async {
      final repo = ref.watch(coachRepositoryProvider);
      final workspace = await ref.watch(
        coachClientWorkspaceProvider(subscriptionId).future,
      );
      return repo.requestTaiyoCoachClientBrief(
        clientId: workspace.client.memberId,
        subscriptionId: subscriptionId,
      );
    });

final coachCheckinInboxProvider = FutureProvider((ref) async {
  final repo = ref.watch(coachRepositoryProvider);
  return repo.listCheckinInbox();
});

final coachProgramTemplatesProvider =
    FutureProvider<List<CoachProgramTemplateEntity>>((ref) async {
      final repo = ref.watch(coachRepositoryProvider);
      return repo.listProgramTemplates();
    });

final coachExercisesProvider = FutureProvider<List<CoachExerciseEntity>>((
  ref,
) async {
  final repo = ref.watch(coachRepositoryProvider);
  return repo.listExercises();
});

final coachOnboardingTemplatesProvider =
    FutureProvider<List<CoachOnboardingTemplateEntity>>((ref) async {
      final repo = ref.watch(coachRepositoryProvider);
      return repo.listOnboardingTemplates();
    });

final coachSessionTypesProvider = FutureProvider<List<CoachSessionTypeEntity>>((
  ref,
) async {
  final repo = ref.watch(coachRepositoryProvider);
  return repo.listSessionTypes();
});

final coachBookingsProvider = FutureProvider<List<CoachBookingEntity>>((
  ref,
) async {
  final repo = ref.watch(coachRepositoryProvider);
  final now = DateTime.now();
  return repo.listBookings(
    from: DateTime(now.year, now.month, now.day),
    to: DateTime(now.year, now.month, now.day).add(const Duration(days: 14)),
  );
});

final coachPaymentQueueProvider =
    FutureProvider<List<CoachPaymentReceiptEntity>>((ref) async {
      final repo = ref.watch(coachRepositoryProvider);
      return repo.listPaymentQueue();
    });

final paymentOrderProvider =
    FutureProvider.family<CoachPaymentOrderEntity?, String>((
      ref,
      paymentOrderId,
    ) async {
      final repo = ref.watch(coachPaymentRepositoryProvider);
      return repo.getPaymentOrder(paymentOrderId);
    });

final watchPaymentOrderProvider =
    StreamProvider.family<CoachPaymentOrderEntity?, String>((
      ref,
      paymentOrderId,
    ) async* {
      final repo = ref.watch(coachPaymentRepositoryProvider);
      while (true) {
        yield await repo.getPaymentOrder(paymentOrderId);
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    });

final currentCoachSubscriptionPaymentProvider =
    FutureProvider.family<CoachPaymentOrderEntity?, SubscriptionEntity>((
      ref,
      subscription,
    ) async {
      final paymentOrderId = subscription.paymentOrderId;
      if (paymentOrderId == null || paymentOrderId.trim().isEmpty) {
        return null;
      }
      final repo = ref.watch(coachPaymentRepositoryProvider);
      return repo.getPaymentOrder(paymentOrderId);
    });

final coachResourcesProvider = FutureProvider<List<CoachResourceEntity>>((
  ref,
) async {
  final repo = ref.watch(coachRepositoryProvider);
  return repo.listCoachResources();
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

final coachSubscriptionRequestsProvider =
    FutureProvider<List<SubscriptionEntity>>((ref) async {
      final repo = ref.watch(coachRepositoryProvider);
      return repo.listSubscriptionRequests();
    });

final coachDetailsProvider = FutureProvider.family<CoachEntity?, String>((
  ref,
  coachId,
) async {
  final repo = ref.watch(coachRepositoryProvider);
  return repo.getCoachDetails(coachId);
});
