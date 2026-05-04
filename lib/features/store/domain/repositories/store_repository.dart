import '../../../../core/result/paged.dart';
import '../entities/cart_entity.dart';
import '../entities/order_entity.dart';
import '../entities/product_entity.dart';
import '../entities/shipping_address_entity.dart';
import '../entities/store_recommendation_entity.dart';

abstract class StoreRepository {
  Future<Paged<ProductEntity>> listProducts({
    String? category,
    String? cursor,
    int limit = 20,
  });

  Future<ProductEntity?> getProductById(String productId);

  Future<CartEntity> getCart();

  Future<CartEntity> addToCart({
    required ProductEntity product,
    int quantity = 1,
  });

  Future<CartEntity> updateCartQuantity({
    required String productId,
    required int quantity,
  });

  Future<CartEntity> removeCartItem(String productId);

  Future<CartEntity> clearInvalidCartItems();

  Future<Set<String>> getFavoriteIds();

  Future<List<ProductEntity>> getFavoriteProducts();

  Future<bool> toggleFavorite(ProductEntity product);

  Future<List<ShippingAddressEntity>> listShippingAddresses();

  Future<ShippingAddressEntity> saveShippingAddress(
    ShippingAddressEntity address,
  );

  Future<void> deleteShippingAddress(String addressId);

  Future<List<ShippingAddressEntity>> setDefaultShippingAddress(
    String addressId,
  );

  Future<List<OrderEntity>> placeOrderFromCart({
    required String addressId,
    required String idempotencyKey,
  });

  Future<List<OrderEntity>> listMyOrders();

  Future<OrderEntity?> getMyOrderDetails(String orderId);

  Future<StoreRecommendationsEntity> requestTaiyoStoreRecommendations({
    int limit = 3,
  });
}
