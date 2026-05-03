import '../../../store/domain/entities/order_entity.dart';
import '../../../store/domain/entities/product_entity.dart';
import '../entities/seller_profile_entity.dart';
import '../entities/seller_taiyo_entity.dart';

abstract class SellerRepository {
  Future<SellerProfileEntity?> getSellerProfile();

  Future<void> upsertSellerProfile({
    required String storeName,
    required String storeDescription,
    required String primaryCategory,
    required String shippingScope,
    String? supportEmail,
  });

  Future<SellerDashboardSummaryEntity> getDashboardSummary();

  Future<List<ProductEntity>> listOwnProducts();

  Future<ProductEntity> saveProduct({
    String? productId,
    required String title,
    required String description,
    required String category,
    required double price,
    required int stockQty,
    required int lowStockThreshold,
    List<String> imagePaths,
    bool isActive,
  });

  Future<String> uploadProductImage({
    required String productId,
    required List<int> bytes,
    String extension,
  });

  Future<bool> deleteOrArchiveProduct(String productId);

  Future<List<OrderEntity>> listOrders();

  Future<OrderEntity?> getOrderDetails(String orderId);

  Future<void> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? note,
  });

  Future<SellerTaiyoCopilotEntity> requestSellerCopilot({
    String requestType = 'seller_dashboard_brief',
    String? productId,
    String? orderId,
  });
}
