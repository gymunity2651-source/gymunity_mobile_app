import '../../../planner/domain/entities/planner_entities.dart';

class PlannerTurnResult {
  const PlannerTurnResult({
    required this.assistantMessage,
    required this.status,
    this.assistantMessageId,
    this.draftId,
    this.missingFields = const <String>[],
    this.extractedProfile = const PlannerProfileSnapshotEntity(),
    this.plan,
    this.conversationMode,
    this.personalizationUsed = const <String>[],
    this.suggestedReplies = const <String>[],
  });

  final String assistantMessage;
  final String status;
  final String? assistantMessageId;
  final String? draftId;
  final List<String> missingFields;
  final PlannerProfileSnapshotEntity extractedProfile;
  final GeneratedPlanEntity? plan;
  final String? conversationMode;
  final List<String> personalizationUsed;
  final List<String> suggestedReplies;

  bool get isPlanReady => status == 'plan_ready' || status == 'plan_updated';

  factory PlannerTurnResult.fromMap(Map<String, dynamic> map) {
    final extractedProfileRaw = map['extracted_profile'];
    final planRaw = map['plan'];
    return PlannerTurnResult(
      assistantMessage: map['assistant_message'] as String? ?? '',
      status: map['status'] as String? ?? 'general_response',
      assistantMessageId: map['assistant_message_id'] as String?,
      draftId: map['draft_id'] as String?,
      missingFields: map['missing_fields'] is List
          ? (map['missing_fields'] as List)
                .map((dynamic item) => item.toString())
                .toList(growable: false)
          : const <String>[],
      extractedProfile: PlannerProfileSnapshotEntity.fromMap(
        extractedProfileRaw is Map<String, dynamic>
            ? extractedProfileRaw
            : extractedProfileRaw is Map
            ? extractedProfileRaw.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              )
            : null,
      ),
      plan: planRaw is Map<String, dynamic>
          ? GeneratedPlanEntity.fromMap(planRaw)
          : planRaw is Map
          ? GeneratedPlanEntity.fromMap(
              planRaw.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
      conversationMode: map['conversation_mode'] as String?,
      personalizationUsed: map['personalization_used'] is List
          ? (map['personalization_used'] as List)
                .map((dynamic item) => item.toString())
                .toList(growable: false)
          : const <String>[],
      suggestedReplies: map['suggested_replies'] is List
          ? (map['suggested_replies'] as List)
                .map((dynamic item) => item.toString())
                .toList(growable: false)
          : const <String>[],
    );
  }
}
