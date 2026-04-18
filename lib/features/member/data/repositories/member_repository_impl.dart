import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/historical_record_utils.dart';
import '../../domain/entities/member_home_summary_entity.dart';
import '../../domain/entities/coaching_engagement_entity.dart';
import '../../domain/entities/member_profile_entity.dart';
import '../../domain/entities/member_progress_entity.dart';
import '../../domain/repositories/member_repository.dart';
import '../../../coach/domain/entities/subscription_entity.dart';
import '../../../coach/domain/entities/workout_plan_entity.dart';
import '../../../store/domain/entities/order_entity.dart';

class MemberRepositoryImpl implements MemberRepository {
  MemberRepositoryImpl(this._client);

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'No authenticated member found.');
    }
    return userId;
  }

  @override
  Future<MemberProfileEntity?> getMemberProfile() async {
    try {
      final row = await _client
          .from('member_profiles')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return _mapMemberProfile(row);
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
  }) async {
    final userId = _userId;
    try {
      await _client
          .from('member_profiles')
          .upsert(
            <String, dynamic>{
              'user_id': userId,
              'goal': goal,
              'age': age,
              'gender': gender,
              'height_cm': heightCm,
              'current_weight_kg': currentWeightKg,
              'training_frequency': trainingFrequency,
              'experience_level': experienceLevel,
              'budget_egp': budgetEgp,
              'city': city,
              'coaching_preference': coachingPreference,
              'training_place': trainingPlace,
              'preferred_language': preferredLanguage,
              'preferred_coach_gender': preferredCoachGender,
            }..removeWhere((String key, dynamic value) => value == null),
          );

      await _client
          .from('profiles')
          .update(<String, dynamic>{
            'onboarding_completed': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId);

      final existingWeight = await _client
          .from('member_weight_entries')
          .select('id')
          .eq('member_id', userId)
          .limit(1);
      if ((existingWeight as List<dynamic>).isEmpty) {
        await _client.from('member_weight_entries').insert(<String, dynamic>{
          'member_id': userId,
          'weight_kg': currentWeightKg,
          'recorded_at': DateTime.now().toUtc().toIso8601String(),
          'note': 'Initial onboarding weight',
        });
      }
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
  Future<UserPreferencesEntity> getPreferences() async {
    try {
      final row = await _client
          .from('user_preferences')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();
      if (row == null) {
        return const UserPreferencesEntity();
      }
      return UserPreferencesEntity(
        pushNotificationsEnabled:
            row['push_notifications_enabled'] as bool? ?? true,
        aiTipsEnabled: row['ai_tips_enabled'] as bool? ?? true,
        orderUpdatesEnabled: row['order_updates_enabled'] as bool? ?? true,
        measurementUnit: row['measurement_unit'] as String? ?? 'metric',
        language: row['language'] as String? ?? 'english',
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
  Future<void> upsertPreferences(UserPreferencesEntity preferences) async {
    try {
      await _client.from('user_preferences').upsert(<String, dynamic>{
        'user_id': _userId,
        'push_notifications_enabled': preferences.pushNotificationsEnabled,
        'ai_tips_enabled': preferences.aiTipsEnabled,
        'order_updates_enabled': preferences.orderUpdatesEnabled,
        'measurement_unit': preferences.measurementUnit,
        'language': preferences.language,
      });
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
  Future<List<WeightEntryEntity>> listWeightEntries() async {
    try {
      final rows = await _client
          .from('member_weight_entries')
          .select()
          .eq('member_id', _userId)
          .order('recorded_at', ascending: true);

      return (rows as List<dynamic>)
          .map((dynamic row) => _mapWeightEntry(row as Map<String, dynamic>))
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
  Future<void> saveWeightEntry({
    String? entryId,
    required double weightKg,
    required DateTime recordedAt,
    String? note,
  }) async {
    try {
      await _client
          .from('member_weight_entries')
          .upsert(
            <String, dynamic>{
              'id': entryId,
              'member_id': _userId,
              'weight_kg': weightKg,
              'recorded_at': recordedAt.toUtc().toIso8601String(),
              'note': note,
            }..removeWhere((String key, dynamic value) => value == null),
          );

      await _client.from('member_profiles').upsert(<String, dynamic>{
        'user_id': _userId,
        'current_weight_kg': weightKg,
      });
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
  Future<void> deleteWeightEntry(String entryId) async {
    try {
      await _client
          .from('member_weight_entries')
          .delete()
          .eq('id', entryId)
          .eq('member_id', _userId);
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
  Future<List<BodyMeasurementEntity>> listBodyMeasurements() async {
    try {
      final rows = await _client
          .from('member_body_measurements')
          .select()
          .eq('member_id', _userId)
          .order('recorded_at', ascending: true);
      return (rows as List<dynamic>)
          .map(
            (dynamic row) => _mapBodyMeasurement(row as Map<String, dynamic>),
          )
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
  }) async {
    try {
      await _client
          .from('member_body_measurements')
          .upsert(
            <String, dynamic>{
              'id': entryId,
              'member_id': _userId,
              'recorded_at': recordedAt.toUtc().toIso8601String(),
              'waist_cm': waistCm,
              'chest_cm': chestCm,
              'hips_cm': hipsCm,
              'arm_cm': armCm,
              'thigh_cm': thighCm,
              'body_fat_percent': bodyFatPercent,
              'note': note,
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
  Future<void> deleteBodyMeasurement(String entryId) async {
    try {
      await _client
          .from('member_body_measurements')
          .delete()
          .eq('id', entryId)
          .eq('member_id', _userId);
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
  Future<List<WorkoutPlanEntity>> listWorkoutPlans() async {
    try {
      final rows = await _client
          .from('workout_plans')
          .select()
          .eq('member_id', _userId)
          .order('assigned_at', ascending: false);
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
  Future<List<WorkoutSessionEntity>> listWorkoutSessions() async {
    try {
      final rows = await _client
          .from('workout_sessions')
          .select()
          .eq('member_id', _userId)
          .order('performed_at', ascending: false);
      return (rows as List<dynamic>)
          .map((dynamic row) => _mapWorkoutSession(row as Map<String, dynamic>))
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
  Future<void> saveWorkoutSession({
    String? sessionId,
    required String title,
    required DateTime performedAt,
    required int durationMinutes,
    String? workoutPlanId,
    String? coachId,
    String? note,
  }) async {
    try {
      var resolvedCoachId = coachId;
      if ((resolvedCoachId == null || resolvedCoachId.isEmpty) &&
          workoutPlanId != null &&
          workoutPlanId.isNotEmpty) {
        final planRow = await _client
            .from('workout_plans')
            .select('coach_id')
            .eq('id', workoutPlanId)
            .maybeSingle();
        resolvedCoachId = planRow?['coach_id'] as String?;
      }

      await _client
          .from('workout_sessions')
          .upsert(
            <String, dynamic>{
              'id': sessionId,
              'member_id': _userId,
              'workout_plan_id': workoutPlanId,
              'coach_id': resolvedCoachId,
              'title': title,
              'performed_at': performedAt.toUtc().toIso8601String(),
              'duration_minutes': durationMinutes,
              'note': note,
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
  Future<void> deleteWorkoutSession(String sessionId) async {
    try {
      await _client
          .from('workout_sessions')
          .delete()
          .eq('id', sessionId)
          .eq('member_id', _userId);
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
      final rows = await _listSubscriptionRows();
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

  Future<List<dynamic>> _listSubscriptionRows() async {
    try {
      return await _client.rpc('list_member_subscriptions_live')
          as List<dynamic>;
    } on PostgrestException catch (error) {
      if (!_shouldFallbackToDetailedSubscriptions(error)) {
        rethrow;
      }
      return await _client.rpc('list_member_subscriptions_detailed')
          as List<dynamic>;
    }
  }

  bool _shouldFallbackToDetailedSubscriptions(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == 'PGRST202' &&
        message.contains('list_member_subscriptions_live');
  }

  @override
  Future<SubscriptionEntity> confirmCoachPayment({
    required String subscriptionId,
    String? paymentReference,
  }) async {
    try {
      final rows = await _client.rpc(
        'confirm_coach_payment',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'input_payment_reference': paymentReference,
        }..removeWhere((String key, dynamic value) => value == null),
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
  Future<SubscriptionEntity> pauseSubscription({
    required String subscriptionId,
    bool pauseNow = true,
  }) async {
    try {
      await _client.rpc(
        'pause_coach_subscription',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'pause_now': pauseNow,
        },
      );
      final subscriptions = await listSubscriptions();
      return subscriptions.firstWhere(
        (subscription) => subscription.id == subscriptionId,
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
  Future<List<CoachingThreadEntity>> listCoachingThreads() async {
    try {
      final rows = await _client
          .from('coach_member_threads')
          .select()
          .eq('member_id', _userId)
          .order('updated_at', ascending: false);
      final subscriptions = await listSubscriptions();
      final subscriptionsById = <String, SubscriptionEntity>{
        for (final subscription in subscriptions) subscription.id: subscription,
      };

      return (rows as List<dynamic>)
          .map((dynamic row) {
            final threadRow = row as Map<String, dynamic>;
            final subscription =
                subscriptionsById[threadRow['subscription_id']];
            return _mapThread(<String, dynamic>{
              ...threadRow,
              'coach_name': subscription?.coachName,
              'package_title': subscription?.displayTitle,
            });
          })
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
  Future<List<CoachingMessageEntity>> listCoachingMessages(
    String threadId,
  ) async {
    try {
      final rows = await _client
          .from('coach_messages')
          .select()
          .eq('thread_id', threadId)
          .order('created_at', ascending: true);
      return (rows as List<dynamic>)
          .map((dynamic row) => _mapMessage(row as Map<String, dynamic>))
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
  Future<void> sendCoachingMessage({
    required String threadId,
    required String content,
  }) async {
    try {
      await _client.from('coach_messages').insert(<String, dynamic>{
        'thread_id': threadId,
        'sender_user_id': _userId,
        'sender_role': 'member',
        'message_type': 'text',
        'content': content.trim(),
      });
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
  Future<List<WeeklyCheckinEntity>> listWeeklyCheckins({
    String? subscriptionId,
  }) async {
    try {
      dynamic query = _client
          .from('weekly_checkins')
          .select('''
            id,
            subscription_id,
            thread_id,
            member_id,
            coach_id,
            week_start,
            weight_kg,
            waist_cm,
            adherence_score,
            energy_score,
            sleep_score,
            wins,
            blockers,
            questions,
            coach_reply,
            created_at,
            updated_at,
            progress_photos(id, storage_path, angle, created_at)
          ''')
          .eq('member_id', _userId)
          .order('week_start', ascending: false);
      if (subscriptionId != null && subscriptionId.isNotEmpty) {
        query = query.eq('subscription_id', subscriptionId);
      }

      final rows = await query;
      return (rows as List<dynamic>)
          .map((dynamic row) => _mapWeeklyCheckin(row as Map<String, dynamic>))
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
  }) async {
    try {
      final rows = await _client.rpc(
        'submit_weekly_checkin',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'input_week_start': DateTime.utc(
            weekStart.year,
            weekStart.month,
            weekStart.day,
          ).toIso8601String().split('T').first,
          'input_weight_kg': weightKg,
          'input_waist_cm': waistCm,
          'input_adherence_score': adherenceScore,
          'input_energy_score': energyScore,
          'input_sleep_score': sleepScore,
          'input_wins': wins,
          'input_blockers': blockers,
          'input_questions': questions,
          'input_photo_paths': photos,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      final entity = _mapWeeklyCheckin(
        (rows as List<dynamic>).first as Map<String, dynamic>,
      );
      return entity;
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
  Future<List<OrderEntity>> listOrders() async {
    try {
      final rows = await _client.rpc('list_member_orders_detailed');
      return (rows as List<dynamic>)
          .map((dynamic row) => _mapOrder(row as Map<String, dynamic>))
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
  Future<MemberHomeSummaryEntity> getHomeSummary() async {
    final weights = await listWeightEntries();
    final measurements = await listBodyMeasurements();
    final plans = await listWorkoutPlans();
    final sessions = await listWorkoutSessions();
    final subscriptions = await listSubscriptions();
    return MemberHomeSummaryEntity(
      latestWeightEntry: weights.isEmpty ? null : weights.last,
      latestMeasurement: measurements.isEmpty ? null : measurements.last,
      activePlan: plans.cast<WorkoutPlanEntity?>().firstWhere(
        (WorkoutPlanEntity? plan) => plan?.status == 'active',
        orElse: () => plans.isEmpty ? null : plans.first,
      ),
      latestSession: sessions.isEmpty ? null : sessions.first,
      latestSubscription: subscriptions.isEmpty ? null : subscriptions.first,
    );
  }

  MemberProfileEntity _mapMemberProfile(Map<String, dynamic> row) {
    return MemberProfileEntity(
      userId: row['user_id'] as String,
      goal: row['goal'] as String?,
      age: row['age'] as int?,
      gender: row['gender'] as String?,
      heightCm: (row['height_cm'] as num?)?.toDouble(),
      currentWeightKg: (row['current_weight_kg'] as num?)?.toDouble(),
      trainingFrequency: row['training_frequency'] as String?,
      experienceLevel: row['experience_level'] as String?,
      budgetEgp: (row['budget_egp'] as num?)?.toInt(),
      city: row['city'] as String?,
      coachingPreference: row['coaching_preference'] as String?,
      trainingPlace: row['training_place'] as String?,
      preferredLanguage: row['preferred_language'] as String?,
      preferredCoachGender: row['preferred_coach_gender'] as String?,
    );
  }

  WeightEntryEntity _mapWeightEntry(Map<String, dynamic> row) {
    return WeightEntryEntity(
      id: row['id'] as String,
      memberId: row['member_id'] as String,
      weightKg: (row['weight_kg'] as num).toDouble(),
      recordedAt:
          DateTime.tryParse(row['recorded_at'] as String? ?? '') ??
          DateTime.now(),
      note: row['note'] as String?,
    );
  }

  BodyMeasurementEntity _mapBodyMeasurement(Map<String, dynamic> row) {
    return BodyMeasurementEntity(
      id: row['id'] as String,
      memberId: row['member_id'] as String,
      recordedAt:
          DateTime.tryParse(row['recorded_at'] as String? ?? '') ??
          DateTime.now(),
      waistCm: (row['waist_cm'] as num?)?.toDouble(),
      chestCm: (row['chest_cm'] as num?)?.toDouble(),
      hipsCm: (row['hips_cm'] as num?)?.toDouble(),
      armCm: (row['arm_cm'] as num?)?.toDouble(),
      thighCm: (row['thigh_cm'] as num?)?.toDouble(),
      bodyFatPercent: (row['body_fat_percent'] as num?)?.toDouble(),
      note: row['note'] as String?,
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
      planJson: _rowMap(row['plan_json']),
      startDate: _parseDate(row['start_date']),
      endDate: _parseDate(row['end_date']),
      assignedAt: _parseDate(row['assigned_at']),
      updatedAt: _parseDate(row['updated_at']),
      completedAt: _parseDate(row['completed_at']),
      conversationSessionId: row['conversation_session_id'] as String?,
      generatedFromDraftId: row['generated_from_draft_id'] as String?,
      planVersion: (row['plan_version'] as num?)?.toInt() ?? 1,
      defaultReminderTime: row['default_reminder_time'] as String?,
    );
  }

  WorkoutSessionEntity _mapWorkoutSession(Map<String, dynamic> row) {
    return WorkoutSessionEntity(
      id: row['id'] as String,
      memberId: row['member_id'] as String,
      title: row['title'] as String? ?? '',
      performedAt:
          DateTime.tryParse(row['performed_at'] as String? ?? '') ??
          DateTime.now(),
      durationMinutes: row['duration_minutes'] as int? ?? 0,
      workoutPlanId: row['workout_plan_id'] as String?,
      coachId: row['coach_id'] as String?,
      note: row['note'] as String?,
    );
  }

  SubscriptionEntity _mapSubscription(Map<String, dynamic> row) {
    final memberId = normalizeHistoricalId(row['member_id']);
    return SubscriptionEntity(
      id: row['id'] as String,
      memberId: memberId.isEmpty ? _userId : memberId,
      coachId: normalizeHistoricalId(row['coach_id']),
      coachName: normalizeHistoricalLabel(row['coach_name'], 'Deleted coach'),
      coachCity: row['coach_city'] as String?,
      packageId: row['package_id'] as String?,
      packageTitle: row['package_title'] as String?,
      planName: row['plan_name'] as String? ?? '',
      billingCycle: row['billing_cycle'] as String? ?? 'monthly',
      amount: (row['amount'] as num?)?.toDouble() ?? 0,
      status: row['status'] as String? ?? 'checkout_pending',
      paymentMethod: row['payment_method'] as String? ?? 'manual',
      checkoutStatus: row['checkout_status'] as String? ?? 'not_started',
      startsAt: _parseDate(row['starts_at']),
      endsAt: _parseDate(row['ends_at']),
      activatedAt: _parseDate(row['activated_at']),
      cancelledAt: _parseDate(row['cancelled_at']),
      createdAt: _parseDate(row['created_at']),
      nextRenewalAt: _parseDate(row['next_renewal_at']),
      pausedAt: _parseDate(row['paused_at']),
      cancelAtPeriodEnd: row['cancel_at_period_end'] as bool? ?? false,
      trialDays: (row['trial_days'] as num?)?.toInt(),
      renewalPriceEgp: (row['renewal_price_egp'] as num?)?.toDouble(),
      responseSlaHours: (row['response_sla_hours'] as num?)?.toInt(),
      verificationStatus: row['verification_status'] as String?,
      weeklyCheckinType: row['weekly_checkin_type'] as String?,
      deliveryMode: row['delivery_mode'] as String?,
      locationMode: row['location_mode'] as String?,
      threadId: row['thread_id'] as String?,
    );
  }

  CoachingThreadEntity _mapThread(Map<String, dynamic> row) {
    return CoachingThreadEntity(
      id: row['id'] as String,
      subscriptionId: row['subscription_id'] as String,
      memberId: row['member_id'] as String,
      coachId: row['coach_id'] as String,
      coachName: row['coach_name'] as String?,
      packageTitle: row['package_title'] as String?,
      lastMessagePreview: row['last_message_preview'] as String? ?? '',
      lastMessageAt: _parseDate(row['last_message_at']),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  CoachingMessageEntity _mapMessage(Map<String, dynamic> row) {
    return CoachingMessageEntity(
      id: row['id'] as String,
      threadId: row['thread_id'] as String,
      senderUserId: row['sender_user_id'] as String,
      senderRole: row['sender_role'] as String? ?? 'member',
      messageType: row['message_type'] as String? ?? 'text',
      content: row['content'] as String? ?? '',
      createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
    );
  }

  WeeklyCheckinEntity _mapWeeklyCheckin(Map<String, dynamic> row) {
    return WeeklyCheckinEntity(
      id: row['id'] as String,
      subscriptionId: row['subscription_id'] as String,
      threadId: row['thread_id'] as String?,
      memberId: row['member_id'] as String,
      coachId: row['coach_id'] as String,
      weekStart:
          _parseDate(row['week_start']) ??
          DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      waistCm: (row['waist_cm'] as num?)?.toDouble(),
      adherenceScore: (row['adherence_score'] as num?)?.toInt() ?? 0,
      energyScore: (row['energy_score'] as num?)?.toInt(),
      sleepScore: (row['sleep_score'] as num?)?.toInt(),
      wins: row['wins'] as String?,
      blockers: row['blockers'] as String?,
      questions: row['questions'] as String?,
      coachReply: row['coach_reply'] as String?,
      photos: _asList(row['progress_photos'])
          .map(
            (dynamic photo) => _mapProgressPhoto(photo as Map<String, dynamic>),
          )
          .toList(growable: false),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  ProgressPhotoEntity _mapProgressPhoto(Map<String, dynamic> row) {
    return ProgressPhotoEntity(
      id: row['id'] as String? ?? '',
      storagePath: row['storage_path'] as String? ?? '',
      angle: row['angle'] as String? ?? 'front',
      createdAt: _parseDate(row['created_at']),
    );
  }

  OrderEntity _mapOrder(Map<String, dynamic> row) {
    return OrderEntity(
      id: row['id'] as String,
      memberId: _userId,
      sellerId: normalizeHistoricalId(row['seller_id']),
      sellerName: normalizeHistoricalLabel(
        row['seller_name'],
        'Deleted seller',
      ),
      status: row['status'] as String? ?? 'pending',
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'USD',
      paymentMethod: row['payment_method'] as String? ?? 'manual',
      itemCount: row['item_count'] as int? ?? 0,
      shippingAddress: Map<String, dynamic>.from(
        row['shipping_address_json'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> _rowMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic rowValue) => MapEntry(key.toString(), rowValue),
      );
    }
    return const <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List<dynamic>) {
      return value;
    }
    if (value is List) {
      return List<dynamic>.from(value);
    }
    return const <dynamic>[];
  }
}
