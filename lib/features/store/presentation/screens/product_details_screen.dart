import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/product_entity.dart';
import '../providers/store_providers.dart';

class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({super.key, this.product});

  final ProductEntity? product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProduct =
        product ??
        const ProductEntity(
          id: 'preview',
          name: 'GymUnity Product Preview',
          category: 'Equipment',
          price: 0,
        );
    final isWishlisted = ref.watch(storeWishlistProvider).contains(
      selectedProduct.id,
    );
    final cartCount = ref.watch(storeCartCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.cart),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.textPrimary,
                            size: 24,
                          ),
                          if (cartCount > 0)
                            Positioned(
                              right: -8,
                              top: -8,
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
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.screenPadding,
                ),
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Icon(
                      _iconForCategory(selectedProduct.category),
                      size: 96,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Text(
                        selectedProduct.category.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      selectedProduct.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '\$${selectedProduct.price.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.orange,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.limeGreen.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusFull,
                            ),
                          ),
                          child: Text(
                            'In stock',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.limeGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _descriptionFor(selectedProduct),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.55,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Why users pick this',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._benefitsFor(selectedProduct.category).map(
                      (benefit) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_circle,
                                color: AppColors.limeGreen,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                benefit,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          10,
          AppSizes.screenPadding,
          16,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(storeWishlistProvider.notifier).toggle(selectedProduct);
                  final nextValue = ref
                      .read(storeWishlistProvider)
                      .contains(selectedProduct.id);
                  showAppFeedback(
                    context,
                    nextValue
                        ? '${selectedProduct.name} saved to wishlist.'
                        : '${selectedProduct.name} removed from wishlist.',
                  );
                },
                icon: Icon(
                  isWishlisted ? Icons.favorite : Icons.favorite_border,
                ),
                label: Text(isWishlisted ? 'Saved' : 'Wishlist'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(storeCartProvider.notifier).add(selectedProduct);
                  showAppFeedback(
                    context,
                    '${selectedProduct.name} added to your cart.',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.white,
                ),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Add to cart'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'supplements':
        return Icons.local_drink_outlined;
      case 'equipment':
        return Icons.fitness_center;
      case 'apparel':
        return Icons.checkroom_outlined;
      case 'accessories':
        return Icons.watch_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  static String _descriptionFor(ProductEntity product) {
    final category = product.category.trim().toLowerCase();
    switch (category) {
      case 'supplements':
        return 'Built for consistent training days with straightforward nutrition support, clean packaging, and a formula that fits a performance-first routine.';
      case 'equipment':
        return 'Designed for daily use, home setups, and serious sessions without sacrificing grip, balance, or durability.';
      case 'apparel':
        return 'Comfortable enough for all-day wear and dependable enough for high-output workouts, warmups, and recovery sessions.';
      case 'accessories':
        return 'A practical upgrade for athletes who want cleaner tracking, easier carry, and less friction between workouts.';
      default:
        return 'A curated GymUnity product picked to make training more consistent, easier to manage, and more enjoyable week after week.';
    }
  }

  static List<String> _benefitsFor(String category) {
    switch (category.trim().toLowerCase()) {
      case 'supplements':
        return const [
          'Easy to fit into a structured training plan.',
          'Clear performance value without unnecessary complexity.',
          'Good option when you want repeatable results and fast replenishment.',
        ];
      case 'equipment':
        return const [
          'Supports home or gym sessions with minimal setup time.',
          'Reliable enough for repeated use across the week.',
          'Pairs well with guided plans from coaches and AI workouts.',
        ];
      case 'apparel':
        return const [
          'Moves well during strength, cardio, and hybrid sessions.',
          'Helps keep focus on the workout instead of the fit.',
          'Works across training, recovery, and casual daily use.',
        ];
      case 'accessories':
        return const [
          'Reduces friction around tracking, recovery, or gym carry.',
          'Adds convenience without adding clutter to the routine.',
          'Useful for users building more disciplined training habits.',
        ];
      default:
        return const [
          'Chosen to support a smoother training routine.',
          'Simple enough for daily use and consistent habits.',
          'Works well alongside the rest of the GymUnity member flow.',
        ];
    }
  }
}
