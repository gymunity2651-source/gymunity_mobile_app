import 'app_state_keys.dart';
import 'app_state_scope.dart';
import 'local_json_store.dart';

typedef PersistenceClock = DateTime Function();

class PersistedDraftStore {
  PersistedDraftStore(
    this._store, {
    Duration ttl = const Duration(days: 14),
    PersistenceClock? clock,
  }) : _ttl = ttl,
       _clock = clock ?? DateTime.now;

  final LocalJsonStore _store;
  final Duration _ttl;
  final PersistenceClock _clock;

  Future<void> saveDraft({
    required String userId,
    required String draftType,
    required String draftId,
    required Map<String, dynamic> data,
  }) async {
    final savedAt = _clock().toUtc();
    await _store.writeMap(_key(userId, draftType, draftId), <String, dynamic>{
      'schemaVersion': currentLocalStateSchemaVersion,
      'savedAt': savedAt.toIso8601String(),
      'expiresAt': savedAt.add(_ttl).toIso8601String(),
      'data': jsonSafeMap(data),
    });
  }

  Future<Map<String, dynamic>?> readDraft({
    required String userId,
    required String draftType,
    required String draftId,
  }) async {
    final key = _key(userId, draftType, draftId);
    final raw = await _store.readMap(key);
    if (raw == null) {
      return null;
    }
    final savedAt = DateTime.tryParse(raw['savedAt'] as String? ?? '');
    final expiresAt = DateTime.tryParse(raw['expiresAt'] as String? ?? '');
    final data = raw['data'];
    if (savedAt == null ||
        expiresAt == null ||
        expiresAt.isBefore(_clock()) ||
        data is! Map) {
      await _store.remove(key);
      return null;
    }
    return jsonSafeMap(
      data.map((dynamic key, dynamic value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> clearDraft({
    required String userId,
    required String draftType,
    required String draftId,
  }) {
    return _store.remove(_key(userId, draftType, draftId));
  }

  Future<void> clearUserDrafts(String userId) {
    return _store.clearWhere(
      (key) =>
          AppStateScope.belongsToUser(key, AppStateKeys.draftsPrefix, userId),
    );
  }

  static String _key(String userId, String draftType, String draftId) {
    return AppStateScope.userKey(AppStateKeys.draftsPrefix, userId, <String>[
      draftType,
      draftId,
    ]);
  }
}
