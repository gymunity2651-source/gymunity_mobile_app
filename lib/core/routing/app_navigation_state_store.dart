import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

typedef CurrentUserIdReader = Future<String?> Function();
typedef NavigationClock = DateTime Function();

// Dashboard restoration intentionally has no separate persistence API. Each role
// currently has a single canonical dashboard, so AuthRouteResolver falls back to
// routeForRoleDashboard(role) instead of keeping duplicate dashboard state.
const bool storeHasNoLastDashboardFallbackApi = true;

class SavedRouteState {
  const SavedRouteState({
    required this.userId,
    required this.routeName,
    required this.savedAt,
    this.params = const <String, dynamic>{},
  });

  final String userId;
  final String routeName;
  final DateTime savedAt;
  final Map<String, dynamic> params;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'routeName': routeName,
      'savedAt': savedAt.toUtc().toIso8601String(),
      'params': params,
    };
  }

  static SavedRouteState? fromJson(Map<String, dynamic> json) {
    final userId = json['userId'] as String?;
    final routeName = json['routeName'] as String?;
    final savedAtRaw = json['savedAt'] as String?;
    if (userId == null || routeName == null || savedAtRaw == null) {
      return null;
    }
    final savedAt = DateTime.tryParse(savedAtRaw);
    if (savedAt == null) {
      return null;
    }
    return SavedRouteState(
      userId: userId,
      routeName: routeName,
      savedAt: savedAt,
      params: _stringKeyedMap(json['params']),
    );
  }
}

abstract class AppNavigationStateStore {
  Future<void> saveLastSafeRoute(
    String routeName, {
    Map<String, dynamic>? params,
  });

  Future<SavedRouteState?> readLastSafeRoute();

  Future<void> clearLastSafeRoute();

  Future<void> saveLastTabIndex(String area, int index);

  Future<int?> readLastTabIndex(String area);

  Future<void> clearUserScopedState();
}

class SharedPreferencesAppNavigationStateStore
    implements AppNavigationStateStore {
  SharedPreferencesAppNavigationStateStore(
    this._preferences, {
    required CurrentUserIdReader currentUserIdReader,
    NavigationClock? clock,
  }) : _currentUserIdReader = currentUserIdReader,
       _clock = clock ?? DateTime.now;

  static const String _lastSafeRouteKey =
      'app_navigation_state.last_safe_route';
  static const String _tabPrefix = 'app_navigation_state.last_tab';

  final SharedPreferences _preferences;
  final CurrentUserIdReader _currentUserIdReader;
  final NavigationClock _clock;

  @override
  Future<void> saveLastSafeRoute(
    String routeName, {
    Map<String, dynamic>? params,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) {
      return;
    }
    final state = SavedRouteState(
      userId: userId,
      routeName: routeName,
      savedAt: _clock().toUtc(),
      params: _persistableParams(params),
    );
    await _preferences.setString(_lastSafeRouteKey, jsonEncode(state.toJson()));
  }

  @override
  Future<SavedRouteState?> readLastSafeRoute() async {
    final raw = _preferences.getString(_lastSafeRouteKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return SavedRouteState.fromJson(decoded);
    } catch (_) {
      await clearLastSafeRoute();
      return null;
    }
  }

  @override
  Future<void> clearLastSafeRoute() async {
    await _preferences.remove(_lastSafeRouteKey);
  }

  @override
  Future<void> saveLastTabIndex(String area, int index) async {
    final userId = await _currentUserId();
    if (userId == null || area.trim().isEmpty || index < 0) {
      return;
    }
    await _preferences.setInt(_tabKey(userId, area), index);
  }

  @override
  Future<int?> readLastTabIndex(String area) async {
    final userId = await _currentUserId();
    if (userId == null || area.trim().isEmpty) {
      return null;
    }
    return _preferences.getInt(_tabKey(userId, area));
  }

  @override
  Future<void> clearUserScopedState() async {
    final userId = await _currentUserId();
    await clearLastSafeRoute();
    final keys = _preferences.getKeys();
    for (final key in keys) {
      final shouldRemove = userId == null
          ? key.startsWith(_tabPrefix)
          : key.startsWith('$_tabPrefix.$userId.');
      if (shouldRemove) {
        await _preferences.remove(key);
      }
    }
  }

  Future<String?> _currentUserId() async {
    final userId = (await _currentUserIdReader())?.trim();
    return userId == null || userId.isEmpty ? null : userId;
  }

  static String _tabKey(String userId, String area) =>
      '$_tabPrefix.$userId.${area.trim()}';
}

Map<String, dynamic> _persistableParams(Map<String, dynamic>? params) {
  if (params == null || params.isEmpty) {
    return const <String, dynamic>{};
  }
  final sanitized = <String, dynamic>{};
  for (final entry in params.entries) {
    final value = entry.value;
    if (value == null || value is String || value is num || value is bool) {
      sanitized[entry.key] = value;
    }
  }
  return sanitized;
}

Map<String, dynamic> _stringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return _persistableParams(value);
  }
  if (value is Map) {
    return _persistableParams(
      value.map(
        (dynamic key, dynamic entryValue) =>
            MapEntry(key.toString(), entryValue),
      ),
    );
  }
  return const <String, dynamic>{};
}
