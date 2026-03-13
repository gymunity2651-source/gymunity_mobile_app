class ProductEntity {
  const ProductEntity({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    this.currency = 'USD',
    this.stockQty = 0,
    this.imagePaths = const <String>[],
    this.imageUrls = const <String>[],
    this.lowStockThreshold = 5,
    this.isActive = true,
    this.deletedAt,
    this.sellerName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sellerId;
  final String name;
  final String description;
  final String category;
  final double price;
  final String currency;
  final int stockQty;
  final List<String> imagePaths;
  final List<String> imageUrls;
  final int lowStockThreshold;
  final bool isActive;
  final DateTime? deletedAt;
  final String? sellerName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get imageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  bool get isArchived => deletedAt != null || !isActive;

  bool get isLowStock => stockQty <= lowStockThreshold;

  bool get isAvailable => !isArchived && stockQty > 0;
}
