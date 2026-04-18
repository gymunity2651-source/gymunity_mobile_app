import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/ai_branding.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/external_link_service.dart';
import '../../domain/entities/monetization_entities.dart';
import '../providers/monetization_providers.dart';

class AiPremiumPaywallScreen extends ConsumerWidget {
  const AiPremiumPaywallScreen({
    super.key,
    this.showBackButton = true,
    this.lockReason,
  });

  final bool showBackButton;
  final String? lockReason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(billingCatalogProvider);
    final summaryAsync = ref.watch(currentSubscriptionSummaryProvider);
    final actionState = ref.watch(subscriptionManagementControllerProvider);
    final latestEvent = ref.watch(billingInteractionEventProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: showBackButton
            ? IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: const Text(AiBranding.premiumName),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(billingCatalogProvider);
          await ref
              .read(currentSubscriptionSummaryProvider.notifier)
              .refreshFromBackend();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            _HeroCard(lockReason: lockReason),
            if (latestEvent != null) ...[
              const SizedBox(height: 16),
              _StatusBanner(event: latestEvent),
            ],
            if ((actionState.message ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _InlineMessage(message: actionState.message!),
            ],
            const SizedBox(height: 20),
            Text(
              'Included with ${AiBranding.premiumName}',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const _BenefitTile(
              icon: Icons.chat_bubble_outline,
              title: 'Unlimited TAIYO chat',
              description:
                  'Use TAIYO conversations without a local demo or fake fallback.',
            ),
            const _BenefitTile(
              icon: Icons.auto_graph_outlined,
              title: 'TAIYO-guided plans',
              description:
                  'Unlock TAIYO plan-generation surfaces tied to your account entitlement.',
            ),
            const _BenefitTile(
              icon: Icons.restart_alt_outlined,
              title: 'Restore across devices',
              description:
                  'Restore verified purchases after reinstalling or switching devices.',
            ),
            const SizedBox(height: 20),
            summaryAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => _ErrorCard(
                title: 'Unable to load premium access',
                message: 'GymUnity could not refresh your TAIYO Premium state.',
                actionLabel: 'Retry',
                onTap: () => ref
                    .read(currentSubscriptionSummaryProvider.notifier)
                    .refreshFromBackend(),
              ),
              data: (summary) {
                if (summary?.hasAccess ?? false) {
                  return _CurrentSubscriptionCard(summary: summary!);
                }
                return catalogAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => _ErrorCard(
                    title: 'Unable to load store pricing',
                    message:
                        'GymUnity could not reach Apple or Google billing right now.',
                    actionLabel: 'Retry',
                    onTap: () => ref.invalidate(billingCatalogProvider),
                  ),
                  data: (catalog) {
                    if (catalog == null) {
                      return const _InfoCard(
                        title: '${AiBranding.premiumName} is disabled',
                        message:
                            'This build does not currently expose ${AiBranding.premiumName} billing.',
                      );
                    }

                    if (!catalog.billingAvailable || !catalog.hasProducts) {
                      return _ErrorCard(
                        title: 'Billing unavailable',
                        message:
                            catalog.errorMessage ??
                            'Store billing is not available on this device yet.',
                        actionLabel: 'Retry',
                        onTap: () => ref.invalidate(billingCatalogProvider),
                      );
                    }

                    return Column(
                      children: [
                        _PlanCard(
                          plan: AiPremiumPlan.monthly,
                          product: catalog.plan(AiPremiumPlan.monthly)!,
                          isBusy:
                              actionState.actionState ==
                                  PurchaseActionState.purchasing &&
                              actionState.activePlan == AiPremiumPlan.monthly,
                          onTap: () => ref
                              .read(
                                subscriptionManagementControllerProvider
                                    .notifier,
                              )
                              .purchase(AiPremiumPlan.monthly),
                        ),
                        const SizedBox(height: 12),
                        _PlanCard(
                          plan: AiPremiumPlan.annual,
                          product: catalog.plan(AiPremiumPlan.annual)!,
                          highlight: true,
                          isBusy:
                              actionState.actionState ==
                                  PurchaseActionState.purchasing &&
                              actionState.activePlan == AiPremiumPlan.annual,
                          onTap: () => ref
                              .read(
                                subscriptionManagementControllerProvider
                                    .notifier,
                              )
                              .purchase(AiPremiumPlan.annual),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed:
                  actionState.actionState == PurchaseActionState.restoring
                  ? null
                  : () => ref
                        .read(subscriptionManagementControllerProvider.notifier)
                        .restore(),
              icon: const Icon(Icons.restore),
              label: Text(
                actionState.actionState == PurchaseActionState.restoring
                    ? 'Restoring...'
                    : 'Restore Purchases',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.subscriptionManagement,
              ),
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Subscription Status'),
            ),
            const SizedBox(height: 12),
            Text(
              '${AiBranding.premiumName} only unlocks TAIYO features. Physical products in the store and coaching packages use separate non-IAP flows.',
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({this.lockReason});

  final String? lockReason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF132A13), Color(0xFF0F1D3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AiBranding.premiumName,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lockReason?.trim().isNotEmpty == true
                ? lockReason!
                : 'Unlock TAIYO chat and TAIYO-guided plans with verified store billing.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.product,
    required this.onTap,
    this.highlight = false,
    this.isBusy = false,
  });

  final AiPremiumPlan plan;
  final StoreProductView product;
  final VoidCallback onTap;
  final bool highlight;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF1D2C16) : AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: highlight ? AppColors.limeGreen : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlight)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.limeGreen.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(
                'Best value',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.limeGreen,
                ),
              ),
            ),
          if (highlight) const SizedBox(height: 12),
          Text(
            plan == AiPremiumPlan.monthly ? 'Monthly plan' : 'Annual plan',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.priceLabel,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.billingPeriodLabel ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isBusy ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: AppColors.white,
              ),
              child: Text(isBusy ? 'Opening store...' : 'Continue with store'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentSubscriptionCard extends StatelessWidget {
  const _CurrentSubscriptionCard({required this.summary});

  final CurrentSubscriptionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.limeGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current subscription',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            summary.plan == AiPremiumPlan.annual
                ? 'Annual ${AiBranding.premiumName}'
                : 'Monthly ${AiBranding.premiumName}',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.limeGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.entitlement.message ??
                '${AiBranding.premiumName} is active.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (summary.expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Access until ${summary.expiresAt!.toLocal()}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: summary.manageUrl == null
                      ? null
                      : () => ExternalLinkService.openUrl(summary.manageUrl!),
                  child: const Text('Manage in store'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.aiChatHome),
                  child: const Text('Open TAIYO'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.event});

  final BillingInteractionEvent event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.state) {
      PurchaseActionState.synced => AppColors.limeGreen,
      PurchaseActionState.failed => AppColors.error,
      PurchaseActionState.cancelled => AppColors.orange,
      _ => AppColors.electricBlue,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Text(
        event.message ?? '',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
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
            style: GoogleFonts.inter(
              fontSize: 16,
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.message});

  final String title;
  final String message;

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
            style: GoogleFonts.inter(
              fontSize: 16,
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
        ],
      ),
    );
  }
}
