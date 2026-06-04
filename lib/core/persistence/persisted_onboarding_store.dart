import 'app_state_keys.dart';
import 'app_state_scope.dart';
import 'local_json_store.dart';

class OnboardingLocalState {
  OnboardingLocalState({
    required this.userId,
    required this.role,
    required this.stepIndex,
    this.partialData = const <String, dynamic>{},
    DateTime? updatedAt,
  }) : updatedAt = (updatedAt ?? DateTime.now()).toUtc();

  final String userId;
  final String role;
  final int stepIndex;
  final Map<String, dynamic> partialData;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': currentLocalStateSchemaVersion,
      'userId': userId,
      'role': role,
      'stepIndex': stepIndex,
      'partialData': jsonSafeMap(partialData),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static OnboardingLocalState? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final userId = json['userId'] as String?;
    final role = json['role'] as String?;
    final stepIndex = json['stepIndex'];
    if (userId == null || role == null || stepIndex is! int || stepIndex < 0) {
      return null;
    }
    final partialData = json['partialData'];
    return OnboardingLocalState(
      userId: userId,
      role: role,
      stepIndex: stepIndex,
      partialData: partialData is Map
          ? jsonSafeMap(
              partialData.map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : const <String, dynamic>{},
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

class PersistedOnboardingStore {
  PersistedOnboardingStore(this._store);

  final LocalJsonStore _store;

  Future<void> saveStep({
    required String userId,
    required String role,
    required int stepIndex,
    Map<String, dynamic>? partialData,
  }) {
    if (stepIndex < 0) {
      return Future<void>.value();
    }
    return _store.writeMap(
      _key(userId, role),
      OnboardingLocalState(
        userId: userId,
        role: role,
        stepIndex: stepIndex,
        partialData: partialData ?? const <String, dynamic>{},
      ).toJson(),
    );
  }

  Future<OnboardingLocalState?> readStep({
    required String userId,
    required String role,
  }) {
    return _store
        .readMap(_key(userId, role))
        .then(OnboardingLocalState.fromJson);
  }

  Future<void> clearOnboardingState({
    required String userId,
    required String role,
  }) {
    return _store.remove(_key(userId, role));
  }

  Future<void> clearIncompatibleRoleState({
    required String userId,
    required String activeRole,
  }) {
    return _store.clearWhere(
      (key) =>
          AppStateScope.belongsToUser(
            key,
            AppStateKeys.onboardingPrefix,
            userId,
          ) &&
          !key.endsWith('.${activeRole.trim()}'),
    );
  }

  Future<void> clearUserOnboardingState(String userId) {
    return _store.clearWhere(
      (key) => AppStateScope.belongsToUser(
        key,
        AppStateKeys.onboardingPrefix,
        userId,
      ),
    );
  }

  static String _key(String userId, String role) {
    return AppStateScope.userKey(
      AppStateKeys.onboardingPrefix,
      userId,
      <String>[role],
    );
  }
}
