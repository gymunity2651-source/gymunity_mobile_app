import '../../domain/entities/product_entity.dart';

class StoreCartItem {
  const StoreCartItem({
    required this.product,
    required this.quantity,
  });

  final ProductEntity product;
  final int quantity;

  double get lineTotal => product.price * quantity;

  StoreCartItem copyWith({
    ProductEntity? product,
    int? quantity,
  }) {
    return StoreCartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}
