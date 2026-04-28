/// Aggregated insight for a single member, returned by the
/// `get_coach_member_insight` RPC. Each sub-section is null when the
/// member has not consented to share that data category.
class MemberInsightEntity {
  const MemberInsightEntity({
    required this.memberId,
    required this.memberName,
    this.memberAvatarPath,
    this.currentGoal,
    required this.subscriptionStatus,
    this.packageTitle,
    this.lastActiveAt,
    this.planInsight,
    this.adherenceInsight,
    this.progressInsight,
    this.nutritionInsight,
    this.productInsight,
    this.riskFlags = const <String>[],
  });

  // ── Header (always visible) ─────────────────────────────────────────────
  final String memberId;
  final String memberName;
  final String? memberAvatarPath;
  final String? currentGoal;
  final String subscriptionStatus;
  final String? packageTitle;
  final DateTime? lastActiveAt;

  // ── Consent-gated sections ──────────────────────────────────────────────
  final PlanInsightEntity? planInsight;
  final AdherenceInsightEntity? adherenceInsight;
  final ProgressInsightEntity? progressInsight;
  final NutritionInsightEntity? nutritionInsight;
  final ProductInsightEntity? productInsight;

  // ── Coaching signals ────────────────────────────────────────────────────
  final List<String> riskFlags;

  bool get hasLowAdherence => riskFlags.contains('low_adherence');
  bool get hasManyMissedSessions => riskFlags.contains('many_missed_sessions');
  bool get hasNoRecentCheckin => riskFlags.contains('no_recent_checkin');
  bool get hasAnyRisk => riskFlags.isNotEmpty;

  factory MemberInsightEntity.fromJson(Map<String, dynamic> json) =>
      MemberInsightEntity(
        memberId: json['member_id'] as String,
        memberName: json['member_name'] as String? ?? 'Member',
        memberAvatarPath: json['member_avatar_path'] as String?,
        currentGoal: json['current_goal'] as String?,
        subscriptionStatus: json['subscription_status'] as String? ?? 'active',
        packageTitle: json['package_title'] as String?,
        lastActiveAt: json['last_active_at'] != null
            ? DateTime.tryParse(json['last_active_at'] as String)
            : null,
        planInsight: json['plan_insight'] != null &&
                json['plan_insight'] is Map<String, dynamic>
            ? PlanInsightEntity.fromJson(
                json['plan_insight'] as Map<String, dynamic>)
            : null,
        adherenceInsight: json['adherence_insight'] != null &&
                json['adherence_insight'] is Map<String, dynamic>
            ? AdherenceInsightEntity.fromJson(
                json['adherence_insight'] as Map<String, dynamic>)
            : null,
        progressInsight: json['progress_insight'] != null &&
                json['progress_insight'] is Map<String, dynamic>
            ? ProgressInsightEntity.fromJson(
                json['progress_insight'] as Map<String, dynamic>)
            : null,
        nutritionInsight: json['nutrition_insight'] != null &&
                json['nutrition_insight'] is Map<String, dynamic>
            ? NutritionInsightEntity.fromJson(
                json['nutrition_insight'] as Map<String, dynamic>)
            : null,
        productInsight: json['product_insight'] != null &&
                json['product_insight'] is Map<String, dynamic>
            ? ProductInsightEntity.fromJson(
                json['product_insight'] as Map<String, dynamic>)
            : null,
        riskFlags: (json['risk_flags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const <String>[],
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class PlanInsightEntity {
  const PlanInsightEntity({
    this.planId,
    this.planTitle,
    this.planSource,
    this.planStatus,
    this.startDate,
    this.endDate,
    this.planVersion,
    this.durationWeeks,
    this.level,
    this.summary,
    this.totalDays = 0,
    this.totalTasks = 0,
  });

  final String? planId;
  final String? planTitle;
  final String? planSource;
  final String? planStatus;
  final String? startDate;
  final String? endDate;
  final int? planVersion;
  final int? durationWeeks;
  final String? level;
  final String? summary;
  final int totalDays;
  final int totalTasks;

  factory PlanInsightEntity.fromJson(Map<String, dynamic> json) =>
      PlanInsightEntity(
        planId: json['plan_id'] as String?,
        planTitle: json['plan_title'] as String?,
        planSource: json['plan_source'] as String?,
        planStatus: json['plan_status'] as String?,
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        planVersion: (json['plan_version'] as num?)?.toInt(),
        durationWeeks: (json['duration_weeks'] as num?)?.toInt(),
        level: json['level'] as String?,
        summary: json['summary'] as String?,
        totalDays: (json['total_days'] as num?)?.toInt() ?? 0,
        totalTasks: (json['total_tasks'] as num?)?.toInt() ?? 0,
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AdherenceInsightEntity {
  const AdherenceInsightEntity({
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.partialTasks = 0,
    this.skippedTasks = 0,
    this.missedTasks = 0,
    this.completionRate = 0,
    this.streakDays = 0,
    this.lastCompletedAt,
  });

  final int totalTasks;
  final int completedTasks;
  final int partialTasks;
  final int skippedTasks;
  final int missedTasks;
  final double completionRate;
  final int streakDays;
  final DateTime? lastCompletedAt;

  factory AdherenceInsightEntity.fromJson(Map<String, dynamic> json) =>
      AdherenceInsightEntity(
        totalTasks: (json['total_tasks'] as num?)?.toInt() ?? 0,
        completedTasks: (json['completed_tasks'] as num?)?.toInt() ?? 0,
        partialTasks: (json['partial_tasks'] as num?)?.toInt() ?? 0,
        skippedTasks: (json['skipped_tasks'] as num?)?.toInt() ?? 0,
        missedTasks: (json['missed_tasks'] as num?)?.toInt() ?? 0,
        completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0,
        streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
        lastCompletedAt: json['last_completed_at'] != null
            ? DateTime.tryParse(json['last_completed_at'] as String)
            : null,
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ProgressInsightEntity {
  const ProgressInsightEntity({
    this.latestWeight,
    this.latestWeightAt,
    this.weight4wAgo,
    this.weightTrend,
    this.latestMeasurement,
    this.lastCheckinAt,
    this.latestCheckinAdherence,
  });

  final double? latestWeight;
  final DateTime? latestWeightAt;
  final double? weight4wAgo;
  final String? weightTrend; // 'increasing', 'decreasing', 'stable', 'insufficient_data'
  final MeasurementSnapshot? latestMeasurement;
  final DateTime? lastCheckinAt;
  final int? latestCheckinAdherence;

  factory ProgressInsightEntity.fromJson(Map<String, dynamic> json) =>
      ProgressInsightEntity(
        latestWeight: (json['latest_weight'] as num?)?.toDouble(),
        latestWeightAt: json['latest_weight_at'] != null
            ? DateTime.tryParse(json['latest_weight_at'] as String)
            : null,
        weight4wAgo: (json['weight_4w_ago'] as num?)?.toDouble(),
        weightTrend: json['weight_trend'] as String?,
        latestMeasurement: json['latest_measurement'] != null &&
                json['latest_measurement'] is Map<String, dynamic>
            ? MeasurementSnapshot.fromJson(
                json['latest_measurement'] as Map<String, dynamic>)
            : null,
        lastCheckinAt: json['last_checkin_at'] != null
            ? DateTime.tryParse(json['last_checkin_at'] as String)
            : null,
        latestCheckinAdherence:
            (json['latest_checkin_adherence'] as num?)?.toInt(),
      );
}

class MeasurementSnapshot {
  const MeasurementSnapshot({
    this.waistCm,
    this.chestCm,
    this.armCm,
    this.bodyFatPercent,
    this.recordedAt,
  });

  final double? waistCm;
  final double? chestCm;
  final double? armCm;
  final double? bodyFatPercent;
  final DateTime? recordedAt;

  factory MeasurementSnapshot.fromJson(Map<String, dynamic> json) =>
      MeasurementSnapshot(
        waistCm: (json['waist_cm'] as num?)?.toDouble(),
        chestCm: (json['chest_cm'] as num?)?.toDouble(),
        armCm: (json['arm_cm'] as num?)?.toDouble(),
        bodyFatPercent: (json['body_fat_percent'] as num?)?.toDouble(),
        recordedAt: json['recorded_at'] != null
            ? DateTime.tryParse(json['recorded_at'] as String)
            : null,
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class NutritionInsightEntity {
  const NutritionInsightEntity({
    this.targetCalories,
    this.targetProteinG,
    this.targetCarbsG,
    this.targetFatsG,
    this.latestAdherenceScore,
    this.hasActiveMealPlan = false,
  });

  final int? targetCalories;
  final int? targetProteinG;
  final int? targetCarbsG;
  final int? targetFatsG;
  final int? latestAdherenceScore;
  final bool hasActiveMealPlan;

  factory NutritionInsightEntity.fromJson(Map<String, dynamic> json) =>
      NutritionInsightEntity(
        targetCalories: (json['target_calories'] as num?)?.toInt(),
        targetProteinG: (json['target_protein_g'] as num?)?.toInt(),
        targetCarbsG: (json['target_carbs_g'] as num?)?.toInt(),
        targetFatsG: (json['target_fats_g'] as num?)?.toInt(),
        latestAdherenceScore:
            (json['latest_adherence_score'] as num?)?.toInt(),
        hasActiveMealPlan: json['has_active_meal_plan'] as bool? ?? false,
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ProductInsightEntity {
  const ProductInsightEntity({
    this.recommendedProducts = const <RecommendedProductEntry>[],
    this.purchasedRelevant = const <PurchasedProductEntry>[],
  });

  final List<RecommendedProductEntry> recommendedProducts;
  final List<PurchasedProductEntry> purchasedRelevant;

  factory ProductInsightEntity.fromJson(Map<String, dynamic> json) =>
      ProductInsightEntity(
        recommendedProducts: (json['recommended_products'] as List<dynamic>?)
                ?.map((e) => RecommendedProductEntry.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const <RecommendedProductEntry>[],
        purchasedRelevant: (json['purchased_relevant'] as List<dynamic>?)
                ?.map((e) => PurchasedProductEntry.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const <PurchasedProductEntry>[],
      );
}

class RecommendedProductEntry {
  const RecommendedProductEntry({
    required this.productId,
    required this.productTitle,
    required this.context,
    required this.status,
    this.createdAt,
  });

  final String productId;
  final String productTitle;
  final String context;
  final String status;
  final DateTime? createdAt;

  factory RecommendedProductEntry.fromJson(Map<String, dynamic> json) =>
      RecommendedProductEntry(
        productId: json['product_id'] as String,
        productTitle: json['product_title'] as String? ?? 'Product',
        context: json['context'] as String? ?? 'general',
        status: json['status'] as String? ?? 'suggested',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

class PurchasedProductEntry {
  const PurchasedProductEntry({
    required this.productId,
    required this.productTitle,
    required this.quantity,
    this.purchasedAt,
  });

  final String productId;
  final String productTitle;
  final int quantity;
  final DateTime? purchasedAt;

  factory PurchasedProductEntry.fromJson(Map<String, dynamic> json) =>
      PurchasedProductEntry(
        productId: json['product_id'] as String,
        productTitle: json['product_title'] as String? ?? 'Product',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        purchasedAt: json['purchased_at'] != null
            ? DateTime.tryParse(json['purchased_at'] as String)
            : null,
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Lightweight summary entry used in the coach's client list view.
class InsightSummaryEntity {
  const InsightSummaryEntity({
    required this.subscriptionId,
    required this.memberId,
    required this.memberName,
    this.memberAvatarPath,
    this.currentGoal,
    this.packageTitle,
    required this.status,
    this.startedAt,
    this.hasVisibilitySettings = false,
    this.anyDataShared = false,
    this.completionRate,
    this.lastCheckinAt,
    this.riskFlags = const <String>[],
  });

  final String subscriptionId;
  final String memberId;
  final String memberName;
  final String? memberAvatarPath;
  final String? currentGoal;
  final String? packageTitle;
  final String status;
  final DateTime? startedAt;
  final bool hasVisibilitySettings;
  final bool anyDataShared;
  final double? completionRate;
  final DateTime? lastCheckinAt;
  final List<String> riskFlags;

  bool get hasAnyRisk => riskFlags.isNotEmpty;

  factory InsightSummaryEntity.fromJson(Map<String, dynamic> json) =>
      InsightSummaryEntity(
        subscriptionId: json['subscription_id'] as String,
        memberId: json['member_id'] as String,
        memberName: json['member_name'] as String? ?? 'Member',
        memberAvatarPath: json['member_avatar_path'] as String?,
        currentGoal: json['current_goal'] as String?,
        packageTitle: json['package_title'] as String?,
        status: json['status'] as String? ?? 'active',
        startedAt: json['started_at'] != null
            ? DateTime.tryParse(json['started_at'] as String)
            : null,
        hasVisibilitySettings:
            json['has_visibility_settings'] as bool? ?? false,
        anyDataShared: json['any_data_shared'] as bool? ?? false,
        completionRate: (json['completion_rate'] as num?)?.toDouble(),
        lastCheckinAt: json['last_checkin_at'] != null
            ? DateTime.tryParse(json['last_checkin_at'] as String)
            : null,
        riskFlags: (json['risk_flags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const <String>[],
      );
}
