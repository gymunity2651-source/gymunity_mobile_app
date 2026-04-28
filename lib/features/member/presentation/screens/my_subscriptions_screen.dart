import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/services/external_link_service.dart';
import '../../../coach/domain/entities/subscription_entity.dart';
import '../../../coach/presentation/providers/coach_providers.dart';
import '../../../coach_member_insights/presentation/providers/insight_providers.dart';
import '../../domain/entities/coaching_engagement_entity.dart';
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
              _StatusBadge(label: subscription.billingStatusLabel),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(
                label:
                    '${subscription.currency} ${subscription.amount.toStringAsFixed(0)}',
              ),
              if (subscription.isPaymobPayment)
                const _MiniChip(label: 'TEST PAYMENT'),
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
            if (subscription.isPaymobPayment)
              _paymobPaymentActions(context, ref)
            else if (AppConfig.current.enableCoachManualPaymentProofs)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _confirmPayment(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text('Submit payment proof'),
                ),
              )
            else
              _PaymentNotice(
                title: 'Payment pending',
                body:
                    'Manual payment proof is disabled. Refresh after GymUnity confirms this checkout.',
                actionLabel: 'Refresh status',
                onTap: () {
                  ref.invalidate(memberSubscriptionsProvider);
                  ref.invalidate(memberCoachingThreadsProvider);
                },
              ),
          ] else ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.myCoach,
                  arguments: subscription.id,
                ),
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.white,
                ),
                label: const Text('Open Coach Hub'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: subscription.hasMessageThread
                        ? () => Navigator.pushNamed(
                            context,
                            AppRoutes.memberThread,
                            arguments: CoachingThreadEntity(
                              id: subscription.threadId!,
                              subscriptionId: subscription.id,
                              memberId: subscription.memberId,
                              coachId: subscription.coachId,
                              coachName: subscription.coachName,
                              packageTitle: subscription.displayTitle,
                              subscriptionStatus: subscription.status,
                            ),
                          )
                        : null,
                    child: const Text('Messages'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.memberCheckins),
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
            if (subscription.status == 'active') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.memberCoachVisibility,
                      arguments: VisibilitySettingsArgs(
                        subscriptionId: subscription.id,
                        coachId: subscription.coachId,
                        coachName: subscription.coachName ?? 'Coach',
                      ),
                    );
                  },
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: const Text('Privacy Settings'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _paymobPaymentActions(BuildContext context, WidgetRef ref) {
    final isFailed = subscription.checkoutStatus == 'failed';
    return _PaymentNotice(
      title: isFailed ? 'Payment was not completed' : 'Payment pending',
      body: isFailed
          ? 'Start a new TEST PAYMENT checkout or refresh if you completed it in Paymob.'
          : 'Paymob is confirming this TEST PAYMENT through GymUnity. Messages and check-ins unlock after the verified callback activates your subscription.',
      actionLabel: isFailed ? 'Retry payment' : 'Refresh status',
      onTap: () async {
        if (isFailed && subscription.packageId != null) {
          final session = await ref
              .read(coachPaymentRepositoryProvider)
              .createPaymobCheckout(
                packageId: subscription.packageId!,
                coachId: subscription.coachId,
                intakeSnapshot: subscription.intakeSnapshot,
                note: subscription.memberNote,
              );
          await ExternalLinkService.openUrl(session.checkoutUrl);
          ref.invalidate(paymentOrderProvider(session.paymentOrderId));
        }
        ref.invalidate(memberSubscriptionsProvider);
        ref.invalidate(memberCoachingThreadsProvider);
      },
    );
  }

  Future<void> _confirmPayment(BuildContext context, WidgetRef ref) async {
    final referenceController = TextEditingController();
    PlatformFile? pickedFile;
    var submitted = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppSizes.screenPadding,
              right: AppSizes.screenPadding,
              top: AppSizes.lg,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Payment proof',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Payment reference',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      allowMultiple: false,
                      withData: true,
                      type: FileType.custom,
                      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
                    );
                    setSheetState(() => pickedFile = result?.files.single);
                  },
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: Text(pickedFile?.name ?? 'Upload receipt'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final repo = ref.read(memberRepositoryProvider);
                      String? receiptPath;
                      final bytes = pickedFile?.bytes;
                      if (pickedFile != null && bytes != null) {
                        receiptPath = await repo.uploadCoachPaymentReceipt(
                          subscriptionId: subscription.id,
                          bytes: bytes,
                          fileName: pickedFile!.name,
                        );
                      }
                      await repo.submitCoachPaymentReceipt(
                        subscriptionId: subscription.id,
                        paymentReference:
                            referenceController.text.trim().isEmpty
                            ? null
                            : referenceController.text.trim(),
                        receiptStoragePath: receiptPath,
                        amount: subscription.amount,
                      );
                      submitted = true;
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Submit for verification'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    referenceController.dispose();
    if (!submitted) {
      return;
    }
    ref.invalidate(memberSubscriptionsProvider);
    ref.invalidate(memberCoachingThreadsProvider);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment proof submitted for coach verification.'),
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

class _PaymentNotice extends StatelessWidget {
  const _PaymentNotice({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: onTap, child: Text(actionLabel)),
          ),
        ],
      ),
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
