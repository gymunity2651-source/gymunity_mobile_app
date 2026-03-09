class ProductEntity {
  const ProductEntity({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.imageUrl,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final String? imageUrl;
  final bool isActive;
}

