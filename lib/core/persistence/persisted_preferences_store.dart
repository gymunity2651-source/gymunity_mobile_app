import 'app_state_keys.dart';
import 'app_state_scope.dart';
import 'local_json_store.dart';

class PersistedPreferencesStore {
  PersistedPreferencesStore(this._store);

  final LocalJsonStore _store;

  Future<void> saveDevicePreference(String key, Object? value) {
    final safeValue = jsonSafeValue(value);
    if (safeValue == null) {
      return Future<void>.value();
    }
    return _store.writeMap(_deviceKey(key), <String, dynamic>{
      'schemaVersion': currentLocalStateSchemaVersion,
      'value': safeValue,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Object?> readDevicePreference(String key) async {
    return (await _store.readMap(_deviceKey(key)))?['value'];
  }

  Future<void> saveUserPreference({
    required String userId,
    required String key,
    required Object? value,
  }) {
    final safeValue = jsonSafeValue(value);
    if (safeValue == null) {
      return Future<void>.value();
    }
    return _store.writeMap(_userKey(userId, key), <String, dynamic>{
      'schemaVersion': currentLocalStateSchemaVersion,
      'value': safeValue,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Object?> readUserPreference({
    required String userId,
    required String key,
  }) async {
    return (await _store.readMap(_userKey(userId, key)))?['value'];
  }

  Future<void> clearUserPreferences(String userId) {
    return _store.clearWhere(
      (key) => AppStateScope.belongsToUser(
        key,
        AppStateKeys.userPreferencesPrefix,
        userId,
      ),
    );
  }

  static String _deviceKey(String key) {
    return AppStateScope.deviceKey(
      AppStateKeys.devicePreferencesPrefix,
      <String>[key],
    );
  }

  static String _userKey(String userId, String key) {
    return AppStateScope.userKey(
      AppStateKeys.userPreferencesPrefix,
      userId,
      <String>[key],
    );
  }
}
