import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../seller/presentation/providers/seller_providers.dart';
import '../../domain/entities/order_entity.dart';
import '../providers/store_providers.dart';
import '../store_ui_utils.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({
    super.key,
    required this.order,
    this.sellerMode = false,
  });

  final OrderEntity order;
  final bool sellerMode;

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool _updatingStatus = false;

  @override
  Widget build(BuildContext context) {
    final orderAsync = widget.sellerMode
        ? ref.watch(sellerOrderDetailsProvider(widget.order.id))
        : ref.watch(myOrderDetailsProvider(widget.order.id));
    final order = orderAsync.valueOrNull ?? widget.order;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Order Details')),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          if (widget.sellerMode) {
            ref.invalidate(sellerOrdersProvider);
            ref.invalidate(sellerOrderDetailsProvider(widget.order.id));
            await ref.read(sellerOrderDetailsProvider(widget.order.id).future);
            return;
          }
          ref.invalidate(myOrdersProvider);
          ref.invalidate(myOrderDetailsProvider(widget.order.id));
          await ref.read(myOrderDetailsProvider(widget.order.id).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            _OrderSummaryCard(order: order, sellerMode: widget.sellerMode),
            const SizedBox(height: 16),
            if (widget.sellerMode &&
                _availableNextStatuses(order.status).isNotEmpty)
              _SellerStatusActions(
                statuses: _availableNextStatuses(order.status),
                loading: _updatingStatus,
                onSelect: (status) => _updateStatus(order, status),
              ),
            if (widget.sellerMode &&
                _availableNextStatuses(order.status).isNotEmpty)
              const SizedBox(height: 16),
            _OrderItemsCard(items: order.items),
            const SizedBox(height: 16),
            _ShippingCard(shippingAddress: order.shippingAddress),
            const SizedBox(height: 16),
            _TimelineCard(entries: order.statusHistory),
            if (orderAsync.hasError) ...[
              const SizedBox(height: 16),
              _InlineMessage(
                message: describeStoreError(
                  orderAsync.error!,
                  fallbackMessage:
                      'GymUnity could not refresh this order right now.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(OrderEntity order, String status) async {
    setState(() => _updatingStatus = true);
    try {
      await ref
          .read(sellerRepositoryProvider)
          .updateOrderStatus(orderId: order.id, newStatus: status);
      ref.invalidate(sellerOrdersProvider);
      ref.invalidate(sellerOrderDetailsProvider(order.id));
      if (!mounted) {
        return;
      }
      showAppFeedback(
        context,
        'Order marked as ${formatOrderStatus(status).toLowerCase()}.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppFeedback(
        context,
        describeStoreError(
          error,
          fallbackMessage: 'Unable to update the order status.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingStatus = false);
      }
    }
  }

  List<String> _availableNextStatuses(String currentStatus) {
    switch (currentStatus) {
      case 'pending':
        return const <String>['paid', 'cancelled'];
      case 'paid':
        return const <String>['processing', 'cancelled'];
      case 'processing':
        return const <String>['shipped', 'cancelled'];
      case 'shipped':
        return const <String>['delivered'];
      default:
        return const <String>[];
    }
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order, required this.sellerMode});

  final OrderEntity order;
  final bool sellerMode;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.id.substring(0, 8).toUpperCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            label: sellerMode ? 'Buyer' : 'Seller',
            value: sellerMode
                ? (order.memberName?.trim().isNotEmpty == true
                      ? order.memberName!
                      : (order.shippingAddress['recipient_name']?.toString() ??
                            'Customer'))
                : (order.sellerName?.trim().isNotEmpty == true
                      ? order.sellerName!
                      : 'Seller'),
          ),
          _SummaryRow(label: 'Date', value: _formatDate(order.createdAt)),
          _SummaryRow(
            label: 'Payment',
            value: order.paymentMethod.toUpperCase(),
          ),
          _SummaryRow(label: 'Items', value: '${order.itemCount}'),
          const Divider(color: AppColors.border, height: 24),
          _SummaryRow(
            label: 'Total',
            value: '${order.currency} ${order.totalAmount.toStringAsFixed(2)}',
            emphasize: true,
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Unknown';
    }
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _SellerStatusActions extends StatelessWidget {
  const _SellerStatusActions({
    required this.statuses,
    required this.loading,
    required this.onSelect,
  });

  final List<String> statuses;
  final bool loading;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update Status',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: statuses
                .map(
                  (status) => ElevatedButton(
                    onPressed: loading ? null : () => onSelect(status),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orderStatusColor(status),
                      foregroundColor: AppColors.white,
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(formatOrderStatus(status)),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _OrderItemsCard extends StatelessWidget {
  const _OrderItemsCard({required this.items});

  final List<OrderItemEntity> items;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              'No order items were returned for this order.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productTitle,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.quantity} x ${item.unitPrice.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.lineTotal.toStringAsFixed(2),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShippingCard extends StatelessWidget {
  const _ShippingCard({required this.shippingAddress});

  final Map<String, dynamic> shippingAddress;

  @override
  Widget build(BuildContext context) {
    final recipient =
        shippingAddress['recipient_name']?.toString() ?? 'Unknown';
    final phone = shippingAddress['phone']?.toString() ?? '';
    final lines = <String>[
      shippingAddress['line1']?.toString() ?? '',
      shippingAddress['line2']?.toString() ?? '',
      shippingAddress['city']?.toString() ?? '',
      shippingAddress['state_region']?.toString() ?? '',
      shippingAddress['postal_code']?.toString() ?? '',
      shippingAddress['country_code']?.toString() ?? '',
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);

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
            'Shipping',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            recipient,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (phone.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                phone,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                lines.join(', '),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entries});

  final List<OrderStatusHistoryEntry> entries;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              'No status history was returned for this order.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: orderStatusColor(entry.status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatOrderStatus(entry.status),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if ((entry.note ?? '').trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                entry.note!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      _formatEntryDate(entry.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatEntryDate(DateTime? value) {
    if (value == null) {
      return '--';
    }
    final local = value.toLocal();
    return '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        formatOrderStatus(status),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: emphasize ? 15 : 13,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              color: emphasize
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: emphasize ? 16 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: emphasize ? AppColors.orange : AppColors.textPrimary,
            ),
          ),
        ],
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
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
      ),
    );
  }
}
