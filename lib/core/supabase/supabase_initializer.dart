import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'auth_token_project_ref.dart';

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
    await _clearMismatchedPersistedSession(config);
    _initialized = true;
  }

  static void _validateConfig() {
    final configError = AppConfig.current.validationErrorMessage;
    if (configError != null) {
      throw StateError(configError);
    }
  }

  static Future<void> _clearMismatchedPersistedSession(AppConfig config) async {
    final session = Supabase.instance.client.auth.currentSession;
    final accessToken = session?.accessToken.trim() ?? '';
    if (accessToken.isEmpty) {
      return;
    }

    if (!AuthTokenProjectRef.matchesProject(accessToken, config.supabaseUrl)) {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    }
  }
}
