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

class StoreCatalogScreen extends ConsumerStatefulWidget {
  const StoreCatalogScreen({super.key});

  @override
  ConsumerState<StoreCatalogScreen> createState() => _StoreCatalogScreenState();
}

class _StoreCatalogScreenState extends ConsumerState<StoreCatalogScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(storeSearchQueryProvider);
    final productsAsync = ref.watch(storeProductsProvider);
    final products = ref.watch(filteredStoreProductsProvider);
    final favoriteIds =
        ref.watch(favoriteIdsProvider).valueOrNull ?? const <String>{};

    if (_searchController.text != searchQuery) {
      _searchController.value = TextEditingValue(
        text: searchQuery,
        selection: TextSelection.collapsed(offset: searchQuery.length),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('All Products')),
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.refresh(storeProductsProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            SearchBar(
              controller: _searchController,
              hintText: 'Search the catalog',
              onChanged: (value) =>
                  ref.read(storeSearchQueryProvider.notifier).state = value,
              leading: const Icon(Icons.search),
              trailing: [
                if (searchQuery.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _searchController.clear();
                      ref.read(storeSearchQueryProvider.notifier).state = '';
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            productsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => _CatalogMessage(
                message: describeStoreError(
                  error,
                  fallbackMessage:
                      'GymUnity could not load the catalog right now.',
                ),
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(storeProductsProvider),
              ),
              data: (_) {
                if (products.isEmpty) {
                  return _CatalogMessage(
                    message: searchQuery.trim().isNotEmpty
                        ? 'No products matched your search.'
                        : 'No active store products are available right now.',
                  );
                }

                return Column(
                  children: products
                      .map(
                        (product) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CatalogTile(
                            product: product,
                            isFavorite: favoriteIds.contains(product.id),
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.productDetails,
                              arguments: product,
                            ),
                            onFavorite: () => _toggleFavorite(product),
                            onAddToCart: () => _addToCart(product),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(ProductEntity product) async {
    try {
      final isFavorite = await ref
          .read(favoriteIdsProvider.notifier)
          .toggle(product);
      if (!mounted) {
        return;
      }
      showAppFeedback(
        context,
        isFavorite
            ? '${product.name} added to favorites.'
            : '${product.name} removed from favorites.',
      );
    } catch (error) {
      if (!mounted) {
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
  }

  Future<void> _addToCart(ProductEntity product) async {
    try {
      await ref.read(storeCartControllerProvider.notifier).add(product);
      if (!mounted) {
        return;
      }
      showAppFeedback(context, '${product.name} added to your cart.');
    } catch (error) {
      if (!mounted) {
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

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.product,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    required this.onAddToCart,
  });

  final ProductEntity product;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            StoreProductImage(product: product, width: 72, height: 72),
            const SizedBox(width: 14),
            Expanded(
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
                        'Currently unavailable',
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
                IconButton(
                  onPressed: onFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? AppColors.orange
                        : AppColors.textSecondary,
                  ),
                ),
                IconButton(
                  onPressed: product.isAvailable ? onAddToCart : null,
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
