import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../../domain/entities/coach_entity.dart';
import '../providers/coach_providers.dart';
import 'coach_package_editor_screen.dart';

class CoachPackagesScreen extends ConsumerStatefulWidget {
  const CoachPackagesScreen({super.key});

  @override
  ConsumerState<CoachPackagesScreen> createState() =>
      _CoachPackagesScreenState();
}

class _CoachPackagesScreenState extends ConsumerState<CoachPackagesScreen> {
  String _selectedStatus = 'published';
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(coachProfileProvider);
    final packagesAsync = ref.watch(coachPackagesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: const Text('New offer'),
      ),
      body: SafeArea(
        child: AppShellBackground(
          topGlowColor: AppColors.glowOrange,
          bottomGlowColor: AppColors.glowBlue,
          child: RefreshIndicator.adaptive(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.xl,
                AppSizes.screenPadding,
                112,
              ),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offer library',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage draft, published, and archived coaching offers from one place.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                profileAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (profile) => profile == null
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.subscriptionPackages,
                              arguments: profile,
                            ),
                            icon: const Icon(Icons.public_rounded),
                            label: const Text('Preview public storefront'),
                          ),
                        ),
                ),
                const SizedBox(height: AppSizes.md),
                packagesAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.xl),
                      child: CircularProgressIndicator(color: AppColors.orange),
                    ),
                  ),
                  error: (error, stackTrace) => _StateCard(
                    title: 'Offers are unavailable',
                    description: error.toString(),
                    actionLabel: 'Retry',
                    onTap: () => ref.invalidate(coachPackagesProvider),
                  ),
                  data: (packages) {
                    final counts = <String, int>{
                      'published': packages
                          .where((item) => item.visibilityStatus == 'published')
                          .length,
                      'draft': packages
                          .where((item) => item.visibilityStatus == 'draft')
                          .length,
                      'archived': packages
                          .where((item) => item.visibilityStatus == 'archived')
                          .length,
                    };
                    final filtered = packages
                        .where(
                          (item) => item.visibilityStatus == _selectedStatus,
                        )
                        .toList(growable: false);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSizes.sm,
                          runSpacing: AppSizes.sm,
                          children: counts.entries
                              .map(
                                (entry) => ChoiceChip(
                                  label: Text(
                                    '${_titleize(entry.key)} (${entry.value})',
                                  ),
                                  selected: _selectedStatus == entry.key,
                                  onSelected: (_) {
                                    setState(() => _selectedStatus = entry.key);
                                  },
                                  backgroundColor: AppColors.fieldFill,
                                  selectedColor: _statusColor(
                                    entry.key,
                                  ).withValues(alpha: 0.16),
                                  side: BorderSide(
                                    color: _selectedStatus == entry.key
                                        ? _statusColor(entry.key)
                                        : AppColors.border,
                                  ),
                                  labelStyle: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: _selectedStatus == entry.key
                                        ? _statusColor(entry.key)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: AppSizes.lg),
                        if (filtered.isEmpty)
                          _StateCard(
                            title:
                                'No ${_titleize(_selectedStatus).toLowerCase()} offers',
                            description: _selectedStatus == 'published'
                                ? 'Publish an offer so members can subscribe from your public storefront.'
                                : _selectedStatus == 'draft'
                                ? 'Save in-progress offers here before going live.'
                                : 'Archived offers stay out of the marketplace until you restore them.',
                            actionLabel: 'Create offer',
                            onTap: () => _openEditor(context),
                          )
                        else
                          ...filtered.map(
                            (package) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSizes.md,
                              ),
                              child: _OfferCard(
                                package: package,
                                statusColor: _statusColor(
                                  package.visibilityStatus,
                                ),
                                onEdit: () => _openEditor(context, package),
                                onPreview:
                                    profileAsync.valueOrNull == null ||
                                        !package.isPublished
                                    ? null
                                    : () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.subscriptionPackages,
                                        arguments: profileAsync.valueOrNull,
                                      ),
                                onStatusSelected: _isUpdating
                                    ? null
                                    : (status) =>
                                          _updateVisibility(package, status),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(coachPackagesProvider);
    ref.invalidate(coachDashboardSummaryProvider);
    ref.invalidate(coachProfileProvider);
    await ref.read(coachPackagesProvider.future);
  }

  Future<void> _openEditor(
    BuildContext context, [
    CoachPackageEntity? package,
  ]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoachPackageEditorScreen(initialPackage: package),
      ),
    );
    ref.invalidate(coachPackagesProvider);
    ref.invalidate(coachDashboardSummaryProvider);
  }

  Future<void> _updateVisibility(
    CoachPackageEntity package,
    String visibilityStatus,
  ) async {
    setState(() => _isUpdating = true);
    try {
      await ref
          .read(coachRepositoryProvider)
          .saveCoachPackage(
            packageId: package.id,
            title: package.title,
            subtitle: package.subtitle,
            description: package.description,
            billingCycle: package.billingCycle,
            price: package.price,
            outcomeSummary: package.outcomeSummary,
            idealFor: package.idealFor,
            durationWeeks: package.durationWeeks,
            sessionsPerWeek: package.sessionsPerWeek,
            difficultyLevel: package.difficultyLevel,
            equipmentTags: package.equipmentTags,
            includedFeatures: package.includedFeatures,
            checkInFrequency: package.checkInFrequency,
            supportSummary: package.supportSummary,
            faqItems: package.faqItems,
            planPreviewJson: package.planPreviewJson,
            visibilityStatus: visibilityStatus,
            isActive: visibilityStatus == 'published',
          );
      ref.invalidate(coachPackagesProvider);
      ref.invalidate(coachDashboardSummaryProvider);
      ref.invalidate(coachProfileProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Offer moved to ${_titleize(visibilityStatus).toLowerCase()}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
    if (mounted) {
      setState(() => _isUpdating = false);
    }
  }

  String _titleize(String value) {
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'published':
        return AppColors.limeGreen;
      case 'archived':
        return AppColors.textMuted;
      default:
        return AppColors.orangeLight;
    }
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.package,
    required this.statusColor,
    required this.onEdit,
    this.onPreview,
    this.onStatusSelected,
  });

  final CoachPackageEntity package;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback? onPreview;
  final ValueChanged<String>? onStatusSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (package.subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        package.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surfaceRaised,
                onSelected: onStatusSelected,
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'published',
                    child: Text('Move to Published'),
                  ),
                  PopupMenuItem<String>(
                    value: 'draft',
                    child: Text('Move to Draft'),
                  ),
                  PopupMenuItem<String>(
                    value: 'archived',
                    child: Text('Archive'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              _MetaChip(
                label:
                    '\$${package.price.toStringAsFixed(0)}/${package.billingCycle.replaceAll('_', ' ')}',
              ),
              _MetaChip(label: '${package.durationWeeks} weeks'),
              _MetaChip(label: '${package.sessionsPerWeek} sessions / week'),
              _MetaChip(
                label: package.checkInFrequency.isEmpty
                    ? 'Custom check-ins'
                    : package.checkInFrequency,
              ),
              _MetaChip(label: package.visibilityStatus, color: statusColor),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            package.outcomeSummary.trim().isEmpty
                ? package.description
                : package.outcomeSummary,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (package.includedFeatures.isNotEmpty) ...[
            const SizedBox(height: AppSizes.md),
            ...package.includedFeatures
                .take(3)
                .map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: AppColors.orangeLight,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            feature,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  child: const Text('Edit'),
                ),
              ),
              if (onPreview != null) ...[
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPreview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Preview'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.color = AppColors.electricBlue});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.white,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
