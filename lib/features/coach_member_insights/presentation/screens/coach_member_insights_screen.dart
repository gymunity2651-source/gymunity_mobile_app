import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../domain/entities/member_insight_entity.dart';
import '../providers/insight_providers.dart';

/// Premium editorial dashboard showing a coach's aggregated view
/// of a single member's consented insights.
class CoachMemberInsightsScreen extends ConsumerWidget {
  const CoachMemberInsightsScreen({
    super.key,
    required this.args,
  });

  final InsightDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightAsync = ref.watch(coachMemberInsightProvider(args));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: insightAsync.when(
        loading: () => const _LoadingState(),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(coachMemberInsightProvider(args)),
        ),
        data: (insight) => insight == null
            ? _EmptyState(memberName: args.memberName)
            : _InsightContent(insight: insight),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Loading skeleton
// ═══════════════════════════════════════════════════════════════════════════

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: Text(
            'Member Insights',
            style: GoogleFonts.notoSerif(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.lg),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.shimmer,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                ),
              ),
              childCount: 5,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Error
// ═══════════════════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: AppSizes.lg),
            Text(
              'Could not load insights',
              style: GoogleFonts.notoSerif(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: AppSizes.xxl),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AtelierColors.primary,
                foregroundColor: AtelierColors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty — subscription not active
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.memberName});

  final String memberName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(memberName, style: GoogleFonts.notoSerif()),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.lg),
            Text(
              'No active subscription found',
              style: GoogleFonts.notoSerif(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Main content
// ═══════════════════════════════════════════════════════════════════════════

class _InsightContent extends StatelessWidget {
  const _InsightContent({required this.insight});

  final MemberInsightEntity insight;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── App bar ──
        SliverAppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          pinned: true,
          title: Text(
            'Member Insights',
            style: GoogleFonts.notoSerif(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),

        // ── Header card ──
        SliverToBoxAdapter(
          child: _MemberHeader(insight: insight),
        ),

        // ── Risk flags banner ──
        if (insight.hasAnyRisk)
          SliverToBoxAdapter(child: _RiskFlagBanner(flags: insight.riskFlags)),

        // ── Insight sections ──
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.screenPadding,
            vertical: AppSizes.sm,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _InsightSection(
                title: 'AI Plan Summary',
                icon: Icons.fitness_center_rounded,
                isAvailable: insight.planInsight != null,
                child: insight.planInsight != null
                    ? _PlanInsightCard(plan: insight.planInsight!)
                    : null,
              ),
              _InsightSection(
                title: 'Workout Adherence',
                icon: Icons.trending_up_rounded,
                isAvailable: insight.adherenceInsight != null,
                child: insight.adherenceInsight != null
                    ? _AdherenceInsightCard(
                        adherence: insight.adherenceInsight!)
                    : null,
              ),
              _InsightSection(
                title: 'Progress Metrics',
                icon: Icons.monitor_weight_outlined,
                isAvailable: insight.progressInsight != null,
                child: insight.progressInsight != null
                    ? _ProgressInsightCard(
                        progress: insight.progressInsight!)
                    : null,
              ),
              _InsightSection(
                title: 'Nutrition Summary',
                icon: Icons.restaurant_rounded,
                isAvailable: insight.nutritionInsight != null,
                child: insight.nutritionInsight != null
                    ? _NutritionInsightCard(
                        nutrition: insight.nutritionInsight!)
                    : null,
              ),
              _InsightSection(
                title: 'Product Intelligence',
                icon: Icons.shopping_bag_outlined,
                isAvailable: insight.productInsight != null,
                child: insight.productInsight != null
                    ? _ProductInsightCard(
                        product: insight.productInsight!)
                    : null,
              ),
              const SizedBox(height: AppSizes.huge),
            ]),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════════════════════════════════

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.insight});

  final MemberInsightEntity insight;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 400),
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.sm,
          AppSizes.screenPadding,
          AppSizes.lg,
        ),
        padding: const EdgeInsets.all(AppSizes.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AtelierColors.surfaceContainerLow,
              AtelierColors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          border: Border.all(color: AtelierColors.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: AtelierColors.primaryContainer.withValues(alpha: 0.15),
              child: Text(
                (insight.memberName.isNotEmpty
                        ? insight.memberName[0]
                        : '?')
                    .toUpperCase(),
                style: GoogleFonts.notoSerif(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AtelierColors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.lg),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.memberName,
                    style: GoogleFonts.notoSerif(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (insight.currentGoal != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Goal: ${insight.currentGoal}',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (insight.packageTitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      insight.packageTitle!,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AtelierColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Risk flag banner
// ═══════════════════════════════════════════════════════════════════════════

class _RiskFlagBanner extends StatelessWidget {
  const _RiskFlagBanner({required this.flags});

  final List<String> flags;

  String _flagLabel(String flag) {
    switch (flag) {
      case 'low_adherence':
        return 'Low adherence detected';
      case 'many_missed_sessions':
        return 'Many missed sessions';
      case 'no_recent_checkin':
        return 'No recent check-in';
      default:
        return flag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        margin: const EdgeInsets.only(bottom: AppSizes.lg),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 20),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                flags.map(_flagLabel).join(' · '),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Generic section wrapper
// ═══════════════════════════════════════════════════════════════════════════

class _InsightSection extends StatelessWidget {
  const _InsightSection({
    required this.title,
    required this.icon,
    required this.isAvailable,
    this.child,
  });

  final String title;
  final IconData icon;
  final bool isAvailable;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.lg),
        decoration: BoxDecoration(
          color: AtelierColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AtelierColors.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? AtelierColors.primary.withValues(alpha: 0.08)
                          : AppColors.shimmer,
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: isAvailable
                          ? AtelierColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.notoSerif(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isAvailable
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  if (!isAvailable)
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: AppColors.textMuted),
                ],
              ),
            ),

            // Content or locked placeholder
            if (isAvailable && child != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg, 0, AppSizes.lg, AppSizes.lg),
                child: child!,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg, 0, AppSizes.lg, AppSizes.lg),
                child: Text(
                  'Member hasn\'t shared this data yet',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Plan insight card
// ═══════════════════════════════════════════════════════════════════════════

class _PlanInsightCard extends StatelessWidget {
  const _PlanInsightCard({required this.plan});

  final PlanInsightEntity plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plan.planTitle ?? 'Workout Plan',
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.xs,
          children: [
            _MetricChip(
                label: '${plan.durationWeeks ?? 1}w',
                icon: Icons.calendar_today_rounded),
            _MetricChip(
                label: '${plan.totalDays} days',
                icon: Icons.view_day_rounded),
            _MetricChip(
                label: '${plan.totalTasks} tasks',
                icon: Icons.task_alt_rounded),
            if (plan.level != null)
              _MetricChip(
                  label: plan.level!,
                  icon: Icons.signal_cellular_alt_rounded),
          ],
        ),
        if (plan.summary != null && plan.summary!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          Text(
            plan.summary!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Adherence insight card
// ═══════════════════════════════════════════════════════════════════════════

class _AdherenceInsightCard extends StatelessWidget {
  const _AdherenceInsightCard({required this.adherence});

  final AdherenceInsightEntity adherence;

  Color _completionColor(double rate) {
    if (rate >= 75) return AppColors.success;
    if (rate >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Big completion rate
        Row(
          children: [
            Text(
              '${adherence.completionRate.toStringAsFixed(1)}%',
              style: GoogleFonts.notoSerif(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: _completionColor(adherence.completionRate),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Completion rate',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: adherence.completionRate / 100,
                      backgroundColor: AppColors.shimmer,
                      valueColor: AlwaysStoppedAnimation(
                        _completionColor(adherence.completionRate),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.lg),
        // Stats row
        Wrap(
          spacing: AppSizes.md,
          runSpacing: AppSizes.sm,
          children: [
            _StatChip(
                label: 'Completed', value: '${adherence.completedTasks}'),
            _StatChip(
                label: 'Partial', value: '${adherence.partialTasks}'),
            _StatChip(
                label: 'Skipped', value: '${adherence.skippedTasks}'),
            _StatChip(
                label: 'Missed', value: '${adherence.missedTasks}'),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Progress insight card
// ═══════════════════════════════════════════════════════════════════════════

class _ProgressInsightCard extends StatelessWidget {
  const _ProgressInsightCard({required this.progress});

  final ProgressInsightEntity progress;

  IconData _trendIcon(String? trend) {
    switch (trend) {
      case 'decreasing':
        return Icons.trending_down_rounded;
      case 'increasing':
        return Icons.trending_up_rounded;
      case 'stable':
        return Icons.trending_flat_rounded;
      default:
        return Icons.remove_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progress.latestWeight != null)
          Row(
            children: [
              Text(
                '${progress.latestWeight!.toStringAsFixed(1)} kg',
                style: GoogleFonts.notoSerif(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Icon(
                _trendIcon(progress.weightTrend),
                color: progress.weightTrend == 'decreasing'
                    ? AppColors.success
                    : progress.weightTrend == 'increasing'
                        ? AppColors.warning
                        : AppColors.textMuted,
              ),
            ],
          ),
        if (progress.weight4wAgo != null) ...[
          const SizedBox(height: 4),
          Text(
            '4 weeks ago: ${progress.weight4wAgo!.toStringAsFixed(1)} kg',
            style: GoogleFonts.manrope(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
        if (progress.latestMeasurement != null) ...[
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.xs,
            children: [
              if (progress.latestMeasurement!.waistCm != null)
                _MetricChip(
                    label:
                        'Waist ${progress.latestMeasurement!.waistCm!.toStringAsFixed(1)} cm',
                    icon: Icons.straighten_rounded),
              if (progress.latestMeasurement!.bodyFatPercent != null)
                _MetricChip(
                    label:
                        'BF ${progress.latestMeasurement!.bodyFatPercent!.toStringAsFixed(1)}%',
                    icon: Icons.percent_rounded),
            ],
          ),
        ],
        if (progress.latestCheckinAdherence != null) ...[
          const SizedBox(height: AppSizes.md),
          Text(
            'Last check-in adherence: ${progress.latestCheckinAdherence}%',
            style: GoogleFonts.manrope(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Nutrition insight card
// ═══════════════════════════════════════════════════════════════════════════

class _NutritionInsightCard extends StatelessWidget {
  const _NutritionInsightCard({required this.nutrition});

  final NutritionInsightEntity nutrition;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nutrition.targetCalories != null)
          Text(
            '${nutrition.targetCalories} kcal target',
            style: GoogleFonts.notoSerif(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        const SizedBox(height: AppSizes.sm),
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.xs,
          children: [
            if (nutrition.targetProteinG != null)
              _MetricChip(
                  label: 'P ${nutrition.targetProteinG}g',
                  icon: Icons.egg_rounded),
            if (nutrition.targetCarbsG != null)
              _MetricChip(
                  label: 'C ${nutrition.targetCarbsG}g',
                  icon: Icons.grain_rounded),
            if (nutrition.targetFatsG != null)
              _MetricChip(
                  label: 'F ${nutrition.targetFatsG}g',
                  icon: Icons.water_drop_rounded),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        Row(
          children: [
            Icon(
              nutrition.hasActiveMealPlan
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              size: 16,
              color: nutrition.hasActiveMealPlan
                  ? AppColors.success
                  : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              nutrition.hasActiveMealPlan
                  ? 'Active meal plan'
                  : 'No active meal plan',
              style: GoogleFonts.manrope(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Product insight card
// ═══════════════════════════════════════════════════════════════════════════

class _ProductInsightCard extends StatelessWidget {
  const _ProductInsightCard({required this.product});

  final ProductInsightEntity product;

  @override
  Widget build(BuildContext context) {
    final hasRecommended = product.recommendedProducts.isNotEmpty;
    final hasPurchased = product.purchasedRelevant.isNotEmpty;

    if (!hasRecommended && !hasPurchased) {
      return Text(
        'No product intelligence available yet',
        style:
            GoogleFonts.manrope(fontSize: 13, color: AppColors.textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasRecommended) ...[
          Text(
            'Recommended',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          ...product.recommendedProducts.take(3).map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: AtelierColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.productTitle,
                          style: GoogleFonts.manrope(
                              fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ),
                      _ContextBadge(context: r.context),
                    ],
                  ),
                ),
              ),
        ],
        if (hasPurchased) ...[
          const SizedBox(height: AppSizes.md),
          Text(
            'Purchased',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          ...product.purchasedRelevant.take(3).map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${p.productTitle} ×${p.quantity}',
                          style: GoogleFonts.manrope(
                              fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared small widgets
// ═══════════════════════════════════════════════════════════════════════════

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AtelierColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.notoSerif(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.manrope(
              fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ContextBadge extends StatelessWidget {
  const _ContextBadge({required this.context});

  final String context;

  String get _label {
    switch (context) {
      case 'ai_plan_accessory':
        return 'AI Plan';
      case 'nutrition_goal':
        return 'Nutrition';
      case 'equipment_gap':
        return 'Equipment';
      case 'coach_suggestion':
        return 'Suggested';
      default:
        return context;
    }
  }

  @override
  Widget build(BuildContext buildCtx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AtelierColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        _label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AtelierColors.primary,
        ),
      ),
    );
  }
}
