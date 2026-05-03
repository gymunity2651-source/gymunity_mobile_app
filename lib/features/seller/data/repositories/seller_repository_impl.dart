import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/historical_record_utils.dart';
import '../../../store/domain/entities/order_entity.dart';
import '../../../store/domain/entities/product_entity.dart';
import '../../domain/entities/seller_profile_entity.dart';
import '../../domain/entities/seller_taiyo_entity.dart';
import '../../domain/repositories/seller_repository.dart';

const String kTaiyoSellerCopilotFunctionName = 'taiyo-seller-copilot';

class SellerRepositoryImpl implements SellerRepository {
  SellerRepositoryImpl(this._client);

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'No authenticated seller found.');
    }
    return userId;
  }

  @override
  Future<SellerProfileEntity?> getSellerProfile() async {
    try {
      final row = await _client
          .from('seller_profiles')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return SellerProfileEntity(
        userId: row['user_id'] as String,
        storeName: row['store_name'] as String?,
        storeDescription: row['store_description'] as String?,
        primaryCategory: row['primary_category'] as String?,
        shippingScope: row['shipping_scope'] as String?,
        supportEmail: row['support_email'] as String?,
      );
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to load seller profile.',
      );
    }
  }

  @override
  Future<void> upsertSellerProfile({
    required String storeName,
    required String storeDescription,
    required String primaryCategory,
    required String shippingScope,
    String? supportEmail,
  }) async {
    final userId = _userId;
    try {
      await _client
          .from('seller_profiles')
          .upsert(
            <String, dynamic>{
              'user_id': userId,
              'store_name': storeName,
              'store_description': storeDescription,
              'primary_category': primaryCategory,
              'shipping_scope': shippingScope,
              'support_email': supportEmail,
            }..removeWhere((String key, dynamic value) => value == null),
          );

      await _client
          .from('profiles')
          .update(<String, dynamic>{
            'onboarding_completed': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to save seller profile.',
      );
    }
  }

  @override
  Future<SellerDashboardSummaryEntity> getDashboardSummary() async {
    try {
      final rows = await _client.rpc('seller_dashboard_summary');
      final row = (rows as List<dynamic>).first as Map<String, dynamic>;
      return SellerDashboardSummaryEntity(
        totalProducts: row['total_products'] as int? ?? 0,
        activeProducts: row['active_products'] as int? ?? 0,
        lowStockProducts: row['low_stock_products'] as int? ?? 0,
        pendingOrders: row['pending_orders'] as int? ?? 0,
        inProgressOrders: row['in_progress_orders'] as int? ?? 0,
        deliveredOrders: row['delivered_orders'] as int? ?? 0,
        grossRevenue: (row['gross_revenue'] as num?)?.toDouble() ?? 0,
      );
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to load seller dashboard metrics.',
      );
    }
  }

  @override
  Future<List<ProductEntity>> listOwnProducts() async {
    try {
      final rows = await _client
          .from('products')
          .select(
            'id,seller_id,title,description,category,price,currency,stock_qty,image_paths,low_stock_threshold,is_active,deleted_at,created_at,updated_at',
          )
          .eq('seller_id', _userId)
          .order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((dynamic row) => _mapProduct(row as Map<String, dynamic>))
          .toList(growable: false);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to load your products.',
      );
    }
  }

  @override
  Future<ProductEntity> saveProduct({
    String? productId,
    required String title,
    required String description,
    required String category,
    required double price,
    required int stockQty,
    required int lowStockThreshold,
    List<String> imagePaths = const <String>[],
    bool isActive = true,
  }) async {
    try {
      final payload = <String, dynamic>{
        'seller_id': _userId,
        'title': title.trim(),
        'description': description.trim(),
        'category': category.trim(),
        'price': price,
        'currency': 'USD',
        'stock_qty': stockQty,
        'low_stock_threshold': lowStockThreshold,
        'image_paths': imagePaths,
        'is_active': isActive,
        'deleted_at': isActive
            ? null
            : DateTime.now().toUtc().toIso8601String(),
      };

      late final Map<String, dynamic> row;
      if ((productId ?? '').trim().isEmpty) {
        row = await _client
            .from('products')
            .insert(payload)
            .select(
              'id,seller_id,title,description,category,price,currency,stock_qty,image_paths,low_stock_threshold,is_active,deleted_at,created_at,updated_at',
            )
            .single();
      } else {
        row = await _client
            .from('products')
            .update(payload)
            .eq('id', productId!)
            .eq('seller_id', _userId)
            .select(
              'id,seller_id,title,description,category,price,currency,stock_qty,image_paths,low_stock_threshold,is_active,deleted_at,created_at,updated_at',
            )
            .single();
      }

      return _mapProduct(row);
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to save the product.',
      );
    }
  }

  @override
  Future<String> uploadProductImage({
    required String productId,
    required List<int> bytes,
    String extension = 'jpg',
  }) async {
    final normalizedExtension = _normalizeImageExtension(extension);
    final compressedBytes = _optimizeProductImageBytes(
      bytes,
      extension: normalizedExtension,
    );
    final path =
        '$_userId/$productId/${DateTime.now().millisecondsSinceEpoch}.$normalizedExtension';

    try {
      await _client.storage
          .from('product-images')
          .uploadBinary(
            path,
            compressedBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeForExtension(normalizedExtension),
            ),
          );
      return path;
    } on StorageException catch (error, stackTrace) {
      throw StorageFailure(
        message: error.message,
        code: error.statusCode?.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<bool> deleteOrArchiveProduct(String productId) async {
    try {
      final linkedItems = await _client
          .from('order_items')
          .select('id')
          .eq('product_id', productId)
          .limit(1);
      if ((linkedItems as List<dynamic>).isNotEmpty) {
        await _client
            .from('products')
            .update(<String, dynamic>{
              'is_active': false,
              'deleted_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', productId)
            .eq('seller_id', _userId);
        return false;
      }

      final product = await _client
          .from('products')
          .select('image_paths')
          .eq('id', productId)
          .eq('seller_id', _userId)
          .maybeSingle();
      final imagePaths =
          (product?['image_paths'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false);
      if (imagePaths.isNotEmpty) {
        await _client.storage.from('product-images').remove(imagePaths);
      }
      await _client
          .from('products')
          .delete()
          .eq('id', productId)
          .eq('seller_id', _userId);
      return true;
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to delete the product.',
      );
    }
  }

  @override
  Future<List<OrderEntity>> listOrders() async {
    try {
      final rows = await _client.rpc('list_seller_orders_detailed');
      return _enrichOrders(
        (rows as List<dynamic>)
            .map(
              (dynamic row) => _mapOrderSummaryRow(row as Map<String, dynamic>),
            )
            .toList(growable: false),
      );
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to load seller orders.',
      );
    }
  }

  @override
  Future<OrderEntity?> getOrderDetails(String orderId) async {
    final orders = await listOrders();
    for (final order in orders) {
      if (order.id == orderId) {
        return order;
      }
    }
    return null;
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? note,
  }) async {
    try {
      await _client.rpc(
        'update_store_order_status',
        params: <String, dynamic>{
          'target_order_id': orderId,
          'new_status': newStatus,
          'note': note,
        },
      );
    } on PostgrestException catch (error, stackTrace) {
      throw _mapPostgrestFailure(
        error,
        stackTrace,
        fallbackMessage: 'Unable to update the order status.',
      );
    }
  }

  @override
  Future<SellerTaiyoCopilotEntity> requestSellerCopilot({
    String requestType = 'seller_dashboard_brief',
    String? productId,
    String? orderId,
  }) async {
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthFailure(message: 'No authenticated seller found.');
    }

    try {
      final response = await _client.functions.invoke(
        kTaiyoSellerCopilotFunctionName,
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        body: sellerCopilotRequestBody(
          requestType: requestType,
          productId: productId,
          orderId: orderId,
        ),
      );
      return sellerTaiyoCopilotFromResponse(response.data);
    } on FunctionException catch (error, stackTrace) {
      if (error.status == 401) {
        throw AuthFailure(
          message: 'Please sign in again to use TAIYO seller copilot.',
          code: error.status.toString(),
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (error.status == 403) {
        throw AuthFailure(
          message:
              'TAIYO seller copilot is available for seller accounts only.',
          code: error.status.toString(),
          cause: error,
          stackTrace: stackTrace,
        );
      }
      throw NetworkFailure(
        message: _functionErrorMessage(
          error,
          'TAIYO could not prepare seller guidance right now.',
        ),
        code: error.status.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      if (error is AppFailure) {
        rethrow;
      }
      throw NetworkFailure(
        message: 'TAIYO could not prepare seller guidance right now.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
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

  OrderEntity _mapOrderSummaryRow(Map<String, dynamic> row) {
    return OrderEntity(
      id: row['id'] as String? ?? '',
      memberId: normalizeHistoricalId(row['member_id']),
      memberName: normalizeHistoricalLabel(
        row['member_name'],
        'Deleted member',
      ),
      sellerId: _userId,
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
      productId: row['product_id'] as String? ?? '',
      sellerId: row['seller_id'] as String? ?? '',
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

  Uint8List _optimizeProductImageBytes(
    List<int> bytes, {
    required String extension,
  }) {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) {
      return Uint8List.fromList(bytes);
    }

    const maxEdge = 1600;
    final longestEdge = math.max(decoded.width, decoded.height);
    final resized = longestEdge > maxEdge
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxEdge : null,
            height: decoded.height > decoded.width ? maxEdge : null,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    if (extension == 'png') {
      return Uint8List.fromList(img.encodePng(resized, level: 6));
    }

    return Uint8List.fromList(img.encodeJpg(resized, quality: 84));
  }

  String _normalizeImageExtension(String extension) {
    final normalized = extension.trim().toLowerCase();
    if (normalized == 'png') {
      return 'png';
    }
    return 'jpg';
  }

  String _contentTypeForExtension(String extension) {
    if (extension == 'png') {
      return 'image/png';
    }
    return 'image/jpeg';
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

    if (normalized.contains('out of stock') ||
        normalized.contains('unavailable')) {
      return ConflictFailure(
        message: message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (normalized.contains('status transition')) {
      return ValidationFailure(
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

Map<String, dynamic> sellerCopilotRequestBody({
  required String requestType,
  String? productId,
  String? orderId,
}) {
  return <String, dynamic>{
    'request_type': requestType,
    if ((productId ?? '').trim().isNotEmpty) 'product_id': productId,
    if ((orderId ?? '').trim().isNotEmpty) 'order_id': orderId,
  };
}

SellerTaiyoCopilotEntity sellerTaiyoCopilotFromResponse(dynamic value) {
  final map = _responseMap(value);
  if (map.isEmpty) {
    throw const NetworkFailure(
      message: 'TAIYO returned an empty seller copilot response.',
    );
  }
  return SellerTaiyoCopilotEntity.fromMap(map);
}

String _functionErrorMessage(FunctionException error, String fallback) {
  final details = _responseMap(error.details);
  return details['message']?.toString() ??
      details['error']?.toString() ??
      error.details?.toString() ??
      fallback;
}

Map<String, dynamic> _responseMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic rowValue) => MapEntry(key.toString(), rowValue),
    );
  }
  return const <String, dynamic>{};
}
