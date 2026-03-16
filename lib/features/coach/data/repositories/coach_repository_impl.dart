import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/paged.dart';
import '../../../../core/utils/historical_record_utils.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/workout_plan_entity.dart';
import '../../domain/repositories/coach_repository.dart';

class CoachRepositoryImpl implements CoachRepository {
  CoachRepositoryImpl(this._client);

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'No authenticated coach found.');
    }
    return userId;
  }

  @override
  Future<Paged<CoachEntity>> listCoaches({
    String? specialty,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final rows =
          await _client.rpc(
                'list_coach_directory',
                params: <String, dynamic>{
                  'specialty_filter': specialty,
                  'limit_count': limit,
                },
              )
              as List<dynamic>;

      return Paged<CoachEntity>(
        items: rows
            .map(
              (dynamic row) => _mapCoachDirectory(row as Map<String, dynamic>),
            )
            .toList(growable: false),
        nextCursor: null,
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<CoachEntity?> getCoachDetails(String coachId) async {
    try {
      final profileRows =
          await _client.rpc(
                'get_coach_public_profile',
                params: <String, dynamic>{'target_coach_id': coachId},
              )
              as List<dynamic>;
      if (profileRows.isEmpty) {
        return null;
      }

      final profile = profileRows.first as Map<String, dynamic>;
      final packages = await listCoachPackages(
        coachId: coachId,
        activeOnly: true,
      );
      final availability = await listAvailability(coachId: coachId);
      final reviews = await listCoachReviews(coachId);

      return CoachEntity(
        id: profile['user_id'] as String,
        name: profile['full_name'] as String? ?? 'Coach',
        avatarPath: profile['avatar_path'] as String?,
        bio: profile['bio'] as String? ?? '',
        specialties:
            (profile['specialties'] as List<dynamic>? ?? const <dynamic>[])
                .cast<String>(),
        yearsExperience: profile['years_experience'] as int? ?? 0,
        hourlyRate: (profile['hourly_rate'] as num?)?.toDouble() ?? 0,
        pricingCurrency: profile['pricing_currency'] as String? ?? 'USD',
        ratingAvg: (profile['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: profile['rating_count'] as int? ?? 0,
        isVerified: profile['is_verified'] as bool? ?? false,
        deliveryMode: profile['delivery_mode'] as String?,
        serviceSummary: profile['service_summary'] as String? ?? '',
        packages: packages,
        availability: availability,
        reviews: reviews,
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> upsertCoachProfile({
    required String bio,
    required List<String> specialties,
    required int yearsExperience,
    required double hourlyRate,
    required String deliveryMode,
    required String serviceSummary,
  }) async {
    final userId = _userId;
    try {
      await _client.from('coach_profiles').upsert(<String, dynamic>{
        'user_id': userId,
        'bio': bio,
        'specialties': specialties,
        'years_experience': yearsExperience,
        'hourly_rate': hourlyRate,
        'delivery_mode': deliveryMode,
        'service_summary': serviceSummary,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _client
          .from('profiles')
          .update(<String, dynamic>{
            'onboarding_completed': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<List<CoachPackageEntity>> listCoachPackages({
    String? coachId,
    bool activeOnly = false,
  }) async {
    try {
      if (coachId != null &&
          coachId.isNotEmpty &&
          coachId != _client.auth.currentUser?.id) {
        final rows = await _client.rpc(
          'list_coach_public_packages',
          params: <String, dynamic>{'target_coach_id': coachId},
        );
        return (rows as List<dynamic>)
            .map((dynamic row) => _mapPackage(row as Map<String, dynamic>))
            .toList(growable: false);
      }

      dynamic query = _client
          .from('coach_packages')
          .select()
          .eq('coach_id', coachId ?? _userId)
          .order('created_at', ascending: true);
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final rows = await query;
      return (rows as List<dynamic>)
          .map((dynamic row) => _mapPackage(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> saveCoachPackage({
    String? packageId,
    required String title,
    required String description,
    required String billingCycle,
    required double price,
    bool isActive = true,
  }) async {
    try {
      await _client
          .from('coach_packages')
          .upsert(
            <String, dynamic>{
              'id': packageId,
              'coach_id': _userId,
              'title': title,
              'description': description,
              'billing_cycle': billingCycle,
              'price': price,
              'is_active': isActive,
            }..removeWhere((String key, dynamic value) => value == null),
          );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> deleteCoachPackage(String packageId) async {
    try {
      final linkedSubscriptions = await _client
          .from('subscriptions')
          .select('id')
          .eq('package_id', packageId)
          .limit(1);
      if ((linkedSubscriptions as List<dynamic>).isEmpty) {
        await _client
            .from('coach_packages')
            .delete()
            .eq('id', packageId)
            .eq('coach_id', _userId);
        return;
      }
      await _client
          .from('coach_packages')
          .update(<String, dynamic>{'is_active': false})
          .eq('id', packageId)
          .eq('coach_id', _userId);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<List<CoachAvailabilitySlotEntity>> listAvailability({
    String? coachId,
  }) async {
    try {
      dynamic query = _client
          .from('coach_availability_slots')
          .select()
          .eq('coach_id', coachId ?? _userId)
          .order('weekday')
          .order('start_time');
      if (coachId != null && coachId != _client.auth.currentUser?.id) {
        query = query.eq('is_active', true);
      }
      final rows = await query;
      return (rows as List<dynamic>)
          .map((dynamic row) => _mapAvailability(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> saveAvailabilitySlot({
    String? slotId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String timezone,
    bool isActive = true,
  }) async {
    try {
      await _client
          .from('coach_availability_slots')
          .upsert(
            <String, dynamic>{
              'id': slotId,
              'coach_id': _userId,
              'weekday': weekday,
              'start_time': startTime,
              'end_time': endTime,
              'timezone': timezone,
              'is_active': isActive,
            }..removeWhere((String key, dynamic value) => value == null),
          );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> deleteAvailabilitySlot(String slotId) async {
    try {
      await _client
          .from('coach_availability_slots')
          .delete()
          .eq('id', slotId)
          .eq('coach_id', _userId);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<CoachDashboardSummaryEntity> getDashboardSummary() async {
    try {
      final rows = await _client.rpc('coach_dashboard_summary');
      final row = (rows as List<dynamic>).first as Map<String, dynamic>;
      return CoachDashboardSummaryEntity(
        activeClients: row['active_clients'] as int? ?? 0,
        pendingRequests: row['pending_requests'] as int? ?? 0,
        activePackages: row['active_packages'] as int? ?? 0,
        activePlans: row['active_plans'] as int? ?? 0,
        ratingAvg: (row['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: row['rating_count'] as int? ?? 0,
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<List<CoachClientEntity>> listClients() async {
    try {
      final rows = await _client.rpc('list_coach_clients');
      return (rows as List<dynamic>)
          .where(
            (dynamic row) =>
                ((row as Map<String, dynamic>)['member_id'] as String? ?? '')
                    .isNotEmpty,
          )
          .map((dynamic row) => _mapClient(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<WorkoutPlanEntity> createWorkoutPlan({
    required String memberId,
    required String source,
    required String title,
    required Map<String, dynamic> planJson,
  }) async {
    try {
      final row = await _client
          .from('workout_plans')
          .insert(<String, dynamic>{
            'member_id': memberId,
            'coach_id': _userId,
            'source': source,
            'title': title,
            'plan_json': planJson,
            'status': 'active',
          })
          .select()
          .single();

      await _client.from('notifications').insert(<String, dynamic>{
        'user_id': memberId,
        'type': 'coaching',
        'title': 'New workout plan assigned',
        'body': 'A coach assigned the plan "$title".',
        'data': <String, dynamic>{
          'workout_plan_id': row['id'],
          'coach_id': _userId,
        },
      });

      return _mapWorkoutPlan(row);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<List<WorkoutPlanEntity>> listWorkoutPlans({String? memberId}) async {
    try {
      dynamic query = _client
          .from('workout_plans')
          .select()
          .eq('coach_id', _userId)
          .order('assigned_at', ascending: false);
      if (memberId != null && memberId.isNotEmpty) {
        query = query.eq('member_id', memberId);
      }
      final rows = await query;
      return (rows as List<dynamic>)
          .map((dynamic row) => _mapWorkoutPlan(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> updateWorkoutPlanStatus({
    required String planId,
    required String status,
  }) async {
    try {
      await _client
          .from('workout_plans')
          .update(<String, dynamic>{
            'status': status,
            'completed_at': status == 'completed'
                ? DateTime.now().toUtc().toIso8601String()
                : null,
          })
          .eq('id', planId)
          .eq('coach_id', _userId);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<List<SubscriptionEntity>> listSubscriptions() async {
    try {
      final rows = await _client
          .from('subscriptions')
          .select(
            'id,member_id,coach_id,package_id,plan_name,billing_cycle,amount,status,payment_method,starts_at,ends_at,activated_at,cancelled_at,created_at',
          )
          .eq('coach_id', _userId)
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((dynamic row) => _mapSubscription(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<SubscriptionEntity> requestSubscription({
    required String packageId,
    String? note,
  }) async {
    try {
      final rows = await _client.rpc(
        'request_coach_subscription',
        params: <String, dynamic>{
          'target_package_id': packageId,
          'input_member_note': note,
        },
      );
      return _mapSubscription(
        (rows as List<dynamic>).first as Map<String, dynamic>,
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> updateSubscriptionStatus({
    required String subscriptionId,
    required String newStatus,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'update_coach_subscription_status',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'new_status': newStatus,
          'note': note,
        },
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<List<CoachReviewEntity>> listCoachReviews(String coachId) async {
    try {
      final rows = await _client.rpc(
        'list_coach_public_reviews',
        params: <String, dynamic>{'target_coach_id': coachId},
      );
      return (rows as List<dynamic>)
          .map((dynamic row) => _mapReview(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> submitCoachReview({
    required String coachId,
    required String subscriptionId,
    required int rating,
    required String reviewText,
  }) async {
    try {
      await _client.rpc(
        'submit_coach_review',
        params: <String, dynamic>{
          'target_coach_id': coachId,
          'target_subscription_id': subscriptionId,
          'input_rating': rating,
          'input_review_text': reviewText,
        },
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  CoachEntity _mapCoachDirectory(Map<String, dynamic> row) {
    return CoachEntity(
      id: row['user_id'] as String,
      name: row['full_name'] as String? ?? 'Coach',
      specialties: (row['specialties'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>(),
      hourlyRate: (row['hourly_rate'] as num?)?.toDouble() ?? 0,
      ratingAvg: (row['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: row['rating_count'] as int? ?? 0,
      isVerified: row['is_verified'] as bool? ?? false,
    );
  }

  CoachPackageEntity _mapPackage(Map<String, dynamic> row) {
    return CoachPackageEntity(
      id: row['id'] as String,
      coachId: row['coach_id'] as String,
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      billingCycle: row['billing_cycle'] as String? ?? 'monthly',
      price: (row['price'] as num?)?.toDouble() ?? 0,
      isActive: row['is_active'] as bool? ?? true,
      createdAt: _parseDate(row['created_at']),
    );
  }

  CoachAvailabilitySlotEntity _mapAvailability(Map<String, dynamic> row) {
    return CoachAvailabilitySlotEntity(
      id: row['id'] as String,
      coachId: row['coach_id'] as String,
      weekday: row['weekday'] as int? ?? 0,
      startTime: row['start_time']?.toString() ?? '',
      endTime: row['end_time']?.toString() ?? '',
      timezone: row['timezone'] as String? ?? 'UTC',
      isActive: row['is_active'] as bool? ?? true,
    );
  }

  CoachClientEntity _mapClient(Map<String, dynamic> row) {
    return CoachClientEntity(
      subscriptionId: row['subscription_id'] as String,
      memberId: normalizeHistoricalId(row['member_id']),
      memberName: normalizeHistoricalLabel(
        row['member_name'],
        'Deleted member',
      ),
      packageTitle: row['package_title'] as String? ?? 'Subscription',
      status: row['status'] as String? ?? 'pending_payment',
      startedAt: _parseDate(row['started_at']) ?? DateTime.now(),
      activePlanCount: row['active_plan_count'] as int? ?? 0,
      lastSessionAt: _parseDate(row['last_session_at']),
    );
  }

  WorkoutPlanEntity _mapWorkoutPlan(Map<String, dynamic> row) {
    return WorkoutPlanEntity(
      id: row['id'] as String,
      memberId: row['member_id'] as String,
      coachId: row['coach_id'] as String?,
      source: row['source'] as String? ?? 'coach',
      title: row['title'] as String? ?? '',
      status: row['status'] as String? ?? 'active',
      planJson: Map<String, dynamic>.from(
        row['plan_json'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      startDate: _parseDate(row['start_date']),
      endDate: _parseDate(row['end_date']),
      assignedAt: _parseDate(row['assigned_at']),
      updatedAt: _parseDate(row['updated_at']),
      completedAt: _parseDate(row['completed_at']),
      conversationSessionId: row['conversation_session_id'] as String?,
      generatedFromDraftId: row['generated_from_draft_id'] as String?,
      planVersion: row['plan_version'] as int? ?? 1,
      defaultReminderTime: row['default_reminder_time'] as String?,
    );
  }

  SubscriptionEntity _mapSubscription(Map<String, dynamic> row) {
    return SubscriptionEntity(
      id: row['id'] as String,
      memberId: normalizeHistoricalId(row['member_id']),
      coachId: normalizeHistoricalId(row['coach_id']),
      packageId: row['package_id'] as String?,
      planName: row['plan_name'] as String? ?? '',
      billingCycle: row['billing_cycle'] as String? ?? 'monthly',
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      status: row['status'] as String? ?? 'pending_payment',
      paymentMethod: row['payment_method'] as String? ?? 'manual',
      startsAt: _parseDate(row['starts_at']),
      endsAt: _parseDate(row['ends_at']),
      activatedAt: _parseDate(row['activated_at']),
      cancelledAt: _parseDate(row['cancelled_at']),
      createdAt: _parseDate(row['created_at']),
    );
  }

  CoachReviewEntity _mapReview(Map<String, dynamic> row) {
    return CoachReviewEntity(
      id: row['id'] as String,
      memberDisplayName: row['member_display_name'] as String? ?? 'Member',
      rating: row['rating'] as int? ?? 0,
      reviewText: row['review_text'] as String? ?? '',
      createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
