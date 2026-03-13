import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/cart_entity.dart';
import '../providers/store_providers.dart';
import '../store_ui_utils.dart';
import '../widgets/store_product_image.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(storeCartControllerProvider);
    final total = ref.watch(storeCartTotalProvider);
    final hasInvalidItems = ref.watch(storeHasInvalidCartItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Your Cart')),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.refresh(storeCartControllerProvider.future),
        child: cartAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _CartStateMessage(
            message: describeStoreError(
              error,
              fallbackMessage: 'GymUnity could not load your cart right now.',
            ),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(storeCartControllerProvider),
          ),
          data: (cart) {
            if (cart.isEmpty) {
              return _CartStateMessage(
                message:
                    'Your cart is empty. Add products from the store to start checkout.',
                actionLabel: 'Continue Shopping',
                onAction: () => Navigator.pop(context),
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              children: [
                if (hasInvalidItems)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Some cart items are no longer purchasable or exceed current stock.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(storeCartControllerProvider.notifier)
                                  .clearInvalidItems();
                              if (!context.mounted) {
                                return;
                              }
                              showAppFeedback(
                                context,
                                'Your cart was updated to match current stock.',
                              );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              showAppFeedback(
                                context,
                                describeStoreError(
                                  error,
                                  fallbackMessage:
                                      'Unable to repair your cart right now.',
                                ),
                              );
                            }
                          },
                          child: const Text('Fix Cart Issues'),
                        ),
                      ],
                    ),
                  ),
                ...cart.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CartItemTile(item: item),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(label: 'Items', value: '${cart.itemCount}'),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        label: 'Subtotal',
                        value: total.toStringAsFixed(2),
                      ),
                      const SizedBox(height: 10),
                      const _SummaryRow(label: 'Payment', value: 'Manual'),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(color: AppColors.border),
                      ),
                      _SummaryRow(
                        label: 'Total',
                        value: total.toStringAsFixed(2),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: cartAsync.valueOrNull?.isEmpty ?? true
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                8,
                AppSizes.screenPadding,
                16,
              ),
              child: ElevatedButton(
                onPressed: hasInvalidItems
                    ? null
                    : () => Navigator.pushNamed(context, AppRoutes.checkout),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Proceed to checkout'),
              ),
            ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final CartItemEntity item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          StoreProductImage(product: item.product, width: 72, height: 72),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.product.currency} ${item.lineTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
                if (item.isUnavailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Unavailable. Remove this item before checkout.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  )
                else if (item.exceedsStock)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Only ${item.product.stockQty} available right now.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: () => _updateQuantity(
                      context,
                      ref,
                      item.product.id,
                      item.quantity - 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${item.quantity}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: item.product.stockQty <= item.quantity
                        ? null
                        : () => _updateQuantity(
                            context,
                            ref,
                            item.product.id,
                            item.quantity + 1,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(storeCartControllerProvider.notifier)
                        .remove(item.product.id);
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    showAppFeedback(
                      context,
                      describeStoreError(
                        error,
                        fallbackMessage:
                            'Unable to remove the item from your cart.',
                      ),
                    );
                  }
                },
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateQuantity(
    BuildContext context,
    WidgetRef ref,
    String productId,
    int quantity,
  ) async {
    try {
      await ref
          .read(storeCartControllerProvider.notifier)
          .updateQuantity(productId, quantity);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppFeedback(
        context,
        describeStoreError(
          error,
          fallbackMessage: 'Unable to update your cart.',
        ),
      );
    }
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.fieldFill : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 18),
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
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: emphasize ? 16 : 14,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: emphasize ? 18 : 14,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: emphasize ? AppColors.orange : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _CartStateMessage extends StatelessWidget {
  const _CartStateMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        const SizedBox(height: 80),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 14),
          Center(
            child: ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
