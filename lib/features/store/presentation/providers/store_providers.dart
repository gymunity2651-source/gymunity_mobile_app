import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/cart_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/shipping_address_entity.dart';

final selectedStoreCategoryProvider = StateProvider<int>((ref) => 0);
final storeSearchQueryProvider = StateProvider<String>((ref) => '');

final storeCategoriesProvider = Provider<List<String>>(
  (ref) => <String>[
    'All',
    'Supplements',
    'Equipment',
    'Apparel',
    'Accessories',
  ],
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

  return products
      .where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.category.toLowerCase().contains(query) ||
            product.description.toLowerCase().contains(query);
      })
      .toList(growable: false);
});

final storeProductDetailsProvider =
    FutureProvider.family<ProductEntity?, String>((ref, productId) async {
      final repo = ref.watch(storeRepositoryProvider);
      return repo.getProductById(productId);
    });

class FavoriteIdsController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() {
    return ref.read(storeRepositoryProvider).getFavoriteIds();
  }

  Future<bool> toggle(ProductEntity product) async {
    final repo = ref.read(storeRepositoryProvider);
    final nextValue = await repo.toggleFavorite(product);
    state = await AsyncValue.guard(repo.getFavoriteIds);
    ref.invalidate(favoriteProductsProvider);
    return nextValue;
  }
}

final favoriteIdsProvider =
    AsyncNotifierProvider<FavoriteIdsController, Set<String>>(
      FavoriteIdsController.new,
    );

final favoriteProductsProvider = FutureProvider<List<ProductEntity>>((
  ref,
) async {
  ref.watch(favoriteIdsProvider);
  final repo = ref.watch(storeRepositoryProvider);
  return repo.getFavoriteProducts();
});

class StoreCartController extends AsyncNotifier<CartEntity> {
  @override
  Future<CartEntity> build() {
    return ref.read(storeRepositoryProvider).getCart();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(storeRepositoryProvider).getCart(),
    );
  }

  Future<void> add(ProductEntity product, {int quantity = 1}) async {
    state = await AsyncValue.guard(
      () => ref
          .read(storeRepositoryProvider)
          .addToCart(product: product, quantity: quantity),
    );
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    state = await AsyncValue.guard(
      () => ref
          .read(storeRepositoryProvider)
          .updateCartQuantity(productId: productId, quantity: quantity),
    );
  }

  Future<void> remove(String productId) async {
    state = await AsyncValue.guard(
      () => ref.read(storeRepositoryProvider).removeCartItem(productId),
    );
  }

  Future<void> clearInvalidItems() async {
    state = await AsyncValue.guard(
      () => ref.read(storeRepositoryProvider).clearInvalidCartItems(),
    );
  }
}

final storeCartControllerProvider =
    AsyncNotifierProvider<StoreCartController, CartEntity>(
      StoreCartController.new,
    );

final storeCartItemsProvider = Provider<List<CartItemEntity>>((ref) {
  return ref.watch(storeCartControllerProvider).valueOrNull?.items ??
      const <CartItemEntity>[];
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

final storeHasInvalidCartItemsProvider = Provider<bool>((ref) {
  final cart = ref.watch(storeCartControllerProvider).valueOrNull;
  return cart?.hasUnavailableItems ?? false;
});

class ShippingAddressesController
    extends AsyncNotifier<List<ShippingAddressEntity>> {
  @override
  Future<List<ShippingAddressEntity>> build() {
    return ref.read(storeRepositoryProvider).listShippingAddresses();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(storeRepositoryProvider).listShippingAddresses(),
    );
  }

  Future<ShippingAddressEntity> save(ShippingAddressEntity address) async {
    final repo = ref.read(storeRepositoryProvider);
    final saved = await repo.saveShippingAddress(address);
    state = await AsyncValue.guard(repo.listShippingAddresses);
    return saved;
  }

  Future<void> delete(String addressId) async {
    final repo = ref.read(storeRepositoryProvider);
    await repo.deleteShippingAddress(addressId);
    state = await AsyncValue.guard(repo.listShippingAddresses);
  }

  Future<void> setDefault(String addressId) async {
    final repo = ref.read(storeRepositoryProvider);
    state = await AsyncValue.guard(
      () => repo.setDefaultShippingAddress(addressId),
    );
  }
}

final shippingAddressesProvider =
    AsyncNotifierProvider<
      ShippingAddressesController,
      List<ShippingAddressEntity>
    >(ShippingAddressesController.new);

final defaultShippingAddressProvider = Provider<ShippingAddressEntity?>((ref) {
  final addresses =
      ref.watch(shippingAddressesProvider).valueOrNull ?? const [];
  for (final address in addresses) {
    if (address.isDefault) {
      return address;
    }
  }
  return addresses.isNotEmpty ? addresses.first : null;
});

final myOrdersProvider = FutureProvider<List<OrderEntity>>((ref) async {
  final repo = ref.watch(storeRepositoryProvider);
  return repo.listMyOrders();
});

final myOrderDetailsProvider = FutureProvider.family<OrderEntity?, String>((
  ref,
  orderId,
) async {
  final repo = ref.watch(storeRepositoryProvider);
  return repo.getMyOrderDetails(orderId);
});
