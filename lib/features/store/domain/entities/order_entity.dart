class OrderEntity {
  const OrderEntity({
    required this.id,
    required this.memberId,
    required this.sellerId,
    required this.status,
    required this.totalAmount,
    required this.currency,
    this.paymentMethod = 'manual',
    this.memberName,
    this.sellerName,
    this.itemCount = 0,
    this.shippingAddress = const <String, dynamic>{},
    this.items = const <OrderItemEntity>[],
    this.statusHistory = const <OrderStatusHistoryEntry>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String memberId;
  final String sellerId;
  final String status;
  final double totalAmount;
  final String currency;
  final String paymentMethod;
  final String? memberName;
  final String? sellerName;
  final int itemCount;
  final Map<String, dynamic> shippingAddress;
  final List<OrderItemEntity> items;
  final List<OrderStatusHistoryEntry> statusHistory;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get canBeCancelled =>
      status == 'pending' || status == 'paid' || status == 'processing';
}

class OrderItemEntity {
  const OrderItemEntity({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.sellerId,
    required this.productTitle,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
  });

  final String id;
  final String orderId;
  final String productId;
  final String sellerId;
  final String productTitle;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
}

class OrderStatusHistoryEntry {
  const OrderStatusHistoryEntry({
    required this.id,
    required this.orderId,
    required this.status,
    this.actorUserId,
    this.note,
    this.createdAt,
  });

  final String id;
  final String orderId;
  final String status;
  final String? actorUserId;
  final String? note;
  final DateTime? createdAt;
}
