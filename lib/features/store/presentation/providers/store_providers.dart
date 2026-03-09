import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/product_entity.dart';

final selectedStoreCategoryProvider = StateProvider<int>((ref) => 0);

final storeCategoriesProvider = Provider<List<String>>(
  (ref) => <String>['All', 'Supplements', 'Equipment', 'Apparel', 'Accessories'],
);

final storeProductsProvider = FutureProvider<List<ProductEntity>>((ref) async {
  final categories = ref.watch(storeCategoriesProvider);
  final selectedIndex = ref.watch(selectedStoreCategoryProvider);
  final selectedCategory = categories[selectedIndex];
  final repo = ref.watch(storeRepositoryProvider);
  final paged = await repo.listProducts(category: selectedCategory);
  return paged.items;
});

