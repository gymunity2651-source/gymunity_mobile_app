import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/member_home_summary_entity.dart';
import '../../domain/entities/coach_hub_entity.dart';
import '../../domain/entities/coaching_engagement_entity.dart';
import '../../domain/entities/member_profile_entity.dart';
import '../../domain/entities/member_progress_entity.dart';
import '../../../coach/domain/entities/subscription_entity.dart';
import '../../../coach/domain/entities/coach_workspace_entity.dart';
import '../../../coach/domain/entities/workout_plan_entity.dart';
import '../../../store/domain/entities/order_entity.dart';

/// Set this to a tab index to programmatically switch the member home tab.
/// Reset to null after consuming.
final memberHomeTabSwitchProvider = StateProvider<int?>((ref) => null);

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

final memberCoachHubProvider =
    FutureProvider.family<MemberCoachHubEntity, String?>((ref, subscriptionId) {
      final repo = ref.watch(memberRepositoryProvider);
      return repo.getCoachHub(subscriptionId: subscriptionId);
    });

final memberAssignedHabitsProvider =
    FutureProvider.family<List<MemberAssignedHabitEntity>, String?>((
      ref,
      subscriptionId,
    ) {
      final repo = ref.watch(memberRepositoryProvider);
      return repo.listAssignedHabits(subscriptionId: subscriptionId);
    });

final memberAssignedResourcesProvider =
    FutureProvider.family<List<MemberAssignedResourceEntity>, String?>((
      ref,
      subscriptionId,
    ) {
      final repo = ref.watch(memberRepositoryProvider);
      return repo.listAssignedResources(subscriptionId: subscriptionId);
    });

final memberCoachBookingsProvider =
    FutureProvider.family<List<CoachBookingEntity>, String>((
      ref,
      subscriptionId,
    ) {
      final repo = ref.watch(memberRepositoryProvider);
      final now = DateTime.now();
      return repo.listMemberBookings(
        subscriptionId: subscriptionId,
        from: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 7)),
        to: DateTime(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 30)),
      );
    });

final memberBookableSessionTypesProvider =
    FutureProvider.family<List<CoachSessionTypeEntity>, String>((
      ref,
      subscriptionId,
    ) {
      final repo = ref.watch(memberRepositoryProvider);
      return repo.listBookableSessionTypes(subscriptionId: subscriptionId);
    });

final memberBookableSlotsProvider =
    FutureProvider.family<List<MemberBookableSlotEntity>, MemberSlotsQuery>((
      ref,
      query,
    ) {
      final repo = ref.watch(memberRepositoryProvider);
      return repo.listBookableSlots(
        coachId: query.coachId,
        sessionTypeId: query.sessionTypeId,
        dateFrom: query.dateFrom,
        dateTo: query.dateTo,
      );
    });

class MemberSlotsQuery {
  const MemberSlotsQuery({
    required this.coachId,
    required this.sessionTypeId,
    required this.dateFrom,
    required this.dateTo,
  });

  final String coachId;
  final String sessionTypeId;
  final DateTime dateFrom;
  final DateTime dateTo;

  @override
  bool operator ==(Object other) {
    return other is MemberSlotsQuery &&
        other.coachId == coachId &&
        other.sessionTypeId == sessionTypeId &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo;
  }

  @override
  int get hashCode => Object.hash(coachId, sessionTypeId, dateFrom, dateTo);
}

final memberOrdersProvider = FutureProvider<List<OrderEntity>>((ref) async {
  final repo = ref.watch(memberRepositoryProvider);
  return repo.listOrders();
});

final memberHomeSummaryProvider = StreamProvider<MemberHomeSummaryEntity>((
  ref,
) {
  final repo = ref.watch(memberRepositoryProvider);
  final controller = StreamController<MemberHomeSummaryEntity>();
  final client = _tryReadSupabaseClient(ref);
  final userId = client?.auth.currentUser?.id;
  final channelName = userId == null
      ? null
      : 'member-home-summary:$userId:${DateTime.now().microsecondsSinceEpoch}';

  RealtimeChannel? channel;
  var isDisposed = false;
  var refreshInFlight = false;
  var refreshQueued = false;

  Future<void> refresh() async {
    if (isDisposed) {
      return;
    }
    if (refreshInFlight) {
      refreshQueued = true;
      return;
    }
    refreshInFlight = true;
    do {
      refreshQueued = false;
      try {
        controller.add(await repo.getHomeSummary());
      } catch (error, stackTrace) {
        if (!isDisposed) {
          controller.addError(error, stackTrace);
        }
      }
    } while (!isDisposed && refreshQueued);
    refreshInFlight = false;
  }

  Future<void>.microtask(refresh);

  if (client != null && userId != null && channelName != null) {
    channel = client.channel(channelName);
    for (final table in _memberHomeSummaryRealtimeTables) {
      channel = channel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'member_id',
          value: userId,
        ),
        callback: (_) => unawaited(refresh()),
      );
    }
    channel!.subscribe();
  }

  ref.onDispose(() {
    isDisposed = true;
    if (channel != null && client != null) {
      unawaited(client.removeChannel(channel));
    }
    unawaited(controller.close());
  });

  return controller.stream;
});

SupabaseClient? _tryReadSupabaseClient(Ref ref) {
  try {
    return ref.read(supabaseClientProvider);
  } catch (_) {
    return null;
  }
}

const List<String> _memberHomeSummaryRealtimeTables = <String>[
  'member_profiles',
  'subscriptions',
  'member_weight_entries',
  'member_body_measurements',
  'workout_plans',
  'workout_sessions',
  'weekly_checkins',
  'member_ai_weekly_summaries',
  'workout_plan_tasks',
  'workout_task_logs',
];
