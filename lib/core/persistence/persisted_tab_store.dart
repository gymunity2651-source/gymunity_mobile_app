import 'app_state_keys.dart';
import 'app_state_scope.dart';
import 'local_json_store.dart';

class PersistedTabStore {
  PersistedTabStore(this._store);

  final LocalJsonStore _store;

  Future<void> saveSelectedTab({
    required String userId,
    required String area,
    required int index,
  }) async {
    if (userId.trim().isEmpty || area.trim().isEmpty || index < 0) {
      return;
    }
    await _store.writeMap(_key(userId, area), <String, dynamic>{
      'schemaVersion': currentLocalStateSchemaVersion,
      'index': index,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<int?> readSelectedTab({
    required String userId,
    required String area,
  }) async {
    final raw = await _store.readMap(_key(userId, area));
    final index = raw?['index'];
    return index is int && index >= 0 ? index : null;
  }

  Future<void> clearUserTabs(String userId) {
    return _store.clearWhere(
      (key) =>
          AppStateScope.belongsToUser(key, AppStateKeys.tabsPrefix, userId),
    );
  }

  static String _key(String userId, String area) {
    return AppStateScope.userKey(AppStateKeys.tabsPrefix, userId, <String>[
      area,
    ]);
  }
}
