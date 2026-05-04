class StoreRecommendationProductEntity {
  const StoreRecommendationProductEntity({
    required this.productId,
    required this.name,
    required this.whyRecommended,
    this.category = '',
    this.priority = 'medium',
    this.price = 0,
    this.currency = 'USD',
  });

  final String productId;
  final String name;
  final String category;
  final String whyRecommended;
  final String priority;
  final double price;
  final String currency;

  factory StoreRecommendationProductEntity.fromMap(Map<String, dynamic> map) {
    return StoreRecommendationProductEntity(
      productId: map['product_id'] as String? ?? '',
      name: map['name'] as String? ?? 'Product',
      category: map['category'] as String? ?? '',
      whyRecommended:
          map['why_recommended'] as String? ??
          'Useful support for your current fitness context.',
      priority: _priority(map['priority']),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'USD',
    );
  }
}

class StoreRecommendationsEntity {
  const StoreRecommendationsEntity({
    required this.status,
    required this.recommendationType,
    required this.reason,
    required this.products,
    required this.disclaimer,
    this.confidence = 'medium',
  });

  final String status;
  final String recommendationType;
  final String reason;
  final List<StoreRecommendationProductEntity> products;
  final String disclaimer;
  final String confidence;

  factory StoreRecommendationsEntity.fromResponse(dynamic response) {
    final map = _map(response);
    final result = _map(map['result']);
    final products = _list(result['products'])
        .map((item) => StoreRecommendationProductEntity.fromMap(_map(item)))
        .where((product) => product.productId.isNotEmpty)
        .toList(growable: false);
    final quality = _map(map['data_quality']);
    return StoreRecommendationsEntity(
      status: map['status'] as String? ?? 'error',
      recommendationType:
          result['recommendation_type'] as String? ?? 'fitness_support',
      reason:
          result['reason'] as String? ??
          'TAIYO matched available products to your current context.',
      products: products,
      disclaimer:
          result['disclaimer'] as String? ??
          'Recommendations are based on fitness context, not medical advice.',
      confidence: quality['confidence'] as String? ?? 'medium',
    );
  }

  bool get hasProducts => products.isNotEmpty;
}

String _priority(dynamic value) {
  final text = value?.toString().trim().toLowerCase();
  return text == 'low' || text == 'medium' || text == 'high'
      ? text!
      : 'medium';
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  return value is List ? value : const <dynamic>[];
}
