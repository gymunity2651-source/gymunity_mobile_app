import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/visibility_audit_entity.dart';
import '../../domain/entities/visibility_settings_entity.dart';
import '../providers/insight_providers.dart';

/// Member-facing privacy settings screen where each coaching-data
/// category can be individually toggled on/off.
class MemberCoachVisibilitySettingsScreen extends ConsumerStatefulWidget {
  const MemberCoachVisibilitySettingsScreen({
    super.key,
    required this.args,
  });

  final VisibilitySettingsArgs args;

  @override
  ConsumerState<MemberCoachVisibilitySettingsScreen> createState() =>
      _MemberCoachVisibilitySettingsScreenState();
}

class _MemberCoachVisibilitySettingsScreenState
    extends ConsumerState<MemberCoachVisibilitySettingsScreen> {
  late bool _shareAiPlanSummary;
  late bool _shareWorkoutAdherence;
  late bool _shareProgressMetrics;
  late bool _shareNutritionSummary;
  late bool _shareProductRecommendations;
  late bool _shareRelevantPurchases;
  bool _initialized = false;
  bool _saving = false;
  bool _showAudit = false;

  void _initFromEntity(VisibilitySettingsEntity? entity) {
    if (_initialized) return;
    _shareAiPlanSummary = entity?.shareAiPlanSummary ?? false;
    _shareWorkoutAdherence = entity?.shareWorkoutAdherence ?? false;
    _shareProgressMetrics = entity?.shareProgressMetrics ?? false;
    _shareNutritionSummary = entity?.shareNutritionSummary ?? false;
    _shareProductRecommendations = entity?.shareProductRecommendations ?? false;
    _shareRelevantPurchases = entity?.shareRelevantPurchases ?? false;
    _initialized = true;
  }

  bool get _anyEnabled =>
      _shareAiPlanSummary ||
      _shareWorkoutAdherence ||
      _shareProgressMetrics ||
      _shareNutritionSummary ||
      _shareProductRecommendations ||
      _shareRelevantPurchases;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(coachMemberInsightsRepositoryProvider);
      await repo.upsertVisibilitySettings(
        subscriptionId: widget.args.subscriptionId,
        coachId: widget.args.coachId,
        shareAiPlanSummary: _shareAiPlanSummary,
        shareWorkoutAdherence: _shareWorkoutAdherence,
        shareProgressMetrics: _shareProgressMetrics,
        shareNutritionSummary: _shareNutritionSummary,
        shareProductRecommendations: _shareProductRecommendations,
        shareRelevantPurchases: _shareRelevantPurchases,
      );
      // Refresh providers
      ref.invalidate(
          memberVisibilitySettingsProvider(widget.args.subscriptionId));
      ref.invalidate(
          memberVisibilityAuditProvider(widget.args.subscriptionId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Visibility settings saved',
              style: GoogleFonts.manrope(),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _revokeAll() {
    setState(() {
      _shareAiPlanSummary = false;
      _shareWorkoutAdherence = false;
      _shareProgressMetrics = false;
      _shareNutritionSummary = false;
      _shareProductRecommendations = false;
      _shareRelevantPurchases = false;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(
        memberVisibilitySettingsProvider(widget.args.subscriptionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Privacy Settings',
          style: GoogleFonts.notoSerif(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_anyEnabled)
            TextButton(
              onPressed: _saving ? null : _revokeAll,
              child: Text(
                'Revoke all',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            child: Text('Error: $e', style: TextStyle(color: AppColors.error)),
          ),
        ),
        data: (entity) {
          _initFromEntity(entity);
          return _buildContent(context);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.screenPadding,
        vertical: AppSizes.lg,
      ),
      children: [
        // ── Explanation header ──
        Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(
              color: AtelierColors.outlineVariant,
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 36,
                color: AtelierColors.primary,
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                'Control what ${widget.args.coachName} can see',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSerif(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                'Your data is private by default. Toggle each category below to share aggregated summaries with your coach. You can change these at any time.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSizes.xxl),

        // ── Toggles ──
        _ToggleCard(
          icon: Icons.fitness_center_rounded,
          title: 'AI Plan Summary',
          subtitle: 'Share your active workout plan title, duration, and overview',
          value: _shareAiPlanSummary,
          onChanged: (v) => setState(() => _shareAiPlanSummary = v),
        ),
        _ToggleCard(
          icon: Icons.trending_up_rounded,
          title: 'Workout Adherence',
          subtitle: 'Share task completion rates and missed session counts',
          value: _shareWorkoutAdherence,
          onChanged: (v) => setState(() => _shareWorkoutAdherence = v),
        ),
        _ToggleCard(
          icon: Icons.monitor_weight_outlined,
          title: 'Progress Metrics',
          subtitle: 'Share weight trends, body measurements, and check-in scores',
          value: _shareProgressMetrics,
          onChanged: (v) => setState(() => _shareProgressMetrics = v),
        ),
        _ToggleCard(
          icon: Icons.restaurant_rounded,
          title: 'Nutrition Summary',
          subtitle: 'Share calorie & macro targets and nutrition adherence',
          value: _shareNutritionSummary,
          onChanged: (v) => setState(() => _shareNutritionSummary = v),
        ),
        _ToggleCard(
          icon: Icons.shopping_bag_outlined,
          title: 'Product Recommendations',
          subtitle: 'Share AI-suggested products and equipment needs',
          value: _shareProductRecommendations,
          onChanged: (v) => setState(() => _shareProductRecommendations = v),
        ),
        _ToggleCard(
          icon: Icons.receipt_long_rounded,
          title: 'Relevant Purchases',
          subtitle: 'Share purchase activity for recommended products only',
          value: _shareRelevantPurchases,
          onChanged: (v) => setState(() => _shareRelevantPurchases = v),
        ),

        const SizedBox(height: AppSizes.xxl),

        // ── Save button ──
        SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AtelierColors.primary,
              foregroundColor: AtelierColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Save Settings',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: AppSizes.xxxl),

        // ── Audit timeline ──
        GestureDetector(
          onTap: () => setState(() => _showAudit = !_showAudit),
          child: Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  'Consent change history',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Icon(
                _showAudit
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),

        if (_showAudit) ...[
          const SizedBox(height: AppSizes.md),
          _AuditTimeline(subscriptionId: widget.args.subscriptionId),
        ],

        const SizedBox(height: AppSizes.huge),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Toggle card
// ═══════════════════════════════════════════════════════════════════════════

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: AppSizes.md),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg, vertical: AppSizes.md),
      decoration: BoxDecoration(
        color: value
            ? AtelierColors.primary.withValues(alpha: 0.04)
            : AtelierColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: value
              ? AtelierColors.primary.withValues(alpha: 0.2)
              : AtelierColors.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: value
                  ? AtelierColors.primary.withValues(alpha: 0.1)
                  : AppColors.shimmer,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(
              icon,
              size: 20,
              color: value ? AtelierColors.primary : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AtelierColors.primary,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Audit timeline
// ═══════════════════════════════════════════════════════════════════════════

class _AuditTimeline extends ConsumerWidget {
  const _AuditTimeline({required this.subscriptionId});

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync =
        ref.watch(memberVisibilityAuditProvider(subscriptionId));

    return auditAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSizes.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e',
          style: GoogleFonts.manrope(color: AppColors.error)),
      data: (entries) {
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Text(
              'No changes recorded yet',
              style: GoogleFonts.manrope(
                  fontSize: 13, color: AppColors.textMuted),
            ),
          );
        }

        return Column(
          children: entries.map((e) => _AuditEntry(audit: e)).toList(),
        );
      },
    );
  }
}

class _AuditEntry extends StatelessWidget {
  const _AuditEntry({required this.audit});

  final VisibilityAuditEntity audit;

  IconData get _icon {
    switch (audit.changeType) {
      case 'initial_grant':
        return Icons.lock_open_rounded;
      case 'revoked_all':
        return Icons.lock_rounded;
      default:
        return Icons.edit_rounded;
    }
  }

  Color get _color {
    switch (audit.changeType) {
      case 'initial_grant':
        return AppColors.success;
      case 'revoked_all':
        return AppColors.error;
      default:
        return AtelierColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 14, color: _color),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  audit.changeLabel,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(audit.createdAt),
                  style: GoogleFonts.manrope(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
