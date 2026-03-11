import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/product_entity.dart';
import '../models/store_cart_item.dart';

final selectedStoreCategoryProvider = StateProvider<int>((ref) => 0);
final storeSearchQueryProvider = StateProvider<String>((ref) => '');

final storeCategoriesProvider = Provider<List<String>>(
  (ref) => <String>['All', 'Supplements', 'Equipment', 'Apparel', 'Accessories'],
);

final storeProductsProvider = FutureProvider<List<ProductEntity>>((ref) async {
  final categories = ref.watch(storeCategoriesProvider);
  final selectedIndex = ref.watch(selectedStoreCategoryProvider);
  final selectedCategory = categories[selectedIndex];
  final repo = ref.watch(storeRepositoryProvider);
  final paged = await repo.listProducts(category: selectedCategory);
  return paged.items;
});

final filteredStoreProductsProvider = Provider<List<ProductEntity>>((ref) {
  final products = ref.watch(storeProductsProvider).valueOrNull ?? const [];
  final query = ref.watch(storeSearchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) {
    return products;
  }

  return products.where((product) {
    return product.name.toLowerCase().contains(query) ||
        product.category.toLowerCase().contains(query);
  }).toList();
});

class StoreWishlistController extends StateNotifier<Set<String>> {
  StoreWishlistController() : super(<String>{});

  void toggle(ProductEntity product) {
    final next = Set<String>.from(state);
    if (!next.add(product.id)) {
      next.remove(product.id);
    }
    state = next;
  }
}

final storeWishlistProvider =
    StateNotifierProvider<StoreWishlistController, Set<String>>((ref) {
      return StoreWishlistController();
    });

class StoreCartController extends StateNotifier<Map<String, StoreCartItem>> {
  StoreCartController() : super(const <String, StoreCartItem>{});

  void add(ProductEntity product, {int quantity = 1}) {
    final next = Map<String, StoreCartItem>.from(state);
    final existing = next[product.id];
    next[product.id] = existing == null
        ? StoreCartItem(product: product, quantity: quantity)
        : existing.copyWith(quantity: existing.quantity + quantity);
    state = next;
  }

  void updateQuantity(String productId, int quantity) {
    if (!state.containsKey(productId)) {
      return;
    }
    if (quantity <= 0) {
      remove(productId);
      return;
    }

    final next = Map<String, StoreCartItem>.from(state);
    next[productId] = next[productId]!.copyWith(quantity: quantity);
    state = next;
  }

  void remove(String productId) {
    if (!state.containsKey(productId)) {
      return;
    }
    final next = Map<String, StoreCartItem>.from(state);
    next.remove(productId);
    state = next;
  }

  void clear() {
    state = const <String, StoreCartItem>{};
  }
}

final storeCartProvider =
    StateNotifierProvider<StoreCartController, Map<String, StoreCartItem>>((
      ref,
    ) {
      return StoreCartController();
    });

final storeCartItemsProvider = Provider<List<StoreCartItem>>((ref) {
  return ref.watch(storeCartProvider).values.toList();
});

final storeCartCountProvider = Provider<int>((ref) {
  return ref
      .watch(storeCartItemsProvider)
      .fold<int>(0, (total, item) => total + item.quantity);
});

final storeCartTotalProvider = Provider<double>((ref) {
  return ref
      .watch(storeCartItemsProvider)
      .fold<double>(0, (total, item) => total + item.lineTotal);
});
