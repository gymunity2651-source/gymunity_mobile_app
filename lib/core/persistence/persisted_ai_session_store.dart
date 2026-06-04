import 'app_state_keys.dart';
import 'app_state_scope.dart';

import 'local_json_store.dart';

class PersistedAiSessionStore {
  PersistedAiSessionStore(this._store);

  final LocalJsonStore _store;

  bool get autoSendPromptDrafts => false;

  Future<void> saveLastSessionId(String userId, String sessionId) async {
    if (sessionId.trim().isEmpty) {
      return;
    }
    await _store.writeMap(_sessionKey(userId), <String, dynamic>{
      'schemaVersion': currentLocalStateSchemaVersion,
      'sessionId': sessionId,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<String?> readLastSessionId(String userId) async {
    final raw = await _store.readMap(_sessionKey(userId));
    final sessionId = raw?['sessionId'];
    return sessionId is String && sessionId.trim().isNotEmpty
        ? sessionId
        : null;
  }

  Future<String?> restoreLastSessionId(
    String userId, {
    required Future<bool> Function(String sessionId) belongsToCurrentUser,
  }) async {
    final sessionId = await readLastSessionId(userId);
    if (sessionId == null) {
      return null;
    }
    if (!await belongsToCurrentUser(sessionId)) {
      await _store.remove(_sessionKey(userId));
      return null;
    }
    return sessionId;
  }

  Future<void> savePromptDraft(String userId, String draftText) async {
    await _store.writeMap(_promptKey(userId), <String, dynamic>{
      'schemaVersion': currentLocalStateSchemaVersion,
      'draftText': draftText,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<String?> readPromptDraft(String userId) async {
    final raw = await _store.readMap(_promptKey(userId));
    final draft = raw?['draftText'];
    return draft is String ? draft : null;
  }

  Future<void> clearAiState(String userId) {
    return _store.clearWhere(
      (key) => AppStateScope.belongsToUser(key, AppStateKeys.aiPrefix, userId),
    );
  }

  static String _sessionKey(String userId) {
    return AppStateScope.userKey(AppStateKeys.aiPrefix, userId, <String>[
      'last_session',
    ]);
  }

  static String _promptKey(String userId) {
    return AppStateScope.userKey(AppStateKeys.aiPrefix, userId, <String>[
      'prompt_draft',
    ]);
  }
}
