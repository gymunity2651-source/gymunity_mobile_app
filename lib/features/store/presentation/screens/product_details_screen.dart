import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/store_providers.dart';
import '../store_ui_utils.dart';
import '../widgets/store_product_image.dart';

class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({super.key, this.product});

  final ProductEntity? product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (product == null) {
      return const _UnavailableProductScreen();
    }

    final productAsync = ref.watch(storeProductDetailsProvider(product!.id));
    final favoriteIds =
        ref.watch(favoriteIdsProvider).valueOrNull ?? const <String>{};
    final cartCount = ref.watch(storeCartCountProvider);
    final currentProduct = productAsync.valueOrNull ?? product!;
    final isFavorite = favoriteIds.contains(currentProduct.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.favorites),
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? AppColors.orange : null,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.cart),
                icon: const Icon(Icons.shopping_bag_outlined),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$cartCount',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async =>
            ref.refresh(storeProductDetailsProvider(product!.id).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            StoreProductImage(
              product: currentProduct,
              width: double.infinity,
              height: 260,
              borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
            ),
            const SizedBox(height: 20),
            Text(
              currentProduct.name,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentProduct.category,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${currentProduct.currency} ${currentProduct.price.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.orange,
              ),
            ),
            const SizedBox(height: 16),
            _MetaRow(
              label: 'Availability',
              value: currentProduct.isAvailable
                  ? '${currentProduct.stockQty} in stock'
                  : 'Currently unavailable',
              valueColor: currentProduct.isAvailable
                  ? AppColors.textPrimary
                  : AppColors.error,
            ),
            if (currentProduct.isLowStock && currentProduct.isAvailable)
              _MetaRow(
                label: 'Low stock',
                value: 'Only ${currentProduct.stockQty} units left',
                valueColor: AppColors.orange,
              ),
            const SizedBox(height: 18),
            Text(
              currentProduct.description.trim().isEmpty
                  ? 'No product description was provided for this listing.'
                  : currentProduct.description,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (productAsync.hasError) ...[
              const SizedBox(height: 14),
              Text(
                describeStoreError(
                  productAsync.error!,
                  fallbackMessage:
                      'GymUnity could not refresh this product right now.',
                ),
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final next = await ref
                            .read(favoriteIdsProvider.notifier)
                            .toggle(currentProduct);
                        if (!context.mounted) {
                          return;
                        }
                        showAppFeedback(
                          context,
                          next
                              ? '${currentProduct.name} added to favorites.'
                              : '${currentProduct.name} removed from favorites.',
                        );
                      } catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        showAppFeedback(
                          context,
                          describeStoreError(
                            error,
                            fallbackMessage: 'Unable to update your favorites.',
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                    label: Text(isFavorite ? 'Saved' : 'Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: currentProduct.isAvailable
                        ? () async {
                            try {
                              await ref
                                  .read(storeCartControllerProvider.notifier)
                                  .add(currentProduct);
                              if (!context.mounted) {
                                return;
                              }
                              showAppFeedback(
                                context,
                                '${currentProduct.name} added to your cart.',
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
                                      'Unable to update your cart.',
                                ),
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Add to cart'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 14, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableProductScreen extends StatelessWidget {
  const _UnavailableProductScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Text(
            'This route was opened without a product payload.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
