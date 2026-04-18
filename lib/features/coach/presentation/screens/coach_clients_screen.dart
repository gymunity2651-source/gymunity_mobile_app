import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../../domain/entities/subscription_entity.dart';
import '../providers/coach_providers.dart';

class CoachClientsScreen extends ConsumerStatefulWidget {
  const CoachClientsScreen({super.key});

  @override
  ConsumerState<CoachClientsScreen> createState() => _CoachClientsScreenState();
}

class _CoachClientsScreenState extends ConsumerState<CoachClientsScreen> {
  String _selectedStatus = 'pending';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(coachSubscriptionRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                32,
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
                            'Client pipeline',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Review paid leads, inspect intake notes, and assign starter plans quickly.',
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
                requestsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.xl),
                      child: CircularProgressIndicator(color: AppColors.orange),
                    ),
                  ),
                  error: (error, _) => _ClientStateCard(
                    title: 'Subscription queue unavailable',
                    description: error.toString(),
                    actionLabel: 'Retry',
                    onTap: () =>
                        ref.invalidate(coachSubscriptionRequestsProvider),
                  ),
                  data: (requests) {
                    final pending = requests
                        .where(
                          (item) =>
                              item.status == 'checkout_pending' ||
                              item.status == 'pending_payment' ||
                              item.status == 'pending_activation',
                        )
                        .toList(growable: false);
                    final active = requests
                        .where((item) => item.status == 'active')
                        .toList(growable: false);
                    final completed = requests
                        .where(
                          (item) =>
                              item.status != 'pending_payment' &&
                              item.status != 'active',
                        )
                        .toList(growable: false);

                    final visible = switch (_selectedStatus) {
                      'active' => active,
                      'completed' => completed,
                      _ => pending,
                    };

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSizes.sm,
                          runSpacing: AppSizes.sm,
                          children: [
                            _statusChip('pending', pending.length),
                            _statusChip('active', active.length),
                            _statusChip('completed', completed.length),
                          ],
                        ),
                        const SizedBox(height: AppSizes.lg),
                        if (visible.isEmpty)
                          _ClientStateCard(
                            title:
                                'No ${_selectedStatus.toLowerCase()} subscriptions',
                            description: _selectedStatus == 'pending'
                                ? 'New paid or pending activations appear here with structured intake details.'
                                : _selectedStatus == 'active'
                                ? 'Active subscriptions appear here once payment is confirmed and the starter plan is assigned.'
                                : 'Completed, cancelled, or declined subscriptions are grouped here.',
                            actionLabel: 'Refresh',
                            onTap: _refresh,
                          )
                        else
                          ...visible.map(
                            (subscription) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSizes.md,
                              ),
                              child: _SubscriptionCard(
                                subscription: subscription,
                                canApprove:
                                    _selectedStatus == 'pending' &&
                                    !_isProcessing,
                                canReject:
                                    _selectedStatus == 'pending' &&
                                    !_isProcessing,
                                onApprove: () => _approve(subscription),
                                onReject: () => _reject(subscription),
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

  Widget _statusChip(String status, int count) {
    final selected = _selectedStatus == status;
    final color = switch (status) {
      'active' => AppColors.limeGreen,
      'completed' => AppColors.textMuted,
      _ => AppColors.orangeLight,
    };
    return ChoiceChip(
      label: Text('${_titleize(status)} ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => _selectedStatus = status),
      backgroundColor: AppColors.fieldFill,
      selectedColor: color.withValues(alpha: 0.16),
      side: BorderSide(color: selected ? color : AppColors.border),
      labelStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: selected ? color : AppColors.textSecondary,
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(coachSubscriptionRequestsProvider);
    ref.invalidate(coachClientsProvider);
    ref.invalidate(coachDashboardSummaryProvider);
    await ref.read(coachSubscriptionRequestsProvider.future);
  }

  Future<void> _approve(SubscriptionEntity subscription) async {
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(coachRepositoryProvider)
          .activateSubscriptionWithStarterPlan(
            subscriptionId: subscription.id,
            startDate: DateTime.now(),
          );
      ref.invalidate(coachSubscriptionRequestsProvider);
      ref.invalidate(coachClientsProvider);
      ref.invalidate(coachDashboardSummaryProvider);
      ref.invalidate(coachWorkoutPlansProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starter plan assigned and subscription is live.'),
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
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject(SubscriptionEntity subscription) async {
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(coachRepositoryProvider)
          .updateSubscriptionStatus(
            subscriptionId: subscription.id,
            newStatus: 'cancelled',
          );
      ref.invalidate(coachSubscriptionRequestsProvider);
      ref.invalidate(coachClientsProvider);
      ref.invalidate(coachDashboardSummaryProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription request declined.')),
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
      setState(() => _isProcessing = false);
    }
  }

  String _titleize(String value) =>
      '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.subscription,
    required this.canApprove,
    required this.canReject,
    required this.onApprove,
    required this.onReject,
  });

  final SubscriptionEntity subscription;
  final bool canApprove;
  final bool canReject;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final intake = subscription.intakeSnapshot;
    final intakeItems = <String>[
      if ((intake.goal ?? '').trim().isNotEmpty) 'Goal: ${intake.goal}',
      if ((intake.experienceLevel ?? '').trim().isNotEmpty)
        'Experience: ${intake.experienceLevel}',
      if (intake.daysPerWeek != null) 'Days / week: ${intake.daysPerWeek}',
      if (intake.sessionMinutes != null)
        'Session length: ${intake.sessionMinutes} min',
      if (intake.equipment.isNotEmpty)
        'Equipment: ${intake.equipment.join(', ')}',
      if (intake.limitations.isNotEmpty)
        'Limitations: ${intake.limitations.join(', ')}',
    ];

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
                      subscription.memberName ?? 'Member',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subscription.displayTitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: subscription.status),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              _IntakeChip(
                label:
                    '\$${subscription.amount.toStringAsFixed(0)}/${subscription.billingCycle.replaceAll('_', ' ')}',
              ),
              if (subscription.createdAt != null)
                _IntakeChip(
                  label: 'Requested ${_formatDate(subscription.createdAt!)}',
                ),
              if (subscription.startsAt != null)
                _IntakeChip(
                  label: 'Starts ${_formatDate(subscription.startsAt!)}',
                ),
            ],
          ),
          if (subscription.memberNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSizes.md),
            Text(
              'Member note',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              subscription.memberNote!.trim(),
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (intakeItems.isNotEmpty) ...[
            const SizedBox(height: AppSizes.md),
            Text(
              'Intake snapshot',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            ...intakeItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.orangeLight,
                    ),
                    Expanded(
                      child: Text(
                        item,
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
          if (canApprove || canReject) ...[
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                if (canReject)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      child: const Text('Reject'),
                    ),
                  ),
                if (canApprove && canReject) const SizedBox(width: AppSizes.md),
                if (canApprove)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: AppColors.white,
                      ),
                      child: const Text('Assign starter plan'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppColors.limeGreen,
      'completed' => AppColors.textMuted,
      'cancelled' => AppColors.error,
      _ => AppColors.orangeLight,
    };
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
        status.replaceAll('_', ' '),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _IntakeChip extends StatelessWidget {
  const _IntakeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ClientStateCard extends StatelessWidget {
  const _ClientStateCard({
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
