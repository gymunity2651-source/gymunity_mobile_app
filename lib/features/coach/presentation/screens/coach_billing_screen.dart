import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/coach_workspace_entity.dart';
import '../providers/coach_providers.dart';

class CoachBillingScreen extends ConsumerWidget {
  const CoachBillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(coachPaymentQueueProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Billing'),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(coachPaymentQueueProvider);
          await ref.read(coachPaymentQueueProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            Text(
              'Payments & payouts',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConfig.current.enableCoachManualPaymentProofs
                  ? 'Paymob test payments are confirmed by GymUnity webhooks. Legacy manual receipts stay available only for non-Paymob checkouts.'
                  : 'Paymob test payments are confirmed by GymUnity webhooks. Coach payouts are recorded by GymUnity admins after manual settlement.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            queueAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _BillingState(
                icon: Icons.cloud_off_outlined,
                title: 'Billing unavailable',
                body: error.toString(),
                actionLabel: 'Retry',
                onTap: () => ref.invalidate(coachPaymentQueueProvider),
              ),
              data: (receipts) {
                if (receipts.isEmpty) {
                  return const _BillingState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No payment reviews',
                    body:
                        'Awaiting payment and receipt submissions appear here.',
                  );
                }

                const orderedStates = <String>[
                  'awaiting_payment',
                  'payment_pending',
                  'payment_submitted',
                  'receipt_uploaded',
                  'under_verification',
                  'activated',
                  'failed_needs_follow_up',
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: orderedStates
                      .map((state) {
                        final group = receipts
                            .where((receipt) => receipt.billingState == state)
                            .toList(growable: false);
                        if (group.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return _BillingSection(
                          title: state.replaceAll('_', ' '),
                          receipts: group,
                        );
                      })
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingSection extends StatelessWidget {
  const _BillingSection({required this.title, required this.receipts});

  final String title;
  final List<CoachPaymentReceiptEntity> receipts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...receipts.map((receipt) => _ReceiptCard(receipt: receipt)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ReceiptCard extends ConsumerWidget {
  const _ReceiptCard({required this.receipt});

  final CoachPaymentReceiptEntity receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReview =
        AppConfig.current.enableCoachManualPaymentProofs &&
        !receipt.isPaymobPayment &&
        receipt.id.isNotEmpty &&
        receipt.billingState != 'activated' &&
        receipt.billingState != 'failed_needs_follow_up';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: AppColors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  receipt.memberName ?? 'Member',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _BillingBadge(label: receipt.billingState.replaceAll('_', ' ')),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            receipt.packageTitle ?? 'Coaching',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(
                  '${receipt.currency} ${receipt.amount.toStringAsFixed(0)}',
                ),
                visualDensity: VisualDensity.compact,
              ),
              if (receipt.paymentReference != null)
                Chip(
                  label: Text(receipt.paymentReference!),
                  visualDensity: VisualDensity.compact,
                ),
              if (receipt.isPaymobPayment)
                const Chip(
                  label: Text('Paymob TEST'),
                  visualDensity: VisualDensity.compact,
                ),
              if (receipt.paymentOrderStatus != null)
                Chip(
                  label: Text('Order ${receipt.paymentOrderStatus}'),
                  visualDensity: VisualDensity.compact,
                ),
              if (receipt.payoutStatus != null)
                Chip(
                  label: Text('Payout ${receipt.payoutStatus}'),
                  visualDensity: VisualDensity.compact,
                ),
              if (receipt.receiptStoragePath != null)
                const Chip(
                  avatar: Icon(Icons.attach_file, size: 16),
                  label: Text('Receipt uploaded'),
                  visualDensity: VisualDensity.compact,
                ),
              if (receipt.failureReason != null)
                Chip(
                  label: Text(receipt.failureReason!),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  onPressed: () => _openReceiptDetails(context, ref),
                  label: const Text('Details'),
                ),
              ),
              if (canReview) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    onPressed: () async {
                      await ref
                          .read(coachRepositoryProvider)
                          .verifyPayment(receiptId: receipt.id);
                      ref.invalidate(coachPaymentQueueProvider);
                      ref.invalidate(coachWorkspaceSummaryProvider);
                      ref.invalidate(coachClientPipelineProvider);
                    },
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Needs follow-up',
                  onPressed: () => _openFailSheet(context, ref),
                  icon: const Icon(Icons.report_problem_outlined),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openReceiptDetails(BuildContext context, WidgetRef ref) async {
    final audits = await ref
        .read(coachRepositoryProvider)
        .listPaymentAuditTrail(receipt.subscriptionId);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.screenPadding,
          right: AppSizes.screenPadding,
          top: AppSizes.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Receipt details',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            _DetailLine('Member', receipt.memberName ?? 'Member'),
            _DetailLine('Package', receipt.packageTitle ?? 'Coaching'),
            _DetailLine('State', receipt.billingState.replaceAll('_', ' ')),
            _DetailLine('Receipt status', receipt.status.replaceAll('_', ' ')),
            _DetailLine(
              'Amount',
              '${receipt.currency} ${receipt.amount.toStringAsFixed(0)}',
            ),
            if (receipt.paymentReference != null)
              _DetailLine('Reference', receipt.paymentReference!),
            if (receipt.paymentGateway != null)
              _DetailLine('Gateway', receipt.paymentGateway!),
            if (receipt.paymentOrderStatus != null)
              _DetailLine('Payment order', receipt.paymentOrderStatus!),
            if (receipt.payoutStatus != null)
              _DetailLine('Payout', receipt.payoutStatus!),
            if (receipt.receiptStoragePath != null)
              _DetailLine('Receipt path', receipt.receiptStoragePath!),
            if (receipt.failureReason != null)
              _DetailLine('Failure reason', receipt.failureReason!),
            const SizedBox(height: 12),
            Text(
              'Audit trail',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (audits.isEmpty)
              const Text('No audit events yet.')
            else
              ...audits.map(
                (audit) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_outlined),
                  title: Text(audit.newState.replaceAll('_', ' ')),
                  subtitle: Text(
                    audit.note ?? 'Updated by ${audit.actorName ?? 'coach'}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFailSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.screenPadding,
          right: AppSizes.screenPadding,
          top: AppSizes.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment follow-up',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
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
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Reason',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final reason = controller.text.trim();
                  if (reason.isEmpty) return;
                  await ref
                      .read(coachRepositoryProvider)
                      .failPayment(receiptId: receipt.id, reason: reason);
                  ref.invalidate(coachPaymentQueueProvider);
                  ref.invalidate(coachWorkspaceSummaryProvider);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Mark needs follow-up'),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _BillingBadge extends StatelessWidget {
  const _BillingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.orange,
        ),
      ),
    );
  }
}

class _BillingState extends StatelessWidget {
  const _BillingState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onTap != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onTap, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
