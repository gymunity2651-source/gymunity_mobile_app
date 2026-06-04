import 'dart:convert';
import 'dart:io';

abstract class LocalJsonStore {
  Future<Map<String, dynamic>?> readMap(String key);

  Future<void> writeMap(String key, Map<String, dynamic> value);

  Future<void> remove(String key);

  Future<Set<String>> keys();

  Future<void> clearWhere(bool Function(String key) test) async {
    for (final key in await keys()) {
      if (test(key)) {
        await remove(key);
      }
    }
  }
}

class FileLocalJsonStore extends LocalJsonStore {
  FileLocalJsonStore(this.rootDirectory);

  final Directory rootDirectory;

  @override
  Future<Map<String, dynamic>?> readMap(String key) async {
    final file = await _fileForKey(key);
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Corrupt local state must never break app startup.
    }
    await remove(key);
    return null;
  }

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    final file = await _fileForKey(key);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(value), flush: true);
  }

  @override
  Future<void> remove(String key) async {
    final file = await _fileForKey(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<Set<String>> keys() async {
    if (!await rootDirectory.exists()) {
      return <String>{};
    }
    final keys = <String>{};
    await for (final entity in rootDirectory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      final name = entity.uri.pathSegments.last;
      final encoded = name.substring(0, name.length - '.json'.length);
      try {
        keys.add(utf8.decode(base64Url.decode(_padBase64(encoded))));
      } catch (_) {
        // Ignore files that were not created by this store.
      }
    }
    return keys;
  }

  Future<File> _fileForKey(String key) async {
    final encoded = base64Url
        .encode(utf8.encode(key))
        .replaceAll(RegExp(r'=+$'), '');
    return File('${rootDirectory.path}${Platform.pathSeparator}$encoded.json');
  }
}

String _padBase64(String value) {
  final remainder = value.length % 4;
  if (remainder == 0) {
    return value;
  }
  return value.padRight(value.length + 4 - remainder, '=');
}

Map<String, dynamic> jsonSafeMap(Map<String, dynamic> value) {
  final output = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key.trim();
    if (key.isEmpty || _isSensitiveKey(key)) {
      continue;
    }
    final safeValue = jsonSafeValue(entry.value);
    if (safeValue != null) {
      output[key] = safeValue;
    }
  }
  return output;
}

Object? jsonSafeValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is List) {
    return value
        .map((entry) => jsonSafeValue(entry))
        .where((entry) => entry != null)
        .toList(growable: false);
  }
  if (value is Map) {
    return jsonSafeMap(
      value.map(
        (dynamic key, dynamic entryValue) =>
            MapEntry(key.toString(), entryValue),
      ),
    );
  }
  return null;
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase();
  return normalized.contains('password') ||
      normalized.contains('otp') ||
      normalized.contains('token') ||
      normalized.contains('secret') ||
      normalized.contains('payment') ||
      normalized.contains('card');
}
