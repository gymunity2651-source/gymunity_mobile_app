import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../store/domain/entities/order_entity.dart';
import '../../../store/domain/entities/product_entity.dart';
import '../../domain/entities/seller_profile_entity.dart';

final sellerProfileProvider = FutureProvider<SellerProfileEntity?>((ref) async {
  final repo = ref.watch(sellerRepositoryProvider);
  return repo.getSellerProfile();
});

final sellerDashboardSummaryProvider =
    FutureProvider<SellerDashboardSummaryEntity>((ref) async {
      final repo = ref.watch(sellerRepositoryProvider);
      return repo.getDashboardSummary();
    });

final sellerProductsProvider = FutureProvider<List<ProductEntity>>((ref) async {
  final repo = ref.watch(sellerRepositoryProvider);
  return repo.listOwnProducts();
});

final sellerOrdersProvider = FutureProvider<List<OrderEntity>>((ref) async {
  final repo = ref.watch(sellerRepositoryProvider);
  return repo.listOrders();
});

final sellerOrderDetailsProvider = FutureProvider.family<OrderEntity?, String>((
  ref,
  orderId,
) async {
  final repo = ref.watch(sellerRepositoryProvider);
  return repo.getOrderDetails(orderId);
});
