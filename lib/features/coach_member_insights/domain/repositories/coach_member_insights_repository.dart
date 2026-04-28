import '../entities/member_insight_entity.dart';
import '../entities/visibility_audit_entity.dart';
import '../entities/visibility_settings_entity.dart';

/// Contract for coach-member insight operations.
///
/// Coach-side methods return consent-gated aggregated data.
/// Member-side methods manage consent toggles and audit history.
abstract class CoachMemberInsightsRepository {
  // ── Coach reads ─────────────────────────────────────────────────────────

  /// Fetches a single member's full insight snapshot, consent-gated.
  /// Returns `null` if the subscription is not active or not found.
  Future<MemberInsightEntity?> getMemberInsight({
    required String memberId,
    required String subscriptionId,
  });

  /// Returns a lightweight insight summary for every active client.
  Future<List<InsightSummaryEntity>> listClientInsightSummaries();

  // ── Member consent management ───────────────────────────────────────────

  /// Fetches the current visibility settings for a subscription.
  /// Returns `null` if the member has never configured settings yet.
  Future<VisibilitySettingsEntity?> getVisibilitySettings({
    required String subscriptionId,
  });

  /// Creates or updates consent toggles. An immutable audit entry is
  /// written server-side on every call.
  Future<VisibilitySettingsEntity> upsertVisibilitySettings({
    required String subscriptionId,
    required String coachId,
    required bool shareAiPlanSummary,
    required bool shareWorkoutAdherence,
    required bool shareProgressMetrics,
    required bool shareNutritionSummary,
    required bool shareProductRecommendations,
    required bool shareRelevantPurchases,
  });

  /// Returns the consent change audit trail for a subscription.
  Future<List<VisibilityAuditEntity>> listVisibilityAudit({
    required String subscriptionId,
  });
}
