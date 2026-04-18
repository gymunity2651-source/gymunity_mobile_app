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
    String? city,
    String? language,
    String? coachGender,
    double? maxBudget,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final rows =
          await _client.rpc(
                'list_coach_directory_v2',
                params: <String, dynamic>{
                  'specialty_filter': specialty,
                  'city_filter': city,
                  'language_filter': language,
                  'gender_filter': coachGender,
                  'max_budget_egp': maxBudget,
                  'limit_count': limit,
                }..removeWhere((String key, dynamic value) => value == null),
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
      final userProfile = await _client
          .from('profiles')
          .select('full_name, avatar_path')
          .eq('user_id', coachId)
          .maybeSingle();
      final coachProfile = await _client
          .from('coach_profiles')
          .select()
          .eq('user_id', coachId)
          .maybeSingle();
      if (userProfile == null && coachProfile == null) {
        return null;
      }

      final packages = await listCoachPackages(
        coachId: coachId,
        activeOnly: true,
      );
      final publishedPackages = packages
          .where((package) => package.visibilityStatus == 'published')
          .toList();
      publishedPackages.sort((a, b) => a.price.compareTo(b.price));
      final availability = await listAvailability(coachId: coachId);
      final reviews = await listCoachReviews(coachId);
      final profile = coachProfile ?? const <String, dynamic>{};
      final user = userProfile ?? const <String, dynamic>{};

      return CoachEntity(
        id: coachId,
        name: user['full_name'] as String? ?? 'Coach',
        avatarPath: user['avatar_path'] as String?,
        bio: profile['bio'] as String? ?? '',
        specialties:
            (profile['specialties'] as List<dynamic>? ?? const <dynamic>[])
                .cast<String>(),
        yearsExperience: profile['years_experience'] as int? ?? 0,
        hourlyRate: (profile['hourly_rate'] as num?)?.toDouble() ?? 0,
        pricingCurrency: profile['pricing_currency'] as String? ?? 'EGP',
        ratingAvg: (profile['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: profile['rating_count'] as int? ?? 0,
        isVerified:
            (profile['verification_status'] as String? ?? '') == 'verified' ||
            (profile['is_verified'] as bool? ?? false),
        city: profile['city'] as String?,
        languages: _asList(
          profile['languages'],
        ).map((dynamic value) => value.toString()).toList(growable: false),
        coachGender: profile['coach_gender'] as String?,
        verificationStatus:
            profile['verification_status'] as String? ?? 'unverified',
        responseSlaHours:
            (profile['response_sla_hours'] as num?)?.toInt() ?? 12,
        trialOfferEnabled: profile['trial_offer_enabled'] as bool? ?? false,
        trialPriceEgp: (profile['trial_price_egp'] as num?)?.toDouble() ?? 0,
        activeClientCount:
            (profile['active_client_count'] as num?)?.toInt() ?? 0,
        remoteOnly: profile['remote_only'] as bool? ?? false,
        limitedSpots: profile['limited_spots'] as bool? ?? false,
        testimonials: _asList(profile['testimonials_json'])
            .map((dynamic item) => CoachTestimonialEntity.fromMap(_asMap(item)))
            .where((item) => item.quote.trim().isNotEmpty)
            .toList(growable: false),
        resultMedia: _asList(profile['result_media_json'])
            .map((dynamic item) => CoachResultMediaEntity.fromMap(_asMap(item)))
            .where((item) => item.storagePath.trim().isNotEmpty)
            .toList(growable: false),
        deliveryMode: profile['delivery_mode'] as String?,
        serviceSummary: profile['service_summary'] as String? ?? '',
        startingPackagePrice: publishedPackages.isEmpty
            ? null
            : publishedPackages.first.price,
        startingPackageBillingCycle: publishedPackages.isEmpty
            ? null
            : publishedPackages.first.billingCycle,
        activePackageCount: publishedPackages.length,
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
    String? city,
    List<String> languages = const <String>[],
    String? coachGender,
    int responseSlaHours = 12,
    bool trialOfferEnabled = true,
    double trialPriceEgp = 0,
    bool remoteOnly = false,
  }) async {
    final userId = _userId;
    try {
      await _client
          .from('coach_profiles')
          .upsert(
            <String, dynamic>{
              'user_id': userId,
              'bio': bio,
              'specialties': specialties,
              'years_experience': yearsExperience,
              'hourly_rate': hourlyRate,
              'delivery_mode': deliveryMode,
              'service_summary': serviceSummary,
              'city': city,
              'languages': languages.isEmpty
                  ? const <String>['arabic', 'english']
                  : languages,
              'coach_gender': coachGender,
              'response_sla_hours': responseSlaHours,
              'trial_offer_enabled': trialOfferEnabled,
              'trial_price_egp': trialPriceEgp,
              'remote_only': remoteOnly,
              'pricing_currency': 'EGP',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }..removeWhere((String key, dynamic value) => value == null),
          );
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
        query = query.eq('visibility_status', 'published');
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
    String subtitle = '',
    String outcomeSummary = '',
    List<String> idealFor = const <String>[],
    int durationWeeks = 4,
    int sessionsPerWeek = 3,
    String difficultyLevel = 'beginner',
    List<String> equipmentTags = const <String>[],
    List<String> includedFeatures = const <String>[],
    String checkInFrequency = '',
    String supportSummary = '',
    List<CoachPackageFaqEntity> faqItems = const <CoachPackageFaqEntity>[],
    Map<String, dynamic> planPreviewJson = const <String, dynamic>{},
    String? visibilityStatus,
    bool isActive = true,
    List<String> targetGoalTags = const <String>[],
    String locationMode = 'online',
    String deliveryMode = 'chat',
    String weeklyCheckinType = 'form',
    int trialDays = 7,
    double depositAmountEgp = 0,
    double renewalPriceEgp = 0,
    int maxSlots = 100,
    bool pauseAllowed = true,
    List<String> paymentRails = const <String>[],
  }) async {
    final resolvedVisibilityStatus = _normalizeVisibilityStatus(
      visibilityStatus,
      fallback: isActive ? 'published' : 'draft',
    );
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
              'subtitle': subtitle,
              'outcome_summary': outcomeSummary,
              'ideal_for': idealFor,
              'duration_weeks': durationWeeks,
              'sessions_per_week': sessionsPerWeek,
              'difficulty_level': difficultyLevel,
              'equipment_tags': equipmentTags,
              'included_features': includedFeatures,
              'check_in_frequency': checkInFrequency,
              'support_summary': supportSummary,
              'faq_json': faqItems.map((faq) => faq.toMap()).toList(),
              'plan_preview_json': planPreviewJson,
              'visibility_status': resolvedVisibilityStatus,
              'is_active': resolvedVisibilityStatus == 'published' && isActive,
              'target_goal_tags': targetGoalTags.isEmpty
                  ? const <String>['weight_loss']
                  : targetGoalTags,
              'location_mode': locationMode,
              'delivery_mode': deliveryMode,
              'weekly_checkin_type': weeklyCheckinType,
              'trial_days': trialDays,
              'deposit_amount_egp': depositAmountEgp,
              'renewal_price_egp': renewalPriceEgp,
              'max_slots': maxSlots,
              'pause_allowed': pauseAllowed,
              'payment_rails': paymentRails.isEmpty
                  ? const <String>['card', 'instapay', 'wallet']
                  : paymentRails,
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
          .update(<String, dynamic>{
            'is_active': false,
            'visibility_status': 'archived',
          })
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
            'id,member_id,coach_id,package_id,plan_name,billing_cycle,amount,status,checkout_status,payment_method,starts_at,ends_at,activated_at,cancelled_at,created_at,member_note,intake_snapshot_json,next_renewal_at,paused_at,cancel_at_period_end,payment_reference',
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
  Future<List<SubscriptionEntity>> listSubscriptionRequests() async {
    try {
      final subscriptions = await listSubscriptions();
      return subscriptions
          .where(
            (subscription) =>
                subscription.status == 'checkout_pending' ||
                subscription.status == 'pending_payment' ||
                subscription.status == 'pending_activation' ||
                subscription.checkoutStatus == 'checkout_pending',
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
  Future<SubscriptionEntity> requestSubscription({
    required String packageId,
    CoachSubscriptionIntakeEntity intakeSnapshot =
        const CoachSubscriptionIntakeEntity(),
    String? note,
    String paymentRail = 'instapay',
  }) async {
    try {
      final rows = await _client.rpc(
        'create_coach_checkout',
        params: <String, dynamic>{
          'target_package_id': packageId,
          'selected_payment_rail': paymentRail,
          'input_member_note': note,
          'input_intake_snapshot': intakeSnapshot.toMap(),
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
  Future<SubscriptionEntity> activateSubscriptionWithStarterPlan({
    required String subscriptionId,
    DateTime? startDate,
    String? reminderTime,
    String? note,
  }) async {
    try {
      final rows = await _client.rpc(
        'activate_coach_subscription_with_starter_plan',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'input_start_date': startDate == null
              ? null
              : DateTime.utc(
                  startDate.year,
                  startDate.month,
                  startDate.day,
                ).toIso8601String().split('T').first,
          'input_default_reminder_time': reminderTime,
          'note': note,
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
      city: row['city'] as String?,
      specialties: (row['specialties'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>(),
      languages: _asList(
        row['languages'],
      ).map((dynamic value) => value.toString()).toList(growable: false),
      coachGender: row['coach_gender'] as String?,
      hourlyRate: (row['hourly_rate'] as num?)?.toDouble() ?? 0,
      pricingCurrency: row['pricing_currency'] as String? ?? 'EGP',
      ratingAvg: (row['rating_avg'] as num?)?.toDouble() ?? 0,
      ratingCount: row['rating_count'] as int? ?? 0,
      isVerified: row['is_verified'] as bool? ?? false,
      verificationStatus: row['verification_status'] as String? ?? 'unverified',
      responseSlaHours: (row['response_sla_hours'] as num?)?.toInt() ?? 12,
      trialOfferEnabled: row['trial_offer_enabled'] as bool? ?? false,
      trialPriceEgp: (row['trial_price_egp'] as num?)?.toDouble() ?? 0,
      activeClientCount: (row['active_client_count'] as num?)?.toInt() ?? 0,
      remoteOnly: row['remote_only'] as bool? ?? false,
      startingPackagePrice: (row['starting_package_price'] as num?)?.toDouble(),
      startingPackageBillingCycle:
          row['starting_package_billing_cycle'] as String?,
      activePackageCount: row['active_package_count'] as int? ?? 0,
    );
  }

  CoachPackageEntity _mapPackage(Map<String, dynamic> row) {
    final faqItems = _asList(row['faq_json'])
        .map((dynamic item) => CoachPackageFaqEntity.fromMap(_asMap(item)))
        .toList(growable: false);
    final visibilityStatus = _normalizeVisibilityStatus(
      row['visibility_status'] as String?,
      fallback: (row['is_active'] as bool? ?? false) ? 'published' : 'draft',
    );
    return CoachPackageEntity(
      id: row['id'] as String,
      coachId: row['coach_id'] as String,
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      billingCycle: row['billing_cycle'] as String? ?? 'monthly',
      price: (row['price'] as num?)?.toDouble() ?? 0,
      subtitle: row['subtitle'] as String? ?? '',
      outcomeSummary: row['outcome_summary'] as String? ?? '',
      idealFor: (row['ideal_for'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>(),
      durationWeeks: row['duration_weeks'] as int? ?? 4,
      sessionsPerWeek: row['sessions_per_week'] as int? ?? 3,
      difficultyLevel: row['difficulty_level'] as String? ?? 'beginner',
      equipmentTags:
          (row['equipment_tags'] as List<dynamic>? ?? const <dynamic>[])
              .cast<String>(),
      includedFeatures:
          (row['included_features'] as List<dynamic>? ?? const <dynamic>[])
              .cast<String>(),
      checkInFrequency: row['check_in_frequency'] as String? ?? '',
      supportSummary: row['support_summary'] as String? ?? '',
      faqItems: faqItems,
      planPreviewJson: _asMap(row['plan_preview_json']),
      visibilityStatus: visibilityStatus,
      isActive: visibilityStatus == 'published',
      createdAt: _parseDate(row['created_at']),
      targetGoalTags: _asList(
        row['target_goal_tags'],
      ).map((dynamic item) => item.toString()).toList(growable: false),
      locationMode: row['location_mode'] as String? ?? 'online',
      deliveryMode: row['delivery_mode'] as String? ?? 'chat',
      weeklyCheckinType: row['weekly_checkin_type'] as String? ?? 'form',
      trialDays: (row['trial_days'] as num?)?.toInt() ?? 7,
      depositAmountEgp: (row['deposit_amount_egp'] as num?)?.toDouble() ?? 0,
      renewalPriceEgp: (row['renewal_price_egp'] as num?)?.toDouble() ?? 0,
      maxSlots: (row['max_slots'] as num?)?.toInt() ?? 100,
      pauseAllowed: row['pause_allowed'] as bool? ?? true,
      paymentRails: _asList(
        row['payment_rails'],
      ).map((dynamic item) => item.toString()).toList(growable: false),
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
      planJson: _asMap(row['plan_json']),
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
      packageTitle: normalizeHistoricalLabel(
        row['package_title'] ?? row['plan_name'],
        row['plan_name'] as String? ?? 'Subscription',
      ),
      memberName: row['member_name'] as String?,
      memberNote: row['member_note'] as String?,
      intakeSnapshot: CoachSubscriptionIntakeEntity.fromMap(
        _asMap(row['intake_snapshot_json']),
      ),
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

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
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

  String _normalizeVisibilityStatus(String? value, {required String fallback}) {
    switch (value?.trim().toLowerCase()) {
      case 'draft':
      case 'published':
      case 'archived':
        return value!.trim().toLowerCase();
      default:
        return fallback;
    }
  }
}
