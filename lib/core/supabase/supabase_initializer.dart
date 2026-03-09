import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env/env.dart';

class SupabaseInitializer {
  SupabaseInitializer._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    _validateConfig();

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    _initialized = true;
  }

  static void _validateConfig() {
    final configError = Env.supabaseConfigError;
    if (configError != null) {
      throw StateError(configError);
    }
  }
}
