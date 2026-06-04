import 'app_state_keys.dart';
import 'app_state_scope.dart';
import 'local_json_store.dart';

class PersistedCartItem {
  PersistedCartItem({
    required this.productId,
    required this.quantity,
    DateTime? addedAt,
    this.selectedOptions = const <String, dynamic>{},
  }) : addedAt = (addedAt ?? DateTime.now()).toUtc();

  final String productId;
  final int quantity;
  final DateTime addedAt;
  final Map<String, dynamic> selectedOptions;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'productId': productId,
      'quantity': quantity,
      'addedAt': addedAt.toIso8601String(),
      'selectedOptions': jsonSafeMap(selectedOptions),
    };
  }

  static PersistedCartItem? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final productId = value['productId'] as String?;
    final quantity = value['quantity'];
    final addedAt = DateTime.tryParse(value['addedAt'] as String? ?? '');
    if (productId == null ||
        productId.trim().isEmpty ||
        quantity is! int ||
        quantity <= 0) {
      return null;
    }
    return PersistedCartItem(
      productId: productId,
      quantity: quantity,
      addedAt: addedAt,
      selectedOptions: value['selectedOptions'] is Map
          ? jsonSafeMap(
              (value['selectedOptions'] as Map).map(
                (dynamic key, dynamic entryValue) =>
                    MapEntry(key.toString(), entryValue),
              ),
            )
          : const <String, dynamic>{},
    );
  }
}

class CartRevalidationResult {
  const CartRevalidationResult({
    required this.validItems,
    required this.removedProductIds,
  });

  final List<PersistedCartItem> validItems;
  final List<String> removedProductIds;
}

class PersistedCartStore {
  PersistedCartStore(this._store);

  final LocalJsonStore _store;

  Future<void> saveCartItems(
    String userId,
    List<PersistedCartItem> items,
  ) async {
    await _store.writeMap(_key(userId), <String, dynamic>{
      'schemaVersion': currentLocalStateSchemaVersion,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'items': items
          .where(
            (item) => item.productId.trim().isNotEmpty && item.quantity > 0,
          )
          .map((item) => item.toJson())
          .toList(growable: false),
    });
  }

  Future<List<PersistedCartItem>> readCartItems(String userId) async {
    final raw = await _store.readMap(_key(userId));
    final items = raw?['items'];
    if (items is! List) {
      return const <PersistedCartItem>[];
    }
    return items
        .map(PersistedCartItem.fromJson)
        .whereType<PersistedCartItem>()
        .toList(growable: false);
  }

  Future<CartRevalidationResult> revalidateCart({
    required String userId,
    required Future<bool> Function(String productId) isProductAvailable,
  }) async {
    final existing = await readCartItems(userId);
    final valid = <PersistedCartItem>[];
    final removed = <String>[];
    for (final item in existing) {
      if (await isProductAvailable(item.productId)) {
        valid.add(item);
      } else {
        removed.add(item.productId);
      }
    }
    await saveCartItems(userId, valid);
    return CartRevalidationResult(
      validItems: valid,
      removedProductIds: removed,
    );
  }

  Future<void> clearCart(String userId) => _store.remove(_key(userId));

  static String _key(String userId) {
    return AppStateScope.userKey(AppStateKeys.cartPrefix, userId, <String>[
      'items',
    ]);
  }
}
