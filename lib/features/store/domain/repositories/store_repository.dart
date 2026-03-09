import '../../../../core/result/paged.dart';
import '../entities/order_entity.dart';
import '../entities/product_entity.dart';

abstract class StoreRepository {
  Future<Paged<ProductEntity>> listProducts({
    String? category,
    String? cursor,
    int limit = 20,
  });

  Future<void> createOrUpdateProduct({
    String? productId,
    required String title,
    required String description,
    required String category,
    required double price,
    required int stockQty,
    List<String> imagePaths = const <String>[],
  });

  Future<String> uploadProductImage({
    required String productId,
    required List<int> bytes,
    String extension = 'jpg',
  });

  Future<OrderEntity> placeOrder({
    required String sellerId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String currency = 'USD',
  });

  Future<List<OrderEntity>> listMyOrders();
}
