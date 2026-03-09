import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/paged.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/store_repository.dart';

class StoreRepositoryImpl implements StoreRepository {
  StoreRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Paged<ProductEntity>> listProducts({
    String? category,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      dynamic query = _client
          .from('products')
          .select('id,title,category,price,image_paths,is_active,created_at')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);

      if (category != null && category.isNotEmpty && category != 'All') {
        query = query.eq('category', category);
      }

      final rows = (await query) as List<dynamic>;
      final items = rows.map((dynamic row) {
        final map = row as Map<String, dynamic>;
        final imagePaths = (map['image_paths'] as List<dynamic>? ?? <dynamic>[])
            .cast<String>();
        return ProductEntity(
          id: map['id'] as String,
          name: map['title'] as String? ?? '',
          category: map['category'] as String? ?? '',
          price: (map['price'] as num?)?.toDouble() ?? 0,
          imageUrl: imagePaths.isNotEmpty ? imagePaths.first : null,
          isActive: map['is_active'] as bool? ?? true,
        );
      }).toList();

      return Paged<ProductEntity>(items: items, nextCursor: null);
    } catch (_) {
      // Keep UI alive if backend tables are not provisioned yet.
      return const Paged<ProductEntity>(
        items: <ProductEntity>[
          ProductEntity(
            id: 'demo-1',
            name: 'Premium Grip Yoga Mat 6mm',
            category: 'EQUIPMENT',
            price: 45,
          ),
          ProductEntity(
            id: 'demo-2',
            name: 'SpeedRunner V2 Shoes',
            category: 'APPAREL',
            price: 129,
          ),
          ProductEntity(
            id: 'demo-3',
            name: 'Ignite Pre-Workout (Fruit Punch)',
            category: 'SUPPLEMENTS',
            price: 38.5,
          ),
          ProductEntity(
            id: 'demo-4',
            name: 'ActivePulse Smart Tracker',
            category: 'ACCESSORIES',
            price: 89.99,
          ),
        ],
      );
    }
  }

  @override
  Future<void> createOrUpdateProduct({
    String? productId,
    required String title,
    required String description,
    required String category,
    required double price,
    required int stockQty,
    List<String> imagePaths = const <String>[],
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated seller found.');
    }

    final payload = <String, dynamic>{
      'id': productId,
      'seller_id': user.id,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'stock_qty': stockQty,
      'image_paths': imagePaths,
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((key, value) => value == null);

    try {
      await _client.from('products').upsert(payload);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<String> uploadProductImage({
    required String productId,
    required List<int> bytes,
    String extension = 'jpg',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated seller found.');
    }
    final path =
        '${user.id}/$productId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('product-images').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  @override
  Future<OrderEntity> placeOrder({
    required String sellerId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String currency = 'USD',
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated member found.');
    }

    try {
      final row = await _client
          .from('orders')
          .insert(<String, dynamic>{
            'member_id': user.id,
            'seller_id': sellerId,
            'status': 'pending',
            'total_amount': totalAmount,
            'currency': currency,
            'items_json': items,
          })
          .select(
            'id,member_id,seller_id,status,total_amount,currency',
          )
          .single();

      return OrderEntity(
        id: row['id'] as String,
        memberId: row['member_id'] as String,
        sellerId: row['seller_id'] as String,
        status: row['status'] as String? ?? 'pending',
        totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
        currency: row['currency'] as String? ?? currency,
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<List<OrderEntity>> listMyOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) return <OrderEntity>[];

    try {
      final rows = await _client
          .from('orders')
          .select('id,member_id,seller_id,status,total_amount,currency')
          .eq('member_id', user.id)
          .order('created_at', ascending: false);

      return (rows as List<dynamic>).map((dynamic row) {
        final map = row as Map<String, dynamic>;
        return OrderEntity(
          id: map['id'] as String,
          memberId: map['member_id'] as String,
          sellerId: map['seller_id'] as String,
          status: map['status'] as String? ?? '',
          totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
          currency: map['currency'] as String? ?? 'USD',
        );
      }).toList();
    } catch (_) {
      return <OrderEntity>[];
    }
  }
}
