import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../../../member/presentation/widgets/member_profile_shortcut_button.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/store_providers.dart';
import '../store_ui_utils.dart';
import '../widgets/store_product_image.dart';

class StoreHomeScreen extends ConsumerStatefulWidget {
  const StoreHomeScreen({super.key});

  @override
  ConsumerState<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends ConsumerState<StoreHomeScreen> {
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
    final categories = ref.watch(storeCategoriesProvider);
    final selectedCategory = ref.watch(selectedStoreCategoryProvider);
    final searchQuery = ref.watch(storeSearchQueryProvider);
    final productsAsync = ref.watch(storeProductsProvider);
    final products = ref.watch(filteredStoreProductsProvider);
    final favoriteIdsAsync = ref.watch(favoriteIdsProvider);
    final favoriteIds = favoriteIdsAsync.valueOrNull ?? const <String>{};
    final cartCount = ref.watch(storeCartCountProvider);

    if (_searchController.text != searchQuery) {
      _searchController.value = TextEditingValue(
        text: searchQuery,
        selection: TextSelection.collapsed(offset: searchQuery.length),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppShellBackground(
          topGlowColor: AppColors.glowOrange,
          bottomGlowColor: AppColors.glowLime,
          child: RefreshIndicator.adaptive(
            onRefresh: () async {
              ref.invalidate(storeProductsProvider);
              ref.invalidate(favoriteIdsProvider);
              ref.invalidate(storeCartControllerProvider);
              await ref.read(storeCartControllerProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GymUnity Store',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Real products, real stock, persistent cart and orders.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.favorites),
                      icon: const Icon(Icons.favorite_border),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.cart),
                          icon: const Icon(Icons.shopping_bag_outlined),
                        ),
                        if (cartCount > 0)
                          Positioned(
                            right: 2,
                            top: 2,
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
                    const SizedBox(width: 4),
                    const MemberProfileShortcutButton(),
                  ],
                ),
                const SizedBox(height: 18),
                _StoreHeroCard(
                  productCount: products.length,
                  cartCount: cartCount,
                ),
                const SizedBox(height: 18),
                SearchBar(
                  controller: _searchController,
                  hintText: 'Search products',
                  onChanged: (value) =>
                      ref.read(storeSearchQueryProvider.notifier).state = value,
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (searchQuery.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _searchController.clear();
                          ref.read(storeSearchQueryProvider.notifier).state =
                              '';
                        },
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final selected = selectedCategory == index;
                      return ChoiceChip(
                        label: Text(categories[index]),
                        selected: selected,
                        onSelected: (_) {
                          ref
                                  .read(selectedStoreCategoryProvider.notifier)
                                  .state =
                              index;
                        },
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemCount: categories.length,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.orders),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('My Orders'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.productList),
                        icon: const Icon(Icons.grid_view_outlined),
                        label: const Text('Browse All'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                productsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => _StoreMessageState(
                    message: describeStoreError(
                      error,
                      fallbackMessage:
                          'GymUnity could not load store products right now.',
                    ),
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(storeProductsProvider),
                  ),
                  data: (_) {
                    if (products.isEmpty) {
                      return _StoreMessageState(
                        message: searchQuery.trim().isNotEmpty
                            ? 'No products matched your search.'
                            : 'No active store products are available right now.',
                      );
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.64,
                          ),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _ProductCard(
                          product: product,
                          isFavorite: favoriteIds.contains(product.id),
                          onOpen: () => Navigator.pushNamed(
                            context,
                            AppRoutes.productDetails,
                            arguments: product,
                          ),
                          onFavorite: () => _toggleFavorite(product),
                          onAddToCart: () => _addToCart(product),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isFavorite,
    required this.onOpen,
    required this.onFavorite,
    required this.onAddToCart,
  });

  final ProductEntity product;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.cardDark.withValues(alpha: 0.98),
              AppColors.surfacePanel.withValues(alpha: 0.96),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: AppColors.borderLight.withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                StoreProductImage(
                  product: product,
                  width: double.infinity,
                  height: 120,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: InkWell(
                    onTap: onFavorite,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.cardDark.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite
                            ? AppColors.orange
                            : AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(
                '${product.currency} ${product.price.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orangeLight,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!product.isAvailable)
              Text(
                'Unavailable',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              )
            else if (product.isLowStock)
              Text(
                'Only ${product.stockQty} left',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                ),
              )
            else
              Text(
                '${product.stockQty} available',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: product.isAvailable ? onAddToCart : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(double.infinity, 46),
                ),
                child: const Text('Add to cart'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreHeroCard extends StatelessWidget {
  const _StoreHeroCard({required this.productCount, required this.cartCount});

  final int productCount;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
        border: Border.all(color: AppColors.borderSoft.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardDark.withValues(alpha: 0.97),
            AppColors.surfacePanel.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: const [
              _StoreHeroPill(
                label: 'Verified flow',
                color: AppColors.limeGreen,
              ),
              _StoreHeroPill(label: 'Persistent cart', color: AppColors.aqua),
              _StoreHeroPill(
                label: 'Low-noise layout',
                color: AppColors.orangeLight,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Text(
            'Browse faster, compare cleaner, and keep the buying flow easy to trust.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.08,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            'The store now emphasizes product imagery, price clarity, and the actions people actually need first.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Row(
            children: [
              Expanded(
                child: _StoreHeroStat(
                  label: 'Visible products',
                  value: '$productCount live',
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: _StoreHeroStat(
                  label: 'Items in cart',
                  value: cartCount == 1 ? '1 item' : '$cartCount items',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoreHeroPill extends StatelessWidget {
  const _StoreHeroPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _StoreHeroStat extends StatelessWidget {
  const _StoreHeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreMessageState extends StatelessWidget {
  const _StoreMessageState({
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
