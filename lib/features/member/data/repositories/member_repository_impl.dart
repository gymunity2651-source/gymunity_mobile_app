import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/historical_record_utils.dart';
import '../../domain/entities/member_home_summary_entity.dart';
import '../../domain/entities/coaching_engagement_entity.dart';
import '../../domain/entities/member_profile_entity.dart';
import '../../domain/entities/member_progress_entity.dart';
import '../../domain/repositories/member_repository.dart';
import '../../../coach/domain/entities/subscription_entity.dart';
import '../../../coach/domain/entities/coach_workspace_entity.dart';
import '../../../coach/domain/entities/workout_plan_entity.dart';
import '../../../store/domain/entities/order_entity.dart';
import '../../domain/entities/coach_hub_entity.dart';

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
      return rows
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
  Future<String> uploadCoachPaymentReceipt({
    required String subscriptionId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$_userId/$subscriptionId/${DateTime.now().toUtc().microsecondsSinceEpoch}_$safeFileName';
    try {
      await _client.storage
          .from('coach-payment-receipts')
          .uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(upsert: false),
          );
      return path;
    } on StorageException catch (e, st) {
      throw StorageFailure(
        message: e.message,
        code: e.statusCode?.toString(),
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> submitCoachPaymentReceipt({
    required String subscriptionId,
    String? paymentReference,
    String? receiptStoragePath,
    double? amount,
  }) async {
    try {
      await _client.rpc(
        'submit_coach_payment_receipt',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'input_payment_reference': paymentReference,
          'input_receipt_storage_path': receiptStoragePath,
          'input_amount': amount,
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
              'subscription_status': subscription?.status,
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
      await _client.rpc(
        'send_coaching_message',
        params: <String, dynamic>{
          'target_thread_id': threadId,
          'input_content': content.trim(),
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
            workouts_completed,
            missed_workouts,
            missed_workouts_reason,
            soreness_score,
            fatigue_score,
            pain_warning,
            nutrition_adherence_score,
            habit_adherence_score,
            biggest_obstacle,
            support_needed,
            checkin_metadata_json,
            coach_feedback_json,
            coach_feedback_at,
            next_checkin_date,
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
          'input_workouts_completed': workoutsCompleted,
          'input_missed_workouts': missedWorkouts,
          'input_missed_workouts_reason': missedWorkoutsReason,
          'input_soreness_score': sorenessScore,
          'input_fatigue_score': fatigueScore,
          'input_pain_warning': painWarning,
          'input_nutrition_adherence_score': nutritionAdherenceScore,
          'input_habit_adherence_score': habitAdherenceScore,
          'input_biggest_obstacle': biggestObstacle,
          'input_support_needed': supportNeeded,
          'input_metadata_json': metadata,
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
  Future<MemberDailyStreakEntity> recordDailyActivity({
    DateTime? occurredAt,
    String source = 'app_open',
  }) async {
    final localOccurredAt = (occurredAt ?? DateTime.now()).toLocal();
    try {
      final rows = await _client.rpc(
        'touch_member_daily_streak',
        params: <String, dynamic>{
          'input_activity_date': _dateWire(localOccurredAt),
          'input_activity_source': _normalizeActivitySource(source),
          'input_activity_at': localOccurredAt.toUtc().toIso8601String(),
        },
      );
      final row = rows is List && rows.isNotEmpty
          ? _rowMap(rows.first)
          : _rowMap(rows);
      return _mapDailyStreak(row);
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
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _safeRecordDailyActivity(),
      listWeightEntries(),
      listBodyMeasurements(),
      listWorkoutPlans(),
      listWorkoutSessions(),
      listSubscriptions(),
    ]);
    final dailyStreak = results[0] as MemberDailyStreakEntity;
    final weights = results[1] as List<WeightEntryEntity>;
    final measurements = results[2] as List<BodyMeasurementEntity>;
    final plans = results[3] as List<WorkoutPlanEntity>;
    final sessions = results[4] as List<WorkoutSessionEntity>;
    final subscriptions = results[5] as List<SubscriptionEntity>;
    final activePlan = _resolveActivePlan(plans);
    final activeAiPlan = _resolveActiveAiPlan(plans);
    final weeklyCheckins = await _safeListWeeklyCheckins();
    final planConsistency = activeAiPlan == null
        ? const MemberPlanConsistencySummary()
        : await _buildPlanConsistencySummary(
            activeAiPlan,
            weeklyCheckins: weeklyCheckins,
          );

    return MemberHomeSummaryEntity(
      latestWeightEntry: weights.isEmpty ? null : weights.last,
      previousWeightEntry: weights.length > 1
          ? weights[weights.length - 2]
          : null,
      latestMeasurement: measurements.isEmpty ? null : measurements.last,
      activePlan: activePlan,
      activeAiPlan: activeAiPlan,
      latestSession: sessions.isEmpty ? null : sessions.first,
      latestSubscription: subscriptions.isEmpty ? null : subscriptions.first,
      activeCoachCount: _countActiveCoaches(subscriptions),
      hasPendingCoachCheckout: subscriptions.any(
        (subscription) => subscription.isCheckoutPending,
      ),
      planConsistency: planConsistency,
      dailyStreak: dailyStreak,
    );
  }

  @override
  Future<MemberCoachHubEntity> getCoachHub({String? subscriptionId}) async {
    try {
      final row = await _client.rpc(
        'get_member_coach_hub',
        params: <String, dynamic>{'target_subscription_id': subscriptionId}
          ..removeWhere((String key, dynamic value) => value == null),
      );
      return MemberCoachHubEntity.fromMap(_rowMap(row));
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
  Future<List<MemberCoachAgendaItemEntity>> listCoachAgenda({
    required String subscriptionId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_member_coach_agenda',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'input_date_from': _dateWire(dateFrom),
          'input_date_to': _dateWire(dateTo),
        },
      );
      return _asList(rows)
          .map(
            (dynamic row) => MemberCoachAgendaItemEntity.fromMap(_rowMap(row)),
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
    String memberNote = '',
    bool shareProgressSummary = false,
    bool shareNutritionSummary = false,
    bool shareAiSummary = false,
    bool shareWorkoutAdherence = false,
    bool shareProductContext = false,
  }) async {
    try {
      final row = await _client.rpc(
        'submit_coach_kickoff',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'input_primary_goal': primaryGoal,
          'input_training_level': trainingLevel,
          'input_preferred_training_days': preferredTrainingDays,
          'input_available_equipment': availableEquipment,
          'input_injuries_limitations': injuriesLimitations,
          'input_schedule_constraints': scheduleConstraints,
          'input_nutrition_situation': nutritionSituation,
          'input_sleep_recovery_notes': sleepRecoveryNotes,
          'input_biggest_obstacle': biggestObstacle,
          'input_coach_expectations': coachExpectations,
          'input_member_note': memberNote,
          'input_share_progress_summary': shareProgressSummary,
          'input_share_nutrition_summary': shareNutritionSummary,
          'input_share_ai_summary': shareAiSummary,
          'input_share_workout_adherence': shareWorkoutAdherence,
          'input_share_product_context': shareProductContext,
        },
      );
      return MemberCoachKickoffEntity.fromMap(_firstRowOrMap(row));
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
  Future<List<MemberAssignedHabitEntity>> listAssignedHabits({
    String? subscriptionId,
    DateTime? date,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_member_assigned_habits',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'input_date': _dateWire(date ?? DateTime.now()),
        }..removeWhere((String key, dynamic value) => value == null),
      );
      return _asList(rows)
          .map((dynamic row) => MemberAssignedHabitEntity.fromMap(_rowMap(row)))
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
  Future<MemberAssignedHabitEntity?> logAssignedHabit({
    required String assignmentId,
    required String completionStatus,
    DateTime? logDate,
    double? value,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'log_member_assigned_habit',
        params: <String, dynamic>{
          'target_assignment_id': assignmentId,
          'input_log_date': _dateWire(logDate ?? DateTime.now()),
          'input_completion_status': completionStatus,
          'input_value': value,
          'input_note': note,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      final habits = await listAssignedHabits(date: logDate ?? DateTime.now());
      for (final habit in habits) {
        if (habit.id == assignmentId) return habit;
      }
      return null;
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
  Future<List<MemberAssignedResourceEntity>> listAssignedResources({
    String? subscriptionId,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_member_assigned_resources',
        params: <String, dynamic>{'target_subscription_id': subscriptionId}
          ..removeWhere((String key, dynamic value) => value == null),
      );
      return _asList(rows)
          .map(
            (dynamic row) => MemberAssignedResourceEntity.fromMap(_rowMap(row)),
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
  Future<MemberAssignedResourceEntity?> markResourceProgress({
    required String assignmentId,
    bool markViewed = true,
    bool markCompleted = false,
    String? memberNote,
  }) async {
    try {
      await _client.rpc(
        'mark_member_resource_progress',
        params: <String, dynamic>{
          'target_assignment_id': assignmentId,
          'input_mark_viewed': markViewed,
          'input_mark_completed': markCompleted,
          'input_member_note': memberNote,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      final resources = await listAssignedResources();
      for (final resource in resources) {
        if (resource.id == assignmentId) return resource;
      }
      return null;
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
  Future<String> createCoachResourceSignedUrl(String storagePath) async {
    try {
      return await _client.storage
          .from('coach-resources')
          .createSignedUrl(storagePath, 60 * 15);
    } on StorageException catch (e, st) {
      throw StorageFailure(
        message: e.message,
        code: e.statusCode?.toString(),
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<List<CoachSessionTypeEntity>> listBookableSessionTypes({
    required String subscriptionId,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_member_bookable_session_types',
        params: <String, dynamic>{'target_subscription_id': subscriptionId},
      );
      return _asList(rows)
          .map((dynamic row) => CoachSessionTypeEntity.fromMap(_rowMap(row)))
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
  Future<List<MemberBookableSlotEntity>> listBookableSlots({
    required String coachId,
    required String sessionTypeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_coach_bookable_slots',
        params: <String, dynamic>{
          'target_coach_id': coachId,
          'target_session_type_id': sessionTypeId,
          'input_date_from': _dateWire(dateFrom),
          'input_date_to': _dateWire(dateTo),
        },
      );
      return _asList(rows)
          .map((dynamic row) => MemberBookableSlotEntity.fromMap(_rowMap(row)))
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
  Future<List<CoachBookingEntity>> listMemberBookings({
    required String subscriptionId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_coach_bookings',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'input_date_from': from?.toUtc().toIso8601String(),
          'input_date_to': to?.toUtc().toIso8601String(),
        }..removeWhere((String key, dynamic value) => value == null),
      );
      return _asList(rows)
          .map((dynamic row) => CoachBookingEntity.fromMap(_rowMap(row)))
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
  Future<CoachBookingEntity> createMemberBooking({
    required String subscriptionId,
    required String sessionTypeId,
    required DateTime startsAt,
    String timezone = 'UTC',
    String? note,
  }) async {
    try {
      final row = await _client.rpc(
        'create_coach_booking',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'target_session_type_id': sessionTypeId,
          'input_starts_at': startsAt.toUtc().toIso8601String(),
          'input_timezone': timezone,
          'input_note': note,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      return CoachBookingEntity.fromMap(_firstRowOrMap(row));
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
  Future<CoachBookingEntity> updateMemberBookingStatus({
    required String bookingId,
    required String status,
    String? reason,
  }) async {
    try {
      final row = await _client.rpc(
        'update_coach_booking_status',
        params: <String, dynamic>{
          'target_booking_id': bookingId,
          'input_status': status,
          'input_reason': reason,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      return CoachBookingEntity.fromMap(_firstRowOrMap(row));
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<MemberDailyStreakEntity> _safeRecordDailyActivity() async {
    try {
      return await recordDailyActivity();
    } catch (_) {
      // The home summary should keep rendering even if the streak rollout
      // RPC or schema is temporarily unavailable.
      return const MemberDailyStreakEntity();
    }
  }

  WorkoutPlanEntity? _resolveActivePlan(List<WorkoutPlanEntity> plans) {
    for (final plan in plans) {
      if (plan.status == 'active') {
        return plan;
      }
    }
    return plans.isEmpty ? null : plans.first;
  }

  WorkoutPlanEntity? _resolveActiveAiPlan(List<WorkoutPlanEntity> plans) {
    for (final plan in plans) {
      if (_isActiveAiPlan(plan)) {
        return plan;
      }
    }
    return null;
  }

  bool _isActiveAiPlan(WorkoutPlanEntity plan) {
    if (plan.status != 'active') {
      return false;
    }
    final source = plan.source.trim().toLowerCase();
    return source == 'ai' ||
        (plan.generatedFromDraftId?.trim().isNotEmpty ?? false) ||
        (plan.conversationSessionId?.trim().isNotEmpty ?? false);
  }

  int _countActiveCoaches(List<SubscriptionEntity> subscriptions) {
    final activeCoachKeys = <String>{};
    for (final subscription in subscriptions) {
      if (!subscription.isActive) {
        continue;
      }
      final coachId = subscription.coachId.trim();
      activeCoachKeys.add(
        coachId.isEmpty ? 'subscription:${subscription.id}' : coachId,
      );
    }
    return activeCoachKeys.length;
  }

  Future<List<WeeklyCheckinEntity>> _safeListWeeklyCheckins() async {
    try {
      return await listWeeklyCheckins();
    } catch (_) {
      return const <WeeklyCheckinEntity>[];
    }
  }

  Future<MemberPlanConsistencySummary> _buildPlanConsistencySummary(
    WorkoutPlanEntity activeAiPlan, {
    required List<WeeklyCheckinEntity> weeklyCheckins,
  }) async {
    final now = DateTime.now();
    final currentWeekStart = _startOfWeek(now);
    final anchorDate =
        activeAiPlan.startDate ??
        activeAiPlan.assignedAt ??
        activeAiPlan.updatedAt ??
        now;
    final firstWeekStart = _startOfWeek(anchorDate);
    final endDate = activeAiPlan.endDate;
    final lastWeekStart = endDate == null
        ? currentWeekStart
        : _startOfWeek(endDate.isBefore(now) ? endDate : now);

    if (lastWeekStart.isBefore(firstWeekStart)) {
      return const MemberPlanConsistencySummary();
    }

    final aiWeeklySummaries = await _listAiWeeklySummaryRows(
      from: firstWeekStart,
      to: lastWeekStart,
    );
    final planAgenda = await _listPlanAgendaRows(
      planId: activeAiPlan.id,
      dateFrom: firstWeekStart,
      dateTo: lastWeekStart.add(const Duration(days: 6)),
    );

    final aiSummaryByWeek = <String, _AiWeeklySummarySnapshot>{
      for (final row in aiWeeklySummaries) _dateWire(row.weekStart): row,
    };
    final checkinByWeek = <String, WeeklyCheckinEntity>{};
    for (final checkin in weeklyCheckins) {
      final weekKey = _dateWire(_startOfWeek(checkin.weekStart));
      checkinByWeek.putIfAbsent(weekKey, () => checkin);
    }
    final taskScoreByWeek = _computeTaskAdherenceByWeek(planAgenda);
    final weeks = <MemberPlanConsistencyWeek>[];

    for (
      var week = firstWeekStart;
      !week.isAfter(lastWeekStart);
      week = week.add(const Duration(days: 7))
    ) {
      final weekKey = _dateWire(week);
      final isCurrentWeek = _isSameDate(week, currentWeekStart);
      final aiSummary = aiSummaryByWeek[weekKey];
      final weeklyCheckin = checkinByWeek[weekKey];
      final taskScore = taskScoreByWeek[weekKey];

      int? adherenceScore;
      var source = MemberPlanConsistencySource.none;

      if (aiSummary != null) {
        adherenceScore = aiSummary.adherenceScore;
        source = MemberPlanConsistencySource.aiSummary;
      } else if (weeklyCheckin != null) {
        adherenceScore = weeklyCheckin.adherenceScore;
        source = MemberPlanConsistencySource.weeklyCheckin;
      } else if (taskScore != null) {
        adherenceScore = taskScore;
        source = MemberPlanConsistencySource.taskLogs;
      }

      final state = isCurrentWeek || adherenceScore == null
          ? MemberPlanConsistencyState.pending
          : adherenceScore >= 70
          ? MemberPlanConsistencyState.consistent
          : MemberPlanConsistencyState.inconsistent;

      weeks.add(
        MemberPlanConsistencyWeek(
          weekStart: week,
          adherenceScore: adherenceScore,
          state: state,
          source: source,
        ),
      );
    }

    final completedWeeks = weeks
        .where((week) => week.state != MemberPlanConsistencyState.pending)
        .toList(growable: false);

    var currentStreakWeeks = 0;
    for (final week in weeks.reversed) {
      if (week.state == MemberPlanConsistencyState.pending) {
        continue;
      }
      if (week.isConsistent) {
        currentStreakWeeks++;
        continue;
      }
      break;
    }

    return MemberPlanConsistencySummary(
      weeks: weeks,
      currentStreakWeeks: currentStreakWeeks,
      totalConsistentWeeks: completedWeeks
          .where((week) => week.isConsistent)
          .length,
    );
  }

  Future<List<_AiWeeklySummarySnapshot>> _listAiWeeklySummaryRows({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await _client
          .from('member_ai_weekly_summaries')
          .select('week_start, adherence_score')
          .eq('member_id', _userId)
          .gte('week_start', _dateWire(from))
          .lte('week_start', _dateWire(to))
          .order('week_start', ascending: true);
      return (rows as List<dynamic>)
          .map(
            (dynamic row) => _AiWeeklySummarySnapshot(
              weekStart: _parseDate(
                (row as Map<String, dynamic>)['week_start'],
              )!,
              adherenceScore: (row['adherence_score'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false);
    } on PostgrestException {
      return const <_AiWeeklySummarySnapshot>[];
    }
  }

  Future<List<_PlanAgendaSnapshot>> _listPlanAgendaRows({
    required String planId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_member_plan_agenda',
        params: <String, dynamic>{
          'input_plan_id': planId,
          'input_date_from': _dateWire(dateFrom),
          'input_date_to': _dateWire(dateTo),
        },
      );
      if (rows is! List) {
        return const <_PlanAgendaSnapshot>[];
      }
      return rows
          .whereType<Map>()
          .map(
            (dynamic row) => _PlanAgendaSnapshot(
              scheduledDate: _parseDate(
                (row as Map<String, dynamic>)['scheduled_date'],
              )!,
              isRequired: row['is_required'] as bool? ?? true,
              effectiveStatus: row['effective_status'] as String? ?? 'pending',
              completionPercent: (row['completion_percent'] as num?)?.toInt(),
            ),
          )
          .toList(growable: false);
    } on PostgrestException {
      return const <_PlanAgendaSnapshot>[];
    }
  }

  Map<String, int> _computeTaskAdherenceByWeek(
    List<_PlanAgendaSnapshot> planAgenda,
  ) {
    final accumulators = <String, _WeekAdherenceAccumulator>{};
    for (final task in planAgenda) {
      if (!task.isRequired) {
        continue;
      }
      final weekStart = _startOfWeek(task.scheduledDate);
      final weekKey = _dateWire(weekStart);
      final accumulator = accumulators.putIfAbsent(
        weekKey,
        () => _WeekAdherenceAccumulator(),
      );
      accumulator.totalTasks++;
      switch (task.effectiveStatus) {
        case 'completed':
          accumulator.completedWeight += 1;
          break;
        case 'partial':
          accumulator.completedWeight +=
              (task.completionPercent ?? 50).clamp(0, 100) / 100;
          break;
      }
    }

    return <String, int>{
      for (final entry in accumulators.entries)
        if (entry.value.totalTasks > 0)
          entry.key:
              ((entry.value.completedWeight / entry.value.totalTasks) * 100)
                  .round(),
    };
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
      paymentGateway: row['payment_gateway'] as String?,
      paymentOrderId: row['payment_order_id'] as String?,
      amountCents: (row['amount_cents'] as num?)?.toInt(),
      currency: row['currency'] as String? ?? 'EGP',
      platformFeeCents: (row['platform_fee_cents'] as num?)?.toInt() ?? 0,
      coachNetCents: (row['coach_net_cents'] as num?)?.toInt() ?? 0,
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
      workoutsCompleted: (row['workouts_completed'] as num?)?.toInt(),
      missedWorkouts: (row['missed_workouts'] as num?)?.toInt(),
      missedWorkoutsReason: row['missed_workouts_reason'] as String?,
      sorenessScore: (row['soreness_score'] as num?)?.toInt(),
      fatigueScore: (row['fatigue_score'] as num?)?.toInt(),
      painWarning: row['pain_warning'] as String?,
      nutritionAdherenceScore: (row['nutrition_adherence_score'] as num?)
          ?.toInt(),
      habitAdherenceScore: (row['habit_adherence_score'] as num?)?.toInt(),
      biggestObstacle: row['biggest_obstacle'] as String?,
      supportNeeded: row['support_needed'] as String?,
      checkinMetadata: _rowMap(row['checkin_metadata_json']),
      coachFeedback: _rowMap(row['coach_feedback_json']),
      coachFeedbackAt: _parseDate(row['coach_feedback_at']),
      nextCheckinDate: _parseDate(row['next_checkin_date']),
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

  MemberDailyStreakEntity _mapDailyStreak(Map<String, dynamic> row) {
    final rawCount = row['current_streak_count'] ?? row['daily_streak_count'];
    return MemberDailyStreakEntity(
      currentCount: (rawCount as num?)?.toInt() ?? 0,
      lastActivityDate: _parseDate(
        row['last_activity_date'] ?? row['daily_streak_last_active_on'],
      ),
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  String _normalizeActivitySource(String source) {
    final normalized = source.trim();
    return normalized.isEmpty ? 'app_open' : normalized;
  }

  String _dateWire(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    return normalized.toIso8601String().split('T').first;
  }

  DateTime _startOfWeek(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
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

  Map<String, dynamic> _firstRowOrMap(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return _rowMap(value.first);
    }
    return _rowMap(value);
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

class _AiWeeklySummarySnapshot {
  const _AiWeeklySummarySnapshot({
    required this.weekStart,
    required this.adherenceScore,
  });

  final DateTime weekStart;
  final int adherenceScore;
}

class _PlanAgendaSnapshot {
  const _PlanAgendaSnapshot({
    required this.scheduledDate,
    required this.isRequired,
    required this.effectiveStatus,
    this.completionPercent,
  });

  final DateTime scheduledDate;
  final bool isRequired;
  final String effectiveStatus;
  final int? completionPercent;
}

class _WeekAdherenceAccumulator {
  int totalTasks = 0;
  double completedWeight = 0;
}
