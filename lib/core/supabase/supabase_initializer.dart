import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseInitializer {
  SupabaseInitializer._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;

    _validateConfig();
    final config = AppConfig.current;

    await Supabase.initialize(
      url: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    _initialized = true;
  }

  static void _validateConfig() {
    final configError = AppConfig.current.validationErrorMessage;
    if (configError != null) {
      throw StateError(configError);
    }
  }
}
