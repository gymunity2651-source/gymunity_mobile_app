import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/paged.dart';
import '../../../../core/utils/historical_record_utils.dart';
import '../../domain/entities/cart_entity.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/shipping_address_entity.dart';
import '../../domain/repositories/store_repository.dart';

class StoreRepositoryImpl implements StoreRepository {
  StoreRepositoryImpl(this._client);

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'No authenticated member found.');
    }
    return userId;
  }

  @override
  Future<Paged<ProductEntity>> listProducts({
    String? category,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      dynamic query = _client
          .from('products')
          .select(
            'id,seller_id,title,description,category,price,currency,stock_qty,image_paths,low_stock_threshold,is_active,deleted_at,created_at,updated_at',
          )
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(limit);

      if (category != null && category.isNotEmpty && category != 'All') {
        query = query.ilike('category', category.trim());
      }

      final rows = (await query) as List<dynamic>;
      final items = rows
          .map((dynamic row) => _mapProduct(row as Map<String, dynamic>))
          .toList(growable: false);

      return Paged<ProductEntity>(items: items, nextCursor: null);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to load products.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to load products.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<ProductEntity?> getProductById(String productId) async {
    try {
      final row = await _client
          .from('products')
          .select(
            'id,seller_id,title,description,category,price,currency,stock_qty,image_paths,low_stock_threshold,is_active,deleted_at,created_at,updated_at',
          )
          .eq('id', productId)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return _mapProduct(row);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to load product details.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to load product details.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<CartEntity> getCart() async {
    try {
      final cartRow = await _ensureCartRow();
      return _loadCart(cartRow);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to load your cart.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to load your cart.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<CartEntity> addToCart({
    required ProductEntity product,
    int quantity = 1,
  }) async {
    if (quantity <= 0) {
      return getCart();
    }

    try {
      final cartRow = await _ensureCartRow();
      final cartId = cartRow['id'] as String;
      final existing = await _client
          .from('store_cart_items')
          .select('id,quantity')
          .eq('cart_id', cartId)
          .eq('product_id', product.id)
          .maybeSingle();

      if (existing == null) {
        await _client.from('store_cart_items').insert(<String, dynamic>{
          'cart_id': cartId,
          'product_id': product.id,
          'quantity': quantity,
        });
      } else {
        final currentQty = existing['quantity'] as int? ?? 0;
        await _client
            .from('store_cart_items')
            .update(<String, dynamic>{'quantity': currentQty + quantity})
            .eq('id', existing['id'] as String)
            .eq('cart_id', cartId);
      }

      return _loadCart(cartRow);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to update your cart.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to update your cart.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<CartEntity> updateCartQuantity({
    required String productId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      return removeCartItem(productId);
    }

    try {
      final cartRow = await _ensureCartRow();
      await _client
          .from('store_cart_items')
          .update(<String, dynamic>{'quantity': quantity})
          .eq('cart_id', cartRow['id'] as String)
          .eq('product_id', productId);
      return _loadCart(cartRow);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to update your cart.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to update your cart.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<CartEntity> removeCartItem(String productId) async {
    try {
      final cartRow = await _ensureCartRow();
      await _client
          .from('store_cart_items')
          .delete()
          .eq('cart_id', cartRow['id'] as String)
          .eq('product_id', productId);
      return _loadCart(cartRow);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to remove the item from your cart.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to remove the item from your cart.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<CartEntity> clearInvalidCartItems() async {
    final cart = await getCart();
    for (final item in cart.items) {
      if (item.isUnavailable) {
        await _client
            .from('store_cart_items')
            .delete()
            .eq('id', item.id)
            .eq('cart_id', cart.id);
        continue;
      }

      if (item.exceedsStock && item.product.stockQty > 0) {
        await _client
            .from('store_cart_items')
            .update(<String, dynamic>{'quantity': item.product.stockQty})
            .eq('id', item.id)
            .eq('cart_id', cart.id);
      }
    }

    return getCart();
  }

  @override
  Future<Set<String>> getFavoriteIds() async {
    try {
      final rows = await _client
          .from('product_favorites')
          .select('product_id')
          .eq('member_id', _userId);
      return (rows as List<dynamic>)
          .map((dynamic row) => (row as Map<String, dynamic>)['product_id'])
          .whereType<String>()
          .toSet();
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to load your favorites.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to load your favorites.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<ProductEntity>> getFavoriteProducts() async {
    try {
      final favoriteRows = await _client
          .from('product_favorites')
          .select('product_id,created_at')
          .eq('member_id', _userId)
          .order('created_at', ascending: false);

      final orderedIds = (favoriteRows as List<dynamic>)
          .map((dynamic row) => (row as Map<String, dynamic>)['product_id'])
          .whereType<String>()
          .toList(growable: false);

      if (orderedIds.isEmpty) {
        return const <ProductEntity>[];
      }

      final products = await _loadProductsByIds(orderedIds.toSet());
      return orderedIds
          .map((id) => products[id])
          .whereType<ProductEntity>()
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to load your favorites.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to load your favorites.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<bool> toggleFavorite(ProductEntity product) async {
    try {
      final existing = await _client
          .from('product_favorites')
          .select('product_id')
          .eq('member_id', _userId)
          .eq('product_id', product.id)
          .maybeSingle();

      if (existing != null) {
        await _client
            .from('product_favorites')
            .delete()
            .eq('member_id', _userId)
            .eq('product_id', product.id);
        return false;
      }

      await _client.from('product_favorites').insert(<String, dynamic>{
        'member_id': _userId,
        'product_id': product.id,
      });
      return true;
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to update your favorites.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to update your favorites.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<ShippingAddressEntity>> listShippingAddresses() async {
    try {
      final rows = await _client
          .from('shipping_addresses')
          .select()
          .eq('user_id', _userId)
          .order('is_default', ascending: false)
          .order('updated_at', ascending: false);
      return (rows as List<dynamic>)
          .map(
            (dynamic row) => _mapShippingAddress(row as Map<String, dynamic>),
          )
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to load your shipping addresses.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to load your shipping addresses.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<ShippingAddressEntity> saveShippingAddress(
    ShippingAddressEntity address,
  ) async {
    try {
      final currentAddresses = await listShippingAddresses();
      final shouldBeDefault =
          address.isDefault ||
          currentAddresses.isEmpty ||
          currentAddresses.every((item) => item.id == address.id);

      if (shouldBeDefault) {
        await _client
            .from('shipping_addresses')
            .update(<String, dynamic>{'is_default': false})
            .eq('user_id', _userId);
      }

      final payload = <String, dynamic>{
        'user_id': _userId,
        'recipient_name': address.recipientName.trim(),
        'phone': address.phone.trim(),
        'line1': address.line1.trim(),
        'line2': address.line2?.trim(),
        'city': address.city.trim(),
        'state_region': address.stateRegion.trim(),
        'postal_code': address.postalCode.trim(),
        'country_code': address.countryCode.trim().toUpperCase(),
        'delivery_notes': address.deliveryNotes?.trim(),
        'is_default': shouldBeDefault,
      }..removeWhere((String key, dynamic value) => value == null);

      late final Map<String, dynamic> row;
      if (address.id.trim().isEmpty) {
        row = await _client
            .from('shipping_addresses')
            .insert(payload)
            .select()
            .single();
      } else {
        row = await _client
            .from('shipping_addresses')
            .update(payload)
            .eq('id', address.id)
            .eq('user_id', _userId)
            .select()
            .single();
      }
      return _mapShippingAddress(row);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to save the shipping address.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to save the shipping address.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> deleteShippingAddress(String addressId) async {
    try {
      final target = await _client
          .from('shipping_addresses')
          .select('id,is_default')
          .eq('id', addressId)
          .eq('user_id', _userId)
          .maybeSingle();
      if (target == null) {
        return;
      }

      await _client
          .from('shipping_addresses')
          .delete()
          .eq('id', addressId)
          .eq('user_id', _userId);

      if (target['is_default'] == true) {
        final remaining = await listShippingAddresses();
        if (remaining.isNotEmpty) {
          await setDefaultShippingAddress(remaining.first.id);
        }
      }
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to delete the shipping address.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to delete the shipping address.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<ShippingAddressEntity>> setDefaultShippingAddress(
    String addressId,
  ) async {
    try {
      await _client
          .from('shipping_addresses')
          .update(<String, dynamic>{'is_default': false})
          .eq('user_id', _userId);
      await _client
          .from('shipping_addresses')
          .update(<String, dynamic>{'is_default': true})
          .eq('id', addressId)
          .eq('user_id', _userId);
      return listShippingAddresses();
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to update the default shipping address.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to update the default shipping address.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<OrderEntity>> placeOrderFromCart({
    required String addressId,
    required String idempotencyKey,
  }) async {
    try {
      final rows = await _client.rpc(
        'create_store_order',
        params: <String, dynamic>{
          'target_shipping_address_id': addressId,
          'client_idempotency_key': idempotencyKey,
        },
      );
      return (rows as List<dynamic>)
          .map(
            (dynamic row) => _mapOrderSummaryRow(row as Map<String, dynamic>),
          )
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to place your order.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to place your order.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<OrderEntity>> listMyOrders() async {
    try {
      final rows = await _client.rpc('list_member_orders_detailed');
      return _enrichOrders(
        (rows as List<dynamic>)
            .map(
              (dynamic row) =>
                  _mapMemberOrderSummaryRow(row as Map<String, dynamic>),
            )
            .toList(growable: false),
      );
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to load your orders.',
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to load your orders.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<OrderEntity?> getMyOrderDetails(String orderId) async {
    final orders = await listMyOrders();
    for (final order in orders) {
      if (order.id == orderId) {
        return order;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _ensureCartRow() async {
    final existing = await _client
        .from('store_carts')
        .select('id,member_id,created_at,updated_at')
        .eq('member_id', _userId)
        .maybeSingle();

    if (existing != null) {
      return existing;
    }

    try {
      return await _client
          .from('store_carts')
          .insert(<String, dynamic>{'member_id': _userId})
          .select('id,member_id,created_at,updated_at')
          .single();
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        return (await _client
            .from('store_carts')
            .select('id,member_id,created_at,updated_at')
            .eq('member_id', _userId)
            .single());
      }
      rethrow;
    }
  }

  Future<CartEntity> _loadCart(Map<String, dynamic> cartRow) async {
    final cartId = cartRow['id'] as String;
    final itemRows = await _client
        .from('store_cart_items')
        .select('id,cart_id,product_id,quantity,created_at,updated_at')
        .eq('cart_id', cartId)
        .order('created_at', ascending: true);

    final parsedItemRows = (itemRows as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final productIds = parsedItemRows
        .map((Map<String, dynamic> row) => row['product_id'])
        .whereType<String>()
        .toSet();
    final productsById = await _loadProductsByIds(productIds);

    final items = parsedItemRows
        .map((Map<String, dynamic> row) {
          final productId = row['product_id'] as String? ?? '';
          final product = productsById[productId] ?? _missingProduct(productId);
          return CartItemEntity(
            id: row['id'] as String? ?? '',
            cartId: row['cart_id'] as String? ?? cartId,
            productId: productId,
            product: product,
            quantity: row['quantity'] as int? ?? 0,
            createdAt: _parseDate(row['created_at']),
            updatedAt: _parseDate(row['updated_at']),
          );
        })
        .toList(growable: false);

    return CartEntity(
      id: cartId,
      memberId: cartRow['member_id'] as String? ?? _userId,
      items: items,
      createdAt: _parseDate(cartRow['created_at']),
      updatedAt: _parseDate(cartRow['updated_at']),
    );
  }

  Future<Map<String, ProductEntity>> _loadProductsByIds(
    Set<String> productIds,
  ) async {
    if (productIds.isEmpty) {
      return const <String, ProductEntity>{};
    }

    final rows = await _client
        .from('products')
        .select(
          'id,seller_id,title,description,category,price,currency,stock_qty,image_paths,low_stock_threshold,is_active,deleted_at,created_at,updated_at',
        )
        .inFilter('id', productIds.toList());

    final mapped = <String, ProductEntity>{};
    for (final dynamic row in rows as List<dynamic>) {
      final product = _mapProduct(row as Map<String, dynamic>);
      mapped[product.id] = product;
    }
    return mapped;
  }

  Future<List<OrderEntity>> _enrichOrders(List<OrderEntity> summaries) async {
    if (summaries.isEmpty) {
      return const <OrderEntity>[];
    }

    final orderIds = summaries.map((order) => order.id).toList(growable: false);
    final itemRows = await _client
        .from('order_items')
        .select(
          'id,order_id,product_id,seller_id,product_title_snapshot,unit_price,quantity,line_total',
        )
        .inFilter('order_id', orderIds);
    final historyRows = await _client
        .from('order_status_history')
        .select('id,order_id,status,actor_user_id,note,created_at')
        .inFilter('order_id', orderIds)
        .order('created_at', ascending: true);

    final itemsByOrder = <String, List<OrderItemEntity>>{};
    for (final dynamic row in itemRows as List<dynamic>) {
      final item = _mapOrderItem(row as Map<String, dynamic>);
      itemsByOrder
          .putIfAbsent(item.orderId, () => <OrderItemEntity>[])
          .add(item);
    }

    final historyByOrder = <String, List<OrderStatusHistoryEntry>>{};
    for (final dynamic row in historyRows as List<dynamic>) {
      final entry = _mapOrderStatusHistory(row as Map<String, dynamic>);
      historyByOrder
          .putIfAbsent(entry.orderId, () => <OrderStatusHistoryEntry>[])
          .add(entry);
    }

    return summaries
        .map(
          (order) => OrderEntity(
            id: order.id,
            memberId: order.memberId,
            sellerId: order.sellerId,
            status: order.status,
            totalAmount: order.totalAmount,
            currency: order.currency,
            paymentMethod: order.paymentMethod,
            memberName: order.memberName,
            sellerName: order.sellerName,
            itemCount: order.itemCount,
            shippingAddress: order.shippingAddress,
            items: itemsByOrder[order.id] ?? const <OrderItemEntity>[],
            statusHistory:
                historyByOrder[order.id] ?? const <OrderStatusHistoryEntry>[],
            createdAt: order.createdAt,
            updatedAt: order.updatedAt,
          ),
        )
        .toList(growable: false);
  }

  ProductEntity _mapProduct(Map<String, dynamic> row) {
    final imagePaths =
        (row['image_paths'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false);

    return ProductEntity(
      id: row['id'] as String? ?? '',
      sellerId: row['seller_id'] as String? ?? '',
      name: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      category: row['category'] as String? ?? '',
      price: (row['price'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'USD',
      stockQty: row['stock_qty'] as int? ?? 0,
      imagePaths: imagePaths,
      imageUrls: imagePaths
          .map(_resolveProductImageUrl)
          .toList(growable: false),
      lowStockThreshold: row['low_stock_threshold'] as int? ?? 5,
      isActive: row['is_active'] as bool? ?? true,
      deletedAt: _parseDate(row['deleted_at']),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  ProductEntity _missingProduct(String productId) {
    return ProductEntity(
      id: productId,
      sellerId: '',
      name: 'Unavailable product',
      description: 'This product is no longer available.',
      category: 'Unavailable',
      price: 0,
      stockQty: 0,
      isActive: false,
      deletedAt: DateTime.now(),
    );
  }

  ShippingAddressEntity _mapShippingAddress(Map<String, dynamic> row) {
    return ShippingAddressEntity(
      id: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? _userId,
      recipientName: row['recipient_name'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      line1: row['line1'] as String? ?? '',
      line2: row['line2'] as String?,
      city: row['city'] as String? ?? '',
      stateRegion: row['state_region'] as String? ?? '',
      postalCode: row['postal_code'] as String? ?? '',
      countryCode: row['country_code'] as String? ?? '',
      deliveryNotes: row['delivery_notes'] as String?,
      isDefault: row['is_default'] as bool? ?? false,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  OrderEntity _mapOrderSummaryRow(Map<String, dynamic> row) {
    return OrderEntity(
      id: row['order_id'] as String? ?? row['id'] as String? ?? '',
      memberId: _userId,
      sellerId: normalizeHistoricalId(row['seller_id']),
      sellerName: normalizeHistoricalLabel(
        row['seller_name'],
        'Deleted seller',
      ),
      memberName: normalizeHistoricalLabel(
        row['member_name'],
        'Deleted member',
      ),
      status: row['status'] as String? ?? 'pending',
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'USD',
      paymentMethod: row['payment_method'] as String? ?? 'manual',
      itemCount: row['item_count'] as int? ?? 0,
      shippingAddress: _mapJson(row['shipping_address_json']),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  OrderEntity _mapMemberOrderSummaryRow(Map<String, dynamic> row) {
    return OrderEntity(
      id: row['id'] as String? ?? '',
      memberId: _userId,
      sellerId: normalizeHistoricalId(row['seller_id']),
      sellerName: normalizeHistoricalLabel(
        row['seller_name'],
        'Deleted seller',
      ),
      status: row['status'] as String? ?? 'pending',
      totalAmount: (row['total_amount'] as num?)?.toDouble() ?? 0,
      currency: row['currency'] as String? ?? 'USD',
      paymentMethod: row['payment_method'] as String? ?? 'manual',
      itemCount: row['item_count'] as int? ?? 0,
      shippingAddress: _mapJson(row['shipping_address_json']),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  OrderItemEntity _mapOrderItem(Map<String, dynamic> row) {
    return OrderItemEntity(
      id: row['id'] as String? ?? '',
      orderId: row['order_id'] as String? ?? '',
      productId: normalizeHistoricalId(row['product_id']),
      sellerId: normalizeHistoricalId(row['seller_id']),
      productTitle: row['product_title_snapshot'] as String? ?? '',
      unitPrice: (row['unit_price'] as num?)?.toDouble() ?? 0,
      quantity: row['quantity'] as int? ?? 0,
      lineTotal: (row['line_total'] as num?)?.toDouble() ?? 0,
    );
  }

  OrderStatusHistoryEntry _mapOrderStatusHistory(Map<String, dynamic> row) {
    return OrderStatusHistoryEntry(
      id: row['id'] as String? ?? '',
      orderId: row['order_id'] as String? ?? '',
      status: row['status'] as String? ?? 'pending',
      actorUserId: row['actor_user_id'] as String?,
      note: row['note'] as String?,
      createdAt: _parseDate(row['created_at']),
    );
  }

  Map<String, dynamic> _mapJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
      );
    }
    return const <String, dynamic>{};
  }

  String _resolveProductImageUrl(String pathOrUrl) {
    final trimmed = pathOrUrl.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return trimmed;
    }
    return _client.storage.from('product-images').getPublicUrl(trimmed);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  AppFailure _mapPostgrestFailure(
    PostgrestException error,
    StackTrace stackTrace, {
    required String fallbackMessage,
  }) {
    final message = error.message.trim();
    final normalized = message.toLowerCase();

    if (normalized.contains('shipping address')) {
      return ValidationFailure(
        message: message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (normalized.contains('cart is empty')) {
      return ValidationFailure(
        message: message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (normalized.contains('out of stock') ||
        normalized.contains('unavailable')) {
      return ConflictFailure(
        message: message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (normalized.contains('payment')) {
      return PaymentFailure(
        message: message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return NetworkFailure(
      message: message.isEmpty ? fallbackMessage : message,
      code: error.code,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
