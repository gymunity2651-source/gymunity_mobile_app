class AppStateScope {
  const AppStateScope._();

  static String userKey(String prefix, String userId, Iterable<String> parts) {
    return <String>[prefix, _clean(userId), ...parts.map(_clean)].join('.');
  }

  static String deviceKey(String prefix, Iterable<String> parts) {
    return <String>[prefix, ...parts.map(_clean)].join('.');
  }

  static bool belongsToUser(String key, String prefix, String userId) {
    return key.startsWith('$prefix.${_clean(userId)}');
  }

  static String _clean(String value) {
    return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }
}
