import 'dart:io';

import 'app_state_keys.dart';
import 'app_state_scope.dart';
import 'local_json_store.dart';

enum OfflineActionType {
  preferenceUpdate,
  cartUpdate,
  workoutCompletionSync,
  aiFeedbackSubmit,
  checkInSubmission,
  uploadMetadata,
  productDraftSubmit,
  payment,
  auth,
}

class OfflineAction {
  OfflineAction({
    required this.id,
    required this.userId,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.lastFailureReason,
  });

  factory OfflineAction.create({
    String? id,
    required String userId,
    required OfflineActionType type,
    required Map<String, dynamic> payload,
  }) {
    final now = DateTime.now().toUtc();
    return OfflineAction(
      id: id ?? '${now.microsecondsSinceEpoch}-$userId-${type.name}',
      userId: userId,
      type: type,
      payload: jsonSafeMap(payload),
      createdAt: now,
    );
  }

  final String id;
  final String userId;
  final OfflineActionType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? lastFailureReason;

  OfflineAction copyWith({
    int? retryCount,
    DateTime? lastAttemptAt,
    String? lastFailureReason,
  }) {
    return OfflineAction(
      id: id,
      userId: userId,
      type: type,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastFailureReason: lastFailureReason ?? this.lastFailureReason,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'type': type.name,
      'payload': jsonSafeMap(payload),
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'lastFailureReason': lastFailureReason,
    };
  }

  static OfflineAction? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final id = value['id'] as String?;
    final userId = value['userId'] as String?;
    final typeName = value['type'] as String?;
    final createdAt = DateTime.tryParse(value['createdAt'] as String? ?? '');
    final type = OfflineActionType.values
        .where((candidate) => candidate.name == typeName)
        .firstOrNull;
    if (id == null || userId == null || type == null || createdAt == null) {
      return null;
    }
    final payload = value['payload'];
    return OfflineAction(
      id: id,
      userId: userId,
      type: type,
      payload: payload is Map
          ? jsonSafeMap(
              payload.map(
                (dynamic key, dynamic entryValue) =>
                    MapEntry(key.toString(), entryValue),
              ),
            )
          : const <String, dynamic>{},
      createdAt: createdAt,
      retryCount: value['retryCount'] is int ? value['retryCount'] as int : 0,
      lastAttemptAt: DateTime.tryParse(value['lastAttemptAt'] as String? ?? ''),
      lastFailureReason: value['lastFailureReason'] as String?,
    );
  }
}

class OfflineActionQueue {
  OfflineActionQueue(this._store, {this.maxRetryCount = 3});

  final LocalJsonStore _store;
  final int maxRetryCount;

  Future<void> enqueue(OfflineAction action) async {
    if (!_isSafeToQueue(action.type)) {
      throw ArgumentError('Offline action type ${action.type.name} is unsafe');
    }
    final actions = await pendingActions(action.userId);
    await _writeActions(action.userId, <OfflineAction>[...actions, action]);
  }

  Future<List<OfflineAction>> pendingActions(String userId) async {
    final raw = await _store.readMap(_key(userId));
    final items = raw?['actions'];
    if (items is! List) {
      return const <OfflineAction>[];
    }
    return items
        .map(OfflineAction.fromJson)
        .whereType<OfflineAction>()
        .where((action) => action.retryCount < maxRetryCount)
        .toList(growable: false);
  }

  Future<void> markCompleted(String userId, String actionId) async {
    final remaining = (await pendingActions(
      userId,
    )).where((action) => action.id != actionId).toList(growable: false);
    await _writeActions(userId, remaining);
  }

  Future<void> markFailed(String userId, String actionId, String reason) async {
    final now = DateTime.now().toUtc();
    final updated = (await pendingActions(userId))
        .map((action) {
          if (action.id != actionId) {
            return action;
          }
          return action.copyWith(
            retryCount: action.retryCount + 1,
            lastAttemptAt: now,
            lastFailureReason: reason,
          );
        })
        .toList(growable: false);
    await _writeActions(userId, updated);
  }

  Future<void> retryPendingActions({
    required String userId,
    required Future<void> Function(OfflineAction action) handler,
  }) async {
    final actions = await pendingActions(userId);
    for (final action in actions) {
      final missingUpload = await _missingUploadFile(action);
      if (missingUpload != null) {
        await markFailed(userId, action.id, missingUpload);
        continue;
      }
      try {
        await handler(action);
        await markCompleted(userId, action.id);
      } catch (error) {
        await markFailed(userId, action.id, error.toString());
      }
    }
  }

  Future<void> clearUserActions(String userId) => _store.remove(_key(userId));

  Future<void> _writeActions(String userId, List<OfflineAction> actions) {
    return _store.writeMap(_key(userId), <String, dynamic>{
      'schemaVersion': currentLocalStateSchemaVersion,
      'actions': actions.map((action) => action.toJson()).toList(),
    });
  }

  Future<String?> _missingUploadFile(OfflineAction action) async {
    if (action.type != OfflineActionType.uploadMetadata) {
      return null;
    }
    final filePath = action.payload['filePath'];
    if (filePath is String &&
        filePath.trim().isNotEmpty &&
        !await File(filePath).exists()) {
      return 'Missing upload file: $filePath';
    }
    return null;
  }

  static bool _isSafeToQueue(OfflineActionType type) {
    return type != OfflineActionType.payment && type != OfflineActionType.auth;
  }

  static String _key(String userId) {
    return AppStateScope.userKey(
      AppStateKeys.offlineQueuePrefix,
      userId,
      <String>['actions'],
    );
  }
}
