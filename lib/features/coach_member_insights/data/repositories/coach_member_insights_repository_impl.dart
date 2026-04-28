import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/member_insight_entity.dart';
import '../../domain/entities/visibility_audit_entity.dart';
import '../../domain/entities/visibility_settings_entity.dart';
import '../../domain/repositories/coach_member_insights_repository.dart';

/// Supabase-backed implementation of [CoachMemberInsightsRepository].
///
/// All heavy lifting (aggregation, consent gating, audit) happens
/// server-side in RPCs — this layer simply calls and maps.
class CoachMemberInsightsRepositoryImpl
    implements CoachMemberInsightsRepository {
  CoachMemberInsightsRepositoryImpl(this._client);

  final SupabaseClient _client;

  // ── Coach reads ─────────────────────────────────────────────────────────

  @override
  Future<MemberInsightEntity?> getMemberInsight({
    required String memberId,
    required String subscriptionId,
  }) async {
    final response = await _client.rpc(
      'get_coach_member_insight',
      params: {
        'target_member_id': memberId,
        'target_subscription_id': subscriptionId,
      },
    );

    if (response == null) return null;

    final data = response as Map<String, dynamic>;
    return MemberInsightEntity.fromJson(data);
  }

  @override
  Future<List<InsightSummaryEntity>> listClientInsightSummaries() async {
    final response = await _client.rpc(
      'list_coach_member_insight_summaries',
    );

    if (response == null) return const <InsightSummaryEntity>[];

    final list = response as List<dynamic>;
    return list
        .map((e) =>
            InsightSummaryEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Member consent management ───────────────────────────────────────────

  @override
  Future<VisibilitySettingsEntity?> getVisibilitySettings({
    required String subscriptionId,
  }) async {
    final response = await _client.rpc(
      'get_member_visibility_settings',
      params: {'target_subscription_id': subscriptionId},
    );

    if (response == null) return null;

    final list = response as List<dynamic>;
    if (list.isEmpty) return null;

    return VisibilitySettingsEntity.fromJson(
      list.first as Map<String, dynamic>,
    );
  }

  @override
  Future<VisibilitySettingsEntity> upsertVisibilitySettings({
    required String subscriptionId,
    required String coachId,
    required bool shareAiPlanSummary,
    required bool shareWorkoutAdherence,
    required bool shareProgressMetrics,
    required bool shareNutritionSummary,
    required bool shareProductRecommendations,
    required bool shareRelevantPurchases,
  }) async {
    final response = await _client.rpc(
      'upsert_coach_member_visibility',
      params: {
        'target_subscription_id': subscriptionId,
        'target_coach_id': coachId,
        'input_share_ai_plan_summary': shareAiPlanSummary,
        'input_share_workout_adherence': shareWorkoutAdherence,
        'input_share_progress_metrics': shareProgressMetrics,
        'input_share_nutrition_summary': shareNutritionSummary,
        'input_share_product_recommendations': shareProductRecommendations,
        'input_share_relevant_purchases': shareRelevantPurchases,
      },
    );

    final data = response as Map<String, dynamic>;
    return VisibilitySettingsEntity.fromJson(data);
  }

  @override
  Future<List<VisibilityAuditEntity>> listVisibilityAudit({
    required String subscriptionId,
  }) async {
    final response = await _client.rpc(
      'list_visibility_audit',
      params: {'target_subscription_id': subscriptionId},
    );

    if (response == null) return const <VisibilityAuditEntity>[];

    final list = response as List<dynamic>;
    return list
        .map(
            (e) => VisibilityAuditEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
