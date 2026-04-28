/// Represents a member's granular consent settings for what data
/// their coach can view.
class VisibilitySettingsEntity {
  const VisibilitySettingsEntity({
    required this.id,
    required this.memberId,
    required this.coachId,
    required this.subscriptionId,
    this.shareAiPlanSummary = false,
    this.shareWorkoutAdherence = false,
    this.shareProgressMetrics = false,
    this.shareNutritionSummary = false,
    this.shareProductRecommendations = false,
    this.shareRelevantPurchases = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String memberId;
  final String coachId;
  final String subscriptionId;
  final bool shareAiPlanSummary;
  final bool shareWorkoutAdherence;
  final bool shareProgressMetrics;
  final bool shareNutritionSummary;
  final bool shareProductRecommendations;
  final bool shareRelevantPurchases;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// True if the member has granted at least one sharing toggle.
  bool get hasAnySharing =>
      shareAiPlanSummary ||
      shareWorkoutAdherence ||
      shareProgressMetrics ||
      shareNutritionSummary ||
      shareProductRecommendations ||
      shareRelevantPurchases;

  /// Returns a map suitable for the upsert RPC call.
  Map<String, dynamic> toRpcParams() => {
        'input_share_ai_plan_summary': shareAiPlanSummary,
        'input_share_workout_adherence': shareWorkoutAdherence,
        'input_share_progress_metrics': shareProgressMetrics,
        'input_share_nutrition_summary': shareNutritionSummary,
        'input_share_product_recommendations': shareProductRecommendations,
        'input_share_relevant_purchases': shareRelevantPurchases,
      };

  VisibilitySettingsEntity copyWith({
    bool? shareAiPlanSummary,
    bool? shareWorkoutAdherence,
    bool? shareProgressMetrics,
    bool? shareNutritionSummary,
    bool? shareProductRecommendations,
    bool? shareRelevantPurchases,
  }) =>
      VisibilitySettingsEntity(
        id: id,
        memberId: memberId,
        coachId: coachId,
        subscriptionId: subscriptionId,
        shareAiPlanSummary: shareAiPlanSummary ?? this.shareAiPlanSummary,
        shareWorkoutAdherence:
            shareWorkoutAdherence ?? this.shareWorkoutAdherence,
        shareProgressMetrics:
            shareProgressMetrics ?? this.shareProgressMetrics,
        shareNutritionSummary:
            shareNutritionSummary ?? this.shareNutritionSummary,
        shareProductRecommendations:
            shareProductRecommendations ?? this.shareProductRecommendations,
        shareRelevantPurchases:
            shareRelevantPurchases ?? this.shareRelevantPurchases,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory VisibilitySettingsEntity.fromJson(Map<String, dynamic> json) =>
      VisibilitySettingsEntity(
        id: json['id'] as String,
        memberId: json['member_id'] as String,
        coachId: json['coach_id'] as String,
        subscriptionId: json['subscription_id'] as String,
        shareAiPlanSummary: json['share_ai_plan_summary'] as bool? ?? false,
        shareWorkoutAdherence:
            json['share_workout_adherence'] as bool? ?? false,
        shareProgressMetrics:
            json['share_progress_metrics'] as bool? ?? false,
        shareNutritionSummary:
            json['share_nutrition_summary'] as bool? ?? false,
        shareProductRecommendations:
            json['share_product_recommendations'] as bool? ?? false,
        shareRelevantPurchases:
            json['share_relevant_purchases'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  /// Creates a default (all-off) entity for a brand-new subscription.
  factory VisibilitySettingsEntity.defaultFor({
    required String memberId,
    required String coachId,
    required String subscriptionId,
  }) =>
      VisibilitySettingsEntity(
        id: '',
        memberId: memberId,
        coachId: coachId,
        subscriptionId: subscriptionId,
      );
}
