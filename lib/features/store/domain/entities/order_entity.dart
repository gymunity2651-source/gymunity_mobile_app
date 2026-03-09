class OrderEntity {
  const OrderEntity({
    required this.id,
    required this.memberId,
    required this.sellerId,
    required this.status,
    required this.totalAmount,
    required this.currency,
  });

  final String id;
  final String memberId;
  final String sellerId;
  final String status;
  final double totalAmount;
  final String currency;
}

