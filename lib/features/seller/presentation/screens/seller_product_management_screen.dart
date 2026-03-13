import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../store/presentation/providers/store_providers.dart';
import '../../../store/presentation/widgets/store_product_image.dart';
import '../providers/seller_providers.dart';

class SellerProductManagementScreen extends ConsumerWidget {
  const SellerProductManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(sellerProductsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Product Management'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.addProduct),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.refresh(sellerProductsProvider.future),
        child: productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _ProductsMessageState(
            message: 'GymUnity could not load your products right now.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(sellerProductsProvider),
          ),
          data: (products) {
            if (products.isEmpty) {
              return _ProductsMessageState(
                message:
                    'No seller products exist yet. Add your first product to populate the store catalog.',
                actionLabel: 'Add Product',
                onAction: () =>
                    Navigator.pushNamed(context, AppRoutes.addProduct),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final product = products[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      StoreProductImage(
                        product: product,
                        width: 72,
                        height: 72,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.editProduct,
                            arguments: product,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${product.currency} ${product.price.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orange,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Stock: ${product.stockQty} • ${product.isActive ? 'Active' : 'Archived'}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: product.isActive
                                      ? AppColors.textSecondary
                                      : AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.editProduct,
                              arguments: product,
                            );
                            return;
                          }

                          try {
                            final deleted = await ref
                                .read(sellerRepositoryProvider)
                                .deleteOrArchiveProduct(product.id);
                            ref.invalidate(sellerProductsProvider);
                            ref.invalidate(storeProductsProvider);
                            if (!context.mounted) {
                              return;
                            }
                            showAppFeedback(
                              context,
                              deleted
                                  ? '${product.name} was deleted.'
                                  : '${product.name} was archived because previous orders exist.',
                            );
                          } catch (_) {
                            if (!context.mounted) {
                              return;
                            }
                            showAppFeedback(
                              context,
                              'Unable to remove the product right now.',
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete or Archive'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProductsMessageState extends StatelessWidget {
  const _ProductsMessageState({
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
