import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/external_link_service.dart';
import '../../domain/entities/monetization_entities.dart';
import '../providers/monetization_providers.dart';

class SubscriptionManagementScreen extends ConsumerWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(currentSubscriptionSummaryProvider);
    final latestEvent = ref.watch(billingInteractionEventProvider);
    final actionState = ref.watch(subscriptionManagementControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Subscription Status')),
      body: RefreshIndicator.adaptive(
        onRefresh: () => ref
            .read(currentSubscriptionSummaryProvider.notifier)
            .refreshFromBackend(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            if (latestEvent != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  latestEvent.message ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _StateCard(
                title: 'Unable to load subscription',
                message:
                    'GymUnity could not refresh your AI Premium subscription state.',
                actionLabel: 'Retry',
                onTap: () => ref
                    .read(currentSubscriptionSummaryProvider.notifier)
                    .refreshFromBackend(),
              ),
              data: (summary) {
                if (summary == null) {
                  return _StateCard(
                    title: 'No active AI Premium subscription',
                    message:
                        'You do not have a verified AI Premium entitlement on this account yet.',
                    actionLabel: 'Restore Purchases',
                    onTap: () => ref
                        .read(
                          subscriptionManagementControllerProvider.notifier,
                        )
                        .restore(),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Premium',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary.plan == AiPremiumPlan.annual
                            ? 'Annual plan'
                            : 'Monthly plan',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Line(
                        label: 'Lifecycle',
                        value: summary.entitlement.lifecycleState.name,
                      ),
                      _Line(
                        label: 'Entitlement',
                        value: summary.entitlement.status.name,
                      ),
                      if (summary.renewsAt != null)
                        _Line(
                          label: 'Renews',
                          value: summary.renewsAt!.toLocal().toString(),
                        ),
                      if (summary.expiresAt != null)
                        _Line(
                          label: 'Access until',
                          value: summary.expiresAt!.toLocal().toString(),
                        ),
                      if (summary.gracePeriodUntil != null)
                        _Line(
                          label: 'Grace period',
                          value: summary.gracePeriodUntil!.toLocal().toString(),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        summary.entitlement.message ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  actionState.actionState ==
                                      PurchaseActionState.restoring
                                  ? null
                                  : () => ref
                                        .read(
                                          subscriptionManagementControllerProvider
                                              .notifier,
                                        )
                                        .restore(),
                              child: Text(
                                actionState.actionState ==
                                        PurchaseActionState.restoring
                                    ? 'Restoring...'
                                    : 'Restore',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: summary.manageUrl == null
                                  ? null
                                  : () => ExternalLinkService.openUrl(
                                      summary.manageUrl!,
                                    ),
                              child: const Text('Manage'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
