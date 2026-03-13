import 'dart:convert';

import 'package:flutter/services.dart';

import 'app_config.dart';

class LocalRuntimeConfigLoader {
  LocalRuntimeConfigLoader._();

  static const String _assetPath = 'assets/config/local_env.json';

  static Future<void> primeIfNeeded() async {
    if (AppConfig.current.validationErrorMessage == null) {
      return;
    }

    try {
      final raw = await rootBundle.loadString(_assetPath);
      if (raw.trim().isEmpty) {
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }

      final values = <String, String>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value != null) {
          values[key] = value.toString();
        }
      }

      if (values.isEmpty) {
        return;
      }

      final config = AppConfig.fromMap(values);
      if (config.validationErrorMessage == null) {
        AppConfig.debugOverrideForTests(config);
      }
    } catch (_) {
      // No local runtime override is available. The app will keep the normal
      // config-required state if compile-time defines are missing.
    }
  }
}
