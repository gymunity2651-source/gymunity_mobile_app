import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/member_insight_entity.dart';
import '../../domain/entities/visibility_audit_entity.dart';
import '../../domain/entities/visibility_settings_entity.dart';

// ── Coach-side providers ─────────────────────────────────────────────────

/// Provides the lightweight summary for all active coaching clients.
final coachClientInsightSummariesProvider =
    FutureProvider<List<InsightSummaryEntity>>((ref) {
  final repo = ref.watch(coachMemberInsightsRepositoryProvider);
  return repo.listClientInsightSummaries();
});

/// Route-level arguments for the insight detail screen.
class InsightDetailArgs {
  const InsightDetailArgs({
    required this.memberId,
    required this.subscriptionId,
    required this.memberName,
  });

  final String memberId;
  final String subscriptionId;
  final String memberName;
}

/// Provides the full consent-gated insight for a single member.
final coachMemberInsightProvider = FutureProvider.family<MemberInsightEntity?,
    InsightDetailArgs>((ref, args) {
  final repo = ref.watch(coachMemberInsightsRepositoryProvider);
  return repo.getMemberInsight(
    memberId: args.memberId,
    subscriptionId: args.subscriptionId,
  );
});

// ── Member-side providers ────────────────────────────────────────────────

/// Route-level arguments for the member visibility settings screen.
class VisibilitySettingsArgs {
  const VisibilitySettingsArgs({
    required this.subscriptionId,
    required this.coachId,
    required this.coachName,
  });

  final String subscriptionId;
  final String coachId;
  final String coachName;
}

/// Provides the current visibility settings for a specific subscription.
final memberVisibilitySettingsProvider =
    FutureProvider.family<VisibilitySettingsEntity?, String>(
        (ref, subscriptionId) {
  final repo = ref.watch(coachMemberInsightsRepositoryProvider);
  return repo.getVisibilitySettings(subscriptionId: subscriptionId);
});

/// Provides the audit trail for a subscription's consent history.
final memberVisibilityAuditProvider =
    FutureProvider.family<List<VisibilityAuditEntity>, String>(
        (ref, subscriptionId) {
  final repo = ref.watch(coachMemberInsightsRepositoryProvider);
  return repo.listVisibilityAudit(subscriptionId: subscriptionId);
});
