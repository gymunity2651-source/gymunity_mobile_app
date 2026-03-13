import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../providers/store_providers.dart';
import '../store_ui_utils.dart';
import '../widgets/store_product_image.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteProductsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Favorites')),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(favoriteIdsProvider);
          ref.invalidate(favoriteProductsProvider);
          await ref.read(favoriteProductsProvider.future);
        },
        child: favoritesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _MessageState(
            message: describeStoreError(
              error,
              fallbackMessage:
                  'GymUnity could not load your favorites right now.',
            ),
            actionLabel: 'Retry',
            onAction: () {
              ref.invalidate(favoriteIdsProvider);
              ref.invalidate(favoriteProductsProvider);
            },
          ),
          data: (products) {
            if (products.isEmpty) {
              return const _MessageState(
                message:
                    'You have not saved any products yet. Favorite items from the store to keep them here.',
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
                            AppRoutes.productDetails,
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
                                product.category,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${product.currency} ${product.price.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.orange,
                                ),
                              ),
                              if (!product.isAvailable)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'This product is currently unavailable.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(favoriteIdsProvider.notifier)
                                    .toggle(product);
                                if (!context.mounted) {
                                  return;
                                }
                                showAppFeedback(
                                  context,
                                  '${product.name} removed from favorites.',
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
                                        'Unable to update your favorites.',
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.favorite,
                              color: AppColors.orange,
                            ),
                          ),
                          IconButton(
                            onPressed: product.isAvailable
                                ? () async {
                                    try {
                                      await ref
                                          .read(
                                            storeCartControllerProvider
                                                .notifier,
                                          )
                                          .add(product);
                                      if (!context.mounted) {
                                        return;
                                      }
                                      showAppFeedback(
                                        context,
                                        '${product.name} added to your cart.',
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
                            icon: const Icon(
                              Icons.add_shopping_cart_outlined,
                              color: AppColors.textPrimary,
                            ),
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

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, this.actionLabel, this.onAction});

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
