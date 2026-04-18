import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../coach/domain/entities/subscription_entity.dart';
import '../providers/member_providers.dart';

class MySubscriptionsScreen extends ConsumerWidget {
  const MySubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(memberSubscriptionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Coaching'),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(memberSubscriptionsProvider);
          await ref.read(memberSubscriptionsProvider.future);
        },
        child: subscriptionsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.orange),
          ),
          error: (error, _) => _SubscriptionsState(
            title: 'Unable to load subscriptions',
            description: error.toString(),
            actionLabel: 'Retry',
            onTap: () => ref.invalidate(memberSubscriptionsProvider),
          ),
          data: (subscriptions) {
            if (subscriptions.isEmpty) {
              return _SubscriptionsState(
                title: 'No coaching yet',
                description:
                    'Browse the coach marketplace, start a paid checkout, and your subscriptions will appear here.',
                actionLabel: 'Browse Coaches',
                onTap: () => Navigator.pushNamed(context, AppRoutes.coaches),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              children: [
                Text(
                  'Your live coaching relationships',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track checkout, renewals, pause status, and jump straight to messages or weekly check-ins.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                ...subscriptions.map(
                  (subscription) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SubscriptionCard(subscription: subscription),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.subscription});

  final SubscriptionEntity subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(18),
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
                      subscription.coachName ?? 'Coach',
                      style: GoogleFonts.inter(
                        fontSize: 18,
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
              _StatusBadge(label: subscription.status.replaceAll('_', ' ')),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(label: 'EGP ${subscription.amount.toStringAsFixed(0)}'),
              if (subscription.billingCycle.isNotEmpty)
                _MiniChip(
                  label: subscription.billingCycle.replaceAll('_', ' '),
                ),
              if (subscription.responseSlaHours != null)
                _MiniChip(label: '~${subscription.responseSlaHours}h reply'),
              if (subscription.nextRenewalAt != null)
                _MiniChip(
                  label:
                      'Renews ${subscription.nextRenewalAt!.toLocal().toString().split(' ').first}',
                ),
            ],
          ),
          if (subscription.isCheckoutPending) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmPayment(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('I paid, activate now'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: subscription.hasMessageThread
                        ? () => Navigator.pushNamed(
                            context,
                            AppRoutes.memberMessages,
                          )
                        : null,
                    child: const Text('Messages'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.memberCheckins),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Check-ins'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: subscription.canPause
                  ? () => _togglePause(context, ref)
                  : null,
              child: Text(
                subscription.isPaused
                    ? 'Resume subscription'
                    : 'Pause subscription',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmPayment(BuildContext context, WidgetRef ref) async {
    await ref
        .read(memberRepositoryProvider)
        .confirmCoachPayment(subscriptionId: subscription.id);
    ref.invalidate(memberSubscriptionsProvider);
    ref.invalidate(memberCoachingThreadsProvider);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment confirmed and coaching activated.'),
      ),
    );
  }

  Future<void> _togglePause(BuildContext context, WidgetRef ref) async {
    await ref
        .read(memberRepositoryProvider)
        .pauseSubscription(
          subscriptionId: subscription.id,
          pauseNow: !subscription.isPaused,
        );
    ref.invalidate(memberSubscriptionsProvider);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          subscription.isPaused
              ? 'Subscription resumed.'
              : 'Subscription paused.',
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.orangeLight,
        ),
      ),
    );
  }
}

class _SubscriptionsState extends StatelessWidget {
  const _SubscriptionsState({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 26)),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onTap, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
