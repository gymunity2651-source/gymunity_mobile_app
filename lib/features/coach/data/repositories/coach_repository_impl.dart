import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/paged.dart';
import '../../../../core/utils/historical_record_utils.dart';
import '../../../member/domain/entities/coaching_engagement_entity.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/entities/coach_taiyo_entity.dart';
import '../../domain/entities/coach_workspace_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/workout_plan_entity.dart';
import '../../domain/repositories/coach_repository.dart';

typedef SchemaCompatibleWriteOperation =
    Future<dynamic> Function(Map<String, dynamic> payload);

const List<String> _coachProfilePublicProfileColumns = <String>[
  'headline',
  'positioning_statement',
  'certifications_json',
  'trust_badges_json',
  'faq_json',
  'response_metrics_json',
];

const List<String> _coachProfileRoleFlowColumns = <String>[
  'delivery_mode',
  'service_summary',
  'pricing_currency',
];

const List<String> _coachProfileMarketplaceColumns = <String>[
  'city',
  'languages',
  'coach_gender',
  'response_sla_hours',
  'trial_offer_enabled',
  'trial_price_egp',
  'remote_only',
];

const String kTaiyoCoachClientBriefFunctionName = 'taiyo-coach-client-brief';

Future<void> runSchemaCompatibleWrite({
  required List<Map<String, dynamic>> payloads,
  required SchemaCompatibleWriteOperation operation,
}) async {
  for (var index = 0; index < payloads.length; index++) {
    try {
      await operation(payloads[index]);
      return;
    } on PostgrestException catch (error) {
      final canRetry =
          index < payloads.length - 1 && isMissingSchemaColumnError(error);
      if (!canRetry) {
        rethrow;
      }
    }
  }
}

bool isMissingSchemaColumnError(PostgrestException error) {
  final code = (error.code ?? '').trim().toUpperCase();
  if (code == '42703' || code == 'PGRST204') {
    return true;
  }

  final message = error.message.toLowerCase();
  return (message.contains('column') &&
          (message.contains('does not exist') ||
              message.contains('could not find') ||
              message.contains('schema cache'))) ||
      (message.contains('could not find') && message.contains('schema'));
}

List<Map<String, dynamic>> buildCoachProfilePayloadVariants({
  required Map<String, dynamic> fullPayload,
}) {
  final withoutPublicProfile = Map<String, dynamic>.from(fullPayload)
    ..removeWhere(
      (String key, dynamic _) =>
          _coachProfilePublicProfileColumns.contains(key),
    );
  final legacySafePayload = Map<String, dynamic>.from(withoutPublicProfile)
    ..removeWhere(
      (String key, dynamic _) =>
          _coachProfileRoleFlowColumns.contains(key) ||
          _coachProfileMarketplaceColumns.contains(key),
    );
  return <Map<String, dynamic>>[
    fullPayload,
    withoutPublicProfile,
    legacySafePayload,
  ];
}

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
      final rows = await _listCoachDirectoryRows(
        specialty: specialty,
        city: city,
        language: language,
        coachGender: coachGender,
        maxBudget: maxBudget,
        limit: limit,
      );

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
      final userProfile = await _fetchCoachUserProfile(coachId);
      final coachProfile = await _fetchCoachProfile(coachId);
      if (userProfile == null && coachProfile == null) {
        return null;
      }

      final packages = await listCoachPackages(coachId: coachId);
      final publishedPackages = packages
          .where((package) => package.isPublished || package.isActive)
          .toList();
      publishedPackages.sort((a, b) => a.price.compareTo(b.price));
      final availability = await _loadCoachAvailabilityForDetails(coachId);
      final reviews = await _loadCoachReviewsForDetails(coachId);
      final profile = coachProfile ?? const <String, dynamic>{};
      final user = userProfile ?? const <String, dynamic>{};
      // profiles RLS only allows reading own row, so for other coaches
      // we extract the name from the public profile RPC.
      String coachName = user['full_name'] as String? ?? '';
      if (coachName.isEmpty && profile['full_name'] != null) {
        coachName = profile['full_name'] as String;
      }
      if (coachName.isEmpty) {
        try {
          final publicRow = await _client.rpc(
            'get_coach_public_profile',
            params: <String, dynamic>{'target_coach_id': coachId},
          );
          if (publicRow is Map<String, dynamic>) {
            coachName = publicRow['full_name'] as String? ?? 'Coach';
          }
        } catch (_) {
          coachName = 'Coach';
        }
      }

      return CoachEntity(
        id: coachId,
        name: coachName,
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
        headline: profile['headline'] as String? ?? '',
        positioningStatement: profile['positioning_statement'] as String? ?? '',
        certifications: _asList(profile['certifications_json'])
            .map(
              (dynamic item) => CoachCertificationEntity.fromMap(_asMap(item)),
            )
            .where((item) => item.title.trim().isNotEmpty)
            .toList(growable: false),
        trustBadges: _asList(profile['trust_badges_json'])
            .map((dynamic item) => CoachTrustBadgeEntity.fromMap(_asMap(item)))
            .where((item) => item.label.trim().isNotEmpty)
            .toList(growable: false),
        faqItems: _asList(profile['faq_json'])
            .map((dynamic item) => CoachPackageFaqEntity.fromMap(_asMap(item)))
            .where((item) => item.question.trim().isNotEmpty)
            .toList(growable: false),
        responseMetrics: _asMap(profile['response_metrics_json']),
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
    } catch (e, st) {
      // Surface unexpected errors for debugging.
      debugPrint('[getCoachDetails] Unexpected error: $e');
      debugPrint('[getCoachDetails] Stack: $st');
      rethrow;
    }
  }

  Future<List<CoachAvailabilitySlotEntity>> _loadCoachAvailabilityForDetails(
    String coachId,
  ) async {
    try {
      return await listAvailability(coachId: coachId);
    } catch (error) {
      debugPrint('[getCoachDetails] Availability load failed: $error');
      return const <CoachAvailabilitySlotEntity>[];
    }
  }

  Future<List<CoachReviewEntity>> _loadCoachReviewsForDetails(
    String coachId,
  ) async {
    try {
      return await listCoachReviews(coachId);
    } catch (error) {
      debugPrint('[getCoachDetails] Reviews load failed: $error');
      return const <CoachReviewEntity>[];
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
    String headline = '',
    String positioningStatement = '',
  }) async {
    final userId = _userId;
    final fullPayload = _buildCoachProfilePayload(
      userId: userId,
      bio: bio,
      specialties: specialties,
      yearsExperience: yearsExperience,
      hourlyRate: hourlyRate,
      deliveryMode: deliveryMode,
      serviceSummary: serviceSummary,
      city: city,
      languages: languages,
      coachGender: coachGender,
      responseSlaHours: responseSlaHours,
      trialOfferEnabled: trialOfferEnabled,
      trialPriceEgp: trialPriceEgp,
      remoteOnly: remoteOnly,
      headline: headline,
      positioningStatement: positioningStatement,
    );
    try {
      await _runSchemaCompatibleWrite(
        payloads: buildCoachProfilePayloadVariants(fullPayload: fullPayload),
        operation: (payload) => _client.from('coach_profiles').upsert(payload),
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
    int weeklyCheckinsIncluded = 1,
    int feedbackSlaHours = 24,
    int initialPlanSlaHours = 48,
    bool workoutPlanIncluded = true,
    bool nutritionGuidanceIncluded = false,
    bool habitsIncluded = true,
    bool resourcesIncluded = true,
    bool sessionsIncluded = false,
    bool monthlyReviewIncluded = false,
    int sessionCountPerMonth = 0,
    String packageSummaryForMember = '',
  }) async {
    final resolvedVisibilityStatus = _normalizeVisibilityStatus(
      visibilityStatus,
      fallback: isActive ? 'published' : 'draft',
    );
    try {
      await _runSchemaCompatibleWrite(
        payloads: <Map<String, dynamic>>[
          _buildCoachPackagePayload(
            packageId: packageId,
            title: title,
            description: description,
            billingCycle: billingCycle,
            price: price,
            subtitle: subtitle,
            outcomeSummary: outcomeSummary,
            idealFor: idealFor,
            durationWeeks: durationWeeks,
            sessionsPerWeek: sessionsPerWeek,
            difficultyLevel: difficultyLevel,
            equipmentTags: equipmentTags,
            includedFeatures: includedFeatures,
            checkInFrequency: checkInFrequency,
            supportSummary: supportSummary,
            faqItems: faqItems,
            planPreviewJson: planPreviewJson,
            resolvedVisibilityStatus: resolvedVisibilityStatus,
            isActive: isActive,
            targetGoalTags: targetGoalTags,
            locationMode: locationMode,
            deliveryMode: deliveryMode,
            weeklyCheckinType: weeklyCheckinType,
            trialDays: trialDays,
            depositAmountEgp: depositAmountEgp,
            renewalPriceEgp: renewalPriceEgp,
            maxSlots: maxSlots,
            pauseAllowed: pauseAllowed,
            paymentRails: paymentRails,
            weeklyCheckinsIncluded: weeklyCheckinsIncluded,
            feedbackSlaHours: feedbackSlaHours,
            initialPlanSlaHours: initialPlanSlaHours,
            workoutPlanIncluded: workoutPlanIncluded,
            nutritionGuidanceIncluded: nutritionGuidanceIncluded,
            habitsIncluded: habitsIncluded,
            resourcesIncluded: resourcesIncluded,
            sessionsIncluded: sessionsIncluded,
            monthlyReviewIncluded: monthlyReviewIncluded,
            sessionCountPerMonth: sessionCountPerMonth,
            packageSummaryForMember: packageSummaryForMember,
          ),
          _buildCoachPackagePayload(
            packageId: packageId,
            title: title,
            description: description,
            billingCycle: billingCycle,
            price: price,
            subtitle: subtitle,
            outcomeSummary: outcomeSummary,
            idealFor: idealFor,
            durationWeeks: durationWeeks,
            sessionsPerWeek: sessionsPerWeek,
            difficultyLevel: difficultyLevel,
            equipmentTags: equipmentTags,
            includedFeatures: includedFeatures,
            checkInFrequency: checkInFrequency,
            supportSummary: supportSummary,
            faqItems: faqItems,
            planPreviewJson: planPreviewJson,
            resolvedVisibilityStatus: resolvedVisibilityStatus,
            isActive: isActive,
            includeEgyptMarketplaceFields: false,
          ),
          _buildCoachPackagePayload(
            packageId: packageId,
            title: title,
            description: description,
            billingCycle: billingCycle,
            price: price,
            resolvedVisibilityStatus: resolvedVisibilityStatus,
            isActive: isActive,
            includeCoachMarketplaceFields: false,
            includeEgyptMarketplaceFields: false,
          ),
        ],
        operation: (payload) => _client.from('coach_packages').upsert(payload),
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
  Future<CoachWorkspaceEntity> getWorkspaceSummary() async {
    try {
      final row = await _client.rpc('coach_workspace_summary');
      return CoachWorkspaceEntity.fromMap(_asMap(row));
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
  Future<List<CoachActionItemEntity>> listActionItems() async {
    try {
      final rows = await _client.rpc('list_coach_action_items');
      return _asRows(
        rows,
      ).map(CoachActionItemEntity.fromMap).toList(growable: false);
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
  Future<void> dismissAutomationEvent(String eventId) async {
    try {
      await _client.rpc(
        'dismiss_coach_action_item',
        params: <String, dynamic>{'target_event_id': eventId},
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
  Future<List<CoachClientPipelineEntry>> listClientPipeline(
    CoachClientPipelineFilter filter,
  ) async {
    try {
      final rows = await _client.rpc(
        'list_coach_client_pipeline',
        params: <String, dynamic>{'input_filters': filter.toMap()},
      );
      return _asRows(
        rows,
      ).map(CoachClientPipelineEntry.fromMap).toList(growable: false);
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
  Future<CoachClientWorkspaceEntity> getClientWorkspace(
    String subscriptionId,
  ) async {
    try {
      final row = await _client.rpc(
        'get_coach_client_workspace',
        params: <String, dynamic>{'target_subscription_id': subscriptionId},
      );
      return CoachClientWorkspaceEntity.fromMap(_asMap(row));
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
  Future<CoachTaiyoClientBriefEntity> requestTaiyoCoachClientBrief({
    required String clientId,
    required String subscriptionId,
    String requestType = 'coach_client_brief',
  }) async {
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthFailure(message: 'No authenticated coach found.');
    }

    try {
      final response = await _client.functions.invoke(
        kTaiyoCoachClientBriefFunctionName,
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        body: coachTaiyoClientBriefRequestBody(
          clientId: clientId,
          subscriptionId: subscriptionId,
          requestType: requestType,
        ),
      );
      return coachTaiyoClientBriefFromResponse(response.data);
    } on FunctionException catch (error, stackTrace) {
      if (error.status == 401) {
        throw AuthFailure(
          message: 'Please sign in again to use TAIYO coach copilot.',
          code: error.status.toString(),
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (error.status == 403) {
        throw AuthFailure(
          message: 'TAIYO coach copilot is available for coach accounts only.',
          code: error.status.toString(),
          cause: error,
          stackTrace: stackTrace,
        );
      }
      throw NetworkFailure(
        message: _coachFunctionErrorMessage(
          error,
          'TAIYO could not prepare this client brief right now.',
        ),
        code: error.status.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      if (error is AppFailure) {
        rethrow;
      }
      throw NetworkFailure(
        message: 'TAIYO could not prepare this client brief right now.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> saveClientRecord({
    required String subscriptionId,
    String? pipelineStage,
    String? internalStatus,
    String? riskStatus,
    List<String>? tags,
    String? coachNotes,
    String? preferredLanguage,
    DateTime? followUpAt,
  }) async {
    try {
      await _client.rpc(
        'upsert_coach_client_record',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'input_pipeline_stage': pipelineStage,
          'input_internal_status': internalStatus,
          'input_risk_status': riskStatus,
          'input_tags': tags,
          'input_coach_notes': coachNotes,
          'input_preferred_language': preferredLanguage,
          'input_follow_up_at': followUpAt?.toUtc().toIso8601String(),
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
  Future<CoachClientNoteEntity> addClientNote({
    required String subscriptionId,
    required String note,
    String noteType = 'general',
    bool isPinned = false,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    try {
      final row = await _client.rpc(
        'add_coach_client_note',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'input_note': note,
          'input_note_type': noteType,
          'input_is_pinned': isPinned,
          'input_metadata': metadata,
        },
      );
      return CoachClientNoteEntity.fromMap(_firstRowOrMap(row));
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
  Future<List<CoachThreadEntity>> listCoachThreads() async {
    try {
      final rows = await _client
          .from('coach_member_threads')
          .select()
          .eq('coach_id', _userId)
          .order('updated_at', ascending: false);
      return _asRows(
        rows,
      ).map(CoachThreadEntity.fromMap).toList(growable: false);
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
  Future<List<CoachMessageEntity>> listCoachMessages(String threadId) async {
    try {
      final rows = await _client
          .from('coach_messages')
          .select()
          .eq('thread_id', threadId)
          .order('created_at', ascending: true);
      return _asRows(
        rows,
      ).map(CoachMessageEntity.fromMap).toList(growable: false);
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
  Future<void> sendCoachMessage({
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
      await markThreadRead(threadId);
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
  Future<void> markThreadRead(String threadId) async {
    try {
      await _client.rpc(
        'mark_coach_thread_read',
        params: <String, dynamic>{'target_thread_id': threadId},
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
  Future<List<WeeklyCheckinEntity>> listCheckinInbox() async {
    try {
      final rows = await _client
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
          .eq('coach_id', _userId)
          .isFilter('coach_reply', null)
          .order('week_start', ascending: true);
      return _asRows(
        rows,
      ).map(WeeklyCheckinEntity.fromMap).toList(growable: false);
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
  Future<void> submitCheckinFeedback({
    required String checkinId,
    required String threadId,
    required String feedback,
    String whatWentWell = '',
    String whatNeedsAttention = '',
    String adjustmentForNextWeek = '',
    String onePriority = '',
    String coachNote = '',
    String planChangesSummary = '',
    DateTime? nextCheckinDate,
  }) async {
    try {
      final trimmed = feedback.trim();
      if (trimmed.isEmpty) {
        return;
      }
      await _client.rpc(
        'submit_coach_checkin_feedback',
        params: <String, dynamic>{
          'target_checkin_id': checkinId,
          'target_thread_id': threadId,
          'input_feedback': trimmed,
          'input_what_went_well': whatWentWell,
          'input_what_needs_attention': whatNeedsAttention,
          'input_adjustment_for_next_week': adjustmentForNextWeek,
          'input_one_priority': onePriority,
          'input_coach_note': coachNote,
          'input_plan_changes_summary': planChangesSummary,
          'input_next_checkin_date': nextCheckinDate == null
              ? null
              : DateTime.utc(
                  nextCheckinDate.year,
                  nextCheckinDate.month,
                  nextCheckinDate.day,
                ).toIso8601String().split('T').first,
        },
      );
      await markThreadRead(threadId);
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
  Future<List<CoachProgramTemplateEntity>> listProgramTemplates() async {
    try {
      final rows = await _client.rpc('list_coach_program_templates');
      return _asRows(
        rows,
      ).map(CoachProgramTemplateEntity.fromMap).toList(growable: false);
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
  Future<CoachProgramTemplateEntity> saveProgramTemplate({
    String? templateId,
    required String title,
    required String goalType,
    String description = '',
    int durationWeeks = 4,
    String difficultyLevel = 'beginner',
    String locationMode = 'online',
    List<dynamic> weeklyStructure = const <dynamic>[],
    List<String> tags = const <String>[],
  }) async {
    try {
      final row = await _client.rpc(
        'save_coach_program_template',
        params: <String, dynamic>{
          'input_template_id': templateId,
          'input_title': title,
          'input_goal_type': goalType,
          'input_description': description,
          'input_duration_weeks': durationWeeks,
          'input_difficulty_level': difficultyLevel,
          'input_location_mode': locationMode,
          'input_weekly_structure': weeklyStructure,
          'input_tags': tags,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      return CoachProgramTemplateEntity.fromMap(_firstRowOrMap(row));
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
  Future<void> assignProgramTemplate({
    required String subscriptionId,
    required String templateId,
    DateTime? startDate,
    String? defaultReminderTime,
  }) async {
    try {
      await _client.rpc(
        'assign_program_template_to_client',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'target_template_id': templateId,
          'input_start_date': startDate == null
              ? null
              : DateTime.utc(
                  startDate.year,
                  startDate.month,
                  startDate.day,
                ).toIso8601String().split('T').first,
          'input_default_reminder_time': defaultReminderTime,
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
  Future<List<CoachExerciseEntity>> listExercises() async {
    try {
      final rows = await _client.rpc('list_coach_exercises');
      return _asRows(
        rows,
      ).map(CoachExerciseEntity.fromMap).toList(growable: false);
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
  Future<CoachExerciseEntity> saveExercise({
    String? exerciseId,
    required String title,
    String category = 'strength',
    List<String> primaryMuscles = const <String>[],
    List<String> equipmentTags = const <String>[],
    String difficultyLevel = 'beginner',
    String instructions = '',
    String? videoUrl,
    List<dynamic> substitutions = const <dynamic>[],
    String progressionRule = '',
    String regressionRule = '',
    int? restGuidanceSeconds,
    List<dynamic> cues = const <dynamic>[],
  }) async {
    try {
      final row = await _client.rpc(
        'save_coach_exercise',
        params: <String, dynamic>{
          'input_exercise_id': exerciseId,
          'input_title': title,
          'input_category': category,
          'input_primary_muscles': primaryMuscles,
          'input_equipment_tags': equipmentTags,
          'input_difficulty_level': difficultyLevel,
          'input_instructions': instructions,
          'input_video_url': videoUrl,
          'input_substitutions': substitutions,
          'input_progression_rule': progressionRule,
          'input_regression_rule': regressionRule,
          'input_rest_guidance_seconds': restGuidanceSeconds,
          'input_cues': cues,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      return CoachExerciseEntity.fromMap(_firstRowOrMap(row));
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
  Future<List<CoachHabitAssignmentEntity>> assignHabits({
    required String subscriptionId,
    required List<Map<String, dynamic>> habits,
  }) async {
    try {
      final rows = await _client.rpc(
        'assign_client_habits',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'input_habits': habits,
        },
      );
      return _asRows(
        rows,
      ).map(CoachHabitAssignmentEntity.fromMap).toList(growable: false);
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
  Future<List<CoachOnboardingTemplateEntity>> listOnboardingTemplates() async {
    try {
      final rows = await _client.rpc('list_coach_onboarding_templates');
      return _asRows(
        rows,
      ).map(CoachOnboardingTemplateEntity.fromMap).toList(growable: false);
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
  Future<CoachOnboardingTemplateEntity> saveOnboardingTemplate({
    String? templateId,
    required String title,
    String clientType = 'general',
    String description = '',
    String welcomeMessage = '',
    Map<String, dynamic> intakeForm = const <String, dynamic>{},
    Map<String, dynamic> goalsQuestionnaire = const <String, dynamic>{},
    String? starterProgramTemplateId,
    List<dynamic> habitTemplates = const <dynamic>[],
    List<dynamic> nutritionTasks = const <dynamic>[],
    Map<String, dynamic> checkinSchedule = const <String, dynamic>{},
    List<String> resourceIds = const <String>[],
  }) async {
    try {
      final row = await _client.rpc(
        'save_coach_onboarding_template',
        params: <String, dynamic>{
          'input_template_id': templateId,
          'input_title': title,
          'input_client_type': clientType,
          'input_description': description,
          'input_welcome_message': welcomeMessage,
          'input_intake_form': intakeForm,
          'input_goals_questionnaire': goalsQuestionnaire,
          'input_starter_program_template_id': starterProgramTemplateId,
          'input_habit_templates': habitTemplates,
          'input_nutrition_tasks': nutritionTasks,
          'input_checkin_schedule': checkinSchedule,
          'input_resource_ids': resourceIds,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      return CoachOnboardingTemplateEntity.fromMap(_firstRowOrMap(row));
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
  Future<Map<String, dynamic>> applyOnboardingTemplate({
    required String subscriptionId,
    required String templateId,
  }) async {
    try {
      final row = await _client.rpc(
        'apply_coach_onboarding_flow',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'target_template_id': templateId,
        },
      );
      return _asMap(row);
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
  Future<List<CoachSessionTypeEntity>> listSessionTypes() async {
    try {
      final rows = await _client.rpc('list_coach_session_types');
      return _asRows(
        rows,
      ).map(CoachSessionTypeEntity.fromMap).toList(growable: false);
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
  Future<CoachSessionTypeEntity> saveSessionType({
    String? sessionTypeId,
    required String title,
    String sessionKind = 'consultation',
    int durationMinutes = 45,
    int bufferBeforeMinutes = 0,
    int bufferAfterMinutes = 10,
    String deliveryMode = 'online',
    String? locationNote,
    int cancellationNoticeHours = 12,
    int rescheduleNoticeHours = 12,
    bool isSelfBookable = true,
  }) async {
    try {
      final row = await _client.rpc(
        'save_coach_session_type',
        params: <String, dynamic>{
          'input_session_type_id': sessionTypeId,
          'input_title': title,
          'input_session_kind': sessionKind,
          'input_duration_minutes': durationMinutes,
          'input_buffer_before_minutes': bufferBeforeMinutes,
          'input_buffer_after_minutes': bufferAfterMinutes,
          'input_delivery_mode': deliveryMode,
          'input_location_note': locationNote,
          'input_cancellation_notice_hours': cancellationNoticeHours,
          'input_reschedule_notice_hours': rescheduleNoticeHours,
          'input_is_self_bookable': isSelfBookable,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      return CoachSessionTypeEntity.fromMap(_firstRowOrMap(row));
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
  Future<List<CoachBookingEntity>> listBookings({
    DateTime? from,
    DateTime? to,
    String? subscriptionId,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_coach_bookings',
        params: <String, dynamic>{
          'input_date_from': from?.toUtc().toIso8601String(),
          'input_date_to': to?.toUtc().toIso8601String(),
          'target_subscription_id': subscriptionId,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      return _asRows(
        rows,
      ).map(CoachBookingEntity.fromMap).toList(growable: false);
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
  Future<CoachBookingEntity> createBooking({
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
  Future<CoachBookingEntity> updateBookingStatus({
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

  @override
  Future<List<CoachPaymentReceiptEntity>> listPaymentQueue() async {
    try {
      final rows = await _client.rpc('list_coach_payment_queue');
      return _asRows(
        rows,
      ).map(CoachPaymentReceiptEntity.fromMap).toList(growable: false);
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
  Future<CoachPaymentReceiptEntity> verifyPayment({
    required String receiptId,
    String? note,
  }) async {
    try {
      final row = await _client.rpc(
        'verify_coach_payment',
        params: <String, dynamic>{
          'target_receipt_id': receiptId,
          'input_note': note,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      return CoachPaymentReceiptEntity.fromMap(_firstRowOrMap(row));
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
  Future<CoachPaymentReceiptEntity> failPayment({
    required String receiptId,
    required String reason,
  }) async {
    try {
      final row = await _client.rpc(
        'fail_coach_payment',
        params: <String, dynamic>{
          'target_receipt_id': receiptId,
          'input_reason': reason,
        },
      );
      return CoachPaymentReceiptEntity.fromMap(_firstRowOrMap(row));
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
  Future<List<CoachPaymentAuditEntity>> listPaymentAuditTrail(
    String subscriptionId,
  ) async {
    try {
      final rows = await _client.rpc(
        'list_coach_payment_audit',
        params: <String, dynamic>{'target_subscription_id': subscriptionId},
      );
      return _asRows(
        rows,
      ).map(CoachPaymentAuditEntity.fromMap).toList(growable: false);
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
  Future<String> uploadCoachResource({
    required List<int> bytes,
    required String fileName,
  }) async {
    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$_userId/${DateTime.now().toUtc().microsecondsSinceEpoch}_$safeFileName';
    try {
      await _client.storage
          .from('coach-resources')
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
  Future<List<CoachResourceEntity>> listCoachResources() async {
    try {
      final rows = await _client.rpc('list_coach_resources');
      return _asRows(
        rows,
      ).map(CoachResourceEntity.fromMap).toList(growable: false);
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
  Future<CoachResourceEntity> saveCoachResource({
    String? resourceId,
    required String title,
    String description = '',
    String resourceType = 'file',
    String? storagePath,
    String? externalUrl,
    List<String> tags = const <String>[],
  }) async {
    try {
      final row = await _client.rpc(
        'save_coach_resource',
        params: <String, dynamic>{
          'input_resource_id': resourceId,
          'input_title': title,
          'input_description': description,
          'input_resource_type': resourceType,
          'input_storage_path': storagePath,
          'input_external_url': externalUrl,
          'input_tags': tags,
        }..removeWhere((String key, dynamic value) => value == null),
      );
      return CoachResourceEntity.fromMap(_firstRowOrMap(row));
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
  Future<void> assignResourceToClient({
    required String subscriptionId,
    required String resourceId,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'assign_resource_to_client',
        params: <String, dynamic>{
          'target_subscription_id': subscriptionId,
          'target_resource_id': resourceId,
          'input_note': note,
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
            'id,member_id,coach_id,package_id,plan_name,billing_cycle,amount,status,checkout_status,payment_method,payment_gateway,payment_order_id,amount_cents,currency,platform_fee_cents,coach_net_cents,starts_at,ends_at,activated_at,cancelled_at,created_at,member_note,intake_snapshot_json,next_renewal_at,paused_at,cancel_at_period_end,payment_reference',
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
      headline: row['headline'] as String? ?? '',
      positioningStatement: row['positioning_statement'] as String? ?? '',
      certifications: _asList(row['certifications_json'])
          .map((dynamic item) => CoachCertificationEntity.fromMap(_asMap(item)))
          .where((item) => item.title.trim().isNotEmpty)
          .toList(growable: false),
      trustBadges: _asList(row['trust_badges_json'])
          .map((dynamic item) => CoachTrustBadgeEntity.fromMap(_asMap(item)))
          .where((item) => item.label.trim().isNotEmpty)
          .toList(growable: false),
      faqItems: _asList(row['faq_json'])
          .map((dynamic item) => CoachPackageFaqEntity.fromMap(_asMap(item)))
          .where((item) => item.question.trim().isNotEmpty)
          .toList(growable: false),
      responseMetrics: _asMap(row['response_metrics_json']),
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
      weeklyCheckinsIncluded:
          (row['weekly_checkins_included'] as num?)?.toInt() ?? 1,
      feedbackSlaHours: (row['feedback_sla_hours'] as num?)?.toInt() ?? 24,
      initialPlanSlaHours:
          (row['initial_plan_sla_hours'] as num?)?.toInt() ?? 48,
      workoutPlanIncluded: row['workout_plan_included'] as bool? ?? true,
      nutritionGuidanceIncluded:
          row['nutrition_guidance_included'] as bool? ?? false,
      habitsIncluded: row['habits_included'] as bool? ?? true,
      resourcesIncluded: row['resources_included'] as bool? ?? true,
      sessionsIncluded: row['sessions_included'] as bool? ?? false,
      monthlyReviewIncluded: row['monthly_review_included'] as bool? ?? false,
      sessionCountPerMonth:
          (row['session_count_per_month'] as num?)?.toInt() ?? 0,
      packageSummaryForMember:
          row['package_summary_for_member'] as String? ?? '',
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

  Map<String, dynamic> _firstRowOrMap(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return _asMap(value.first);
    }
    return _asMap(value);
  }

  List<Map<String, dynamic>> _asRows(dynamic value) {
    if (value is List) {
      return value.map((dynamic row) => _asMap(row)).toList(growable: false);
    }
    if (value == null) {
      return const <Map<String, dynamic>>[];
    }
    return <Map<String, dynamic>>[_asMap(value)];
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

  Map<String, dynamic> _buildCoachProfilePayload({
    required String userId,
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
    String headline = '',
    String positioningStatement = '',
    bool includeRoleFlowFields = true,
    bool includeMarketplaceFields = true,
  }) {
    final payload = <String, dynamic>{
      'user_id': userId,
      'bio': bio,
      'specialties': specialties,
      'headline': headline,
      'positioning_statement': positioningStatement,
      'years_experience': yearsExperience,
      'hourly_rate': hourlyRate,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (includeRoleFlowFields) {
      payload.addAll(<String, dynamic>{
        'delivery_mode': deliveryMode,
        'service_summary': serviceSummary,
        'pricing_currency': 'EGP',
      });
    }

    if (includeMarketplaceFields) {
      payload.addAll(<String, dynamic>{
        'city': city,
        'languages': languages.isEmpty
            ? const <String>['arabic', 'english']
            : languages,
        'coach_gender': coachGender,
        'response_sla_hours': responseSlaHours,
        'trial_offer_enabled': trialOfferEnabled,
        'trial_price_egp': trialPriceEgp,
        'remote_only': remoteOnly,
      });
    }

    payload.removeWhere((String key, dynamic value) => value == null);
    return payload;
  }

  Map<String, dynamic> _buildCoachPackagePayload({
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
    required String resolvedVisibilityStatus,
    required bool isActive,
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
    int weeklyCheckinsIncluded = 1,
    int feedbackSlaHours = 24,
    int initialPlanSlaHours = 48,
    bool workoutPlanIncluded = true,
    bool nutritionGuidanceIncluded = false,
    bool habitsIncluded = true,
    bool resourcesIncluded = true,
    bool sessionsIncluded = false,
    bool monthlyReviewIncluded = false,
    int sessionCountPerMonth = 0,
    String packageSummaryForMember = '',
    bool includeCoachMarketplaceFields = true,
    bool includeEgyptMarketplaceFields = true,
  }) {
    final payload = <String, dynamic>{
      'id': packageId,
      'coach_id': _userId,
      'title': title,
      'description': description,
      'billing_cycle': billingCycle,
      'price': price,
      'is_active': resolvedVisibilityStatus == 'published' && isActive,
    };

    if (includeCoachMarketplaceFields) {
      payload.addAll(<String, dynamic>{
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
        'weekly_checkins_included': weeklyCheckinsIncluded,
        'feedback_sla_hours': feedbackSlaHours,
        'initial_plan_sla_hours': initialPlanSlaHours,
        'workout_plan_included': workoutPlanIncluded,
        'nutrition_guidance_included': nutritionGuidanceIncluded,
        'habits_included': habitsIncluded,
        'resources_included': resourcesIncluded,
        'sessions_included': sessionsIncluded,
        'monthly_review_included': monthlyReviewIncluded,
        'session_count_per_month': sessionCountPerMonth,
        'package_summary_for_member': packageSummaryForMember,
      });
    }

    if (includeEgyptMarketplaceFields) {
      payload.addAll(<String, dynamic>{
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
      });
    }

    payload.removeWhere((String key, dynamic value) => value == null);
    return payload;
  }

  Future<void> _runSchemaCompatibleWrite({
    required List<Map<String, dynamic>> payloads,
    required Future<dynamic> Function(Map<String, dynamic> payload) operation,
  }) async {
    await runSchemaCompatibleWrite(payloads: payloads, operation: operation);
  }

  Future<List<dynamic>> _listCoachDirectoryRows({
    String? specialty,
    String? city,
    String? language,
    String? coachGender,
    double? maxBudget,
    required int limit,
  }) async {
    try {
      return await _client.rpc(
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
    } on PostgrestException catch (error) {
      if (!isMissingSchemaColumnError(error)) {
        rethrow;
      }
      return await _client.rpc(
            'list_coach_directory',
            params: <String, dynamic>{
              'specialty_filter': specialty,
              'limit_count': limit,
            }..removeWhere((String key, dynamic value) => value == null),
          )
          as List<dynamic>;
    }
  }

  Future<Map<String, dynamic>?> _fetchCoachUserProfile(String coachId) async {
    return await _client
        .from('profiles')
        .select('full_name, avatar_path')
        .eq('user_id', coachId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> _fetchCoachProfile(String coachId) async {
    try {
      final direct = await _client
          .from('coach_profiles')
          .select()
          .eq('user_id', coachId)
          .maybeSingle();
      if (direct != null) {
        return direct;
      }
    } on PostgrestException catch (error) {
      if (!isMissingSchemaColumnError(error)) {
        rethrow;
      }
    }
    // Fallback: RLS may hide the row from non-owner users.
    final rows = await _client.rpc(
      'get_coach_public_profile',
      params: <String, dynamic>{'target_coach_id': coachId},
    );
    final list = _asRows(rows);
    return list.isEmpty ? null : list.first;
  }
}

Map<String, dynamic> coachTaiyoClientBriefRequestBody({
  required String clientId,
  required String subscriptionId,
  required String requestType,
}) {
  return <String, dynamic>{
    'request_type': requestType,
    'client_id': clientId,
    'subscription_id': subscriptionId,
  };
}

CoachTaiyoClientBriefEntity coachTaiyoClientBriefFromResponse(dynamic value) {
  final map = _coachResponseMap(value);
  if (map.isEmpty) {
    throw const NetworkFailure(
      message: 'TAIYO returned an empty coach client brief response.',
    );
  }
  return CoachTaiyoClientBriefEntity.fromMap(map);
}

String _coachFunctionErrorMessage(FunctionException error, String fallback) {
  final details = _coachResponseMap(error.details);
  return details['message']?.toString() ??
      details['error']?.toString() ??
      error.details?.toString() ??
      fallback;
}

Map<String, dynamic> _coachResponseMap(dynamic value) {
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
