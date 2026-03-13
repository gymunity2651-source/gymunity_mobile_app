import 'product_entity.dart';

class CartEntity {
  const CartEntity({
    required this.id,
    required this.memberId,
    this.items = const <CartItemEntity>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String memberId;
  final List<CartItemEntity> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get itemCount =>
      items.fold<int>(0, (total, item) => total + item.quantity);

  double get subtotal =>
      items.fold<double>(0, (total, item) => total + item.lineTotal);

  bool get isEmpty => items.isEmpty;

  bool get hasUnavailableItems => items.any((item) => item.isUnavailable);
}

class CartItemEntity {
  const CartItemEntity({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.product,
    required this.quantity,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String cartId;
  final String productId;
  final ProductEntity product;
  final int quantity;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get lineTotal => product.price * quantity;

  bool get exceedsStock => quantity > product.stockQty;

  bool get isUnavailable => product.isArchived || product.stockQty <= 0;
}
