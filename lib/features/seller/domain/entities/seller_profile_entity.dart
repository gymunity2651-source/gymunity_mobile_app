class SellerProfileEntity {
  const SellerProfileEntity({
    required this.userId,
    this.storeName,
    this.storeDescription,
    this.primaryCategory,
    this.shippingScope,
    this.supportEmail,
  });

  final String userId;
  final String? storeName;
  final String? storeDescription;
  final String? primaryCategory;
  final String? shippingScope;
  final String? supportEmail;
}

class SellerDashboardSummaryEntity {
  const SellerDashboardSummaryEntity({
    required this.totalProducts,
    required this.activeProducts,
    required this.lowStockProducts,
    required this.pendingOrders,
    required this.inProgressOrders,
    required this.deliveredOrders,
    required this.grossRevenue,
  });

  final int totalProducts;
  final int activeProducts;
  final int lowStockProducts;
  final int pendingOrders;
  final int inProgressOrders;
  final int deliveredOrders;
  final double grossRevenue;

  int get pendingPaymentOrders => pendingOrders;
}
