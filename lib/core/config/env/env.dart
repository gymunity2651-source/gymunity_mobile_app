import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env', allowOptionalFields: true)
abstract class Env {
  @EnviedField(varName: 'SUPABASE_URL')
  static const String supabaseUrl = _Env.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_ANON_KEY')
  static const String supabaseAnonKey = _Env.supabaseAnonKey;

  @EnviedField(varName: 'OPENAI_MODEL')
  static const String openAiModel = _Env.openAiModel;

  // Documentation placeholders for Supabase Google provider setup.
  @EnviedField(varName: 'GOOGLE_WEB_CLIENT_ID', defaultValue: '')
  static const String googleWebClientId = _Env.googleWebClientId;

  @EnviedField(varName: 'GOOGLE_ANDROID_CLIENT_ID', defaultValue: '')
  static const String googleAndroidClientId = _Env.googleAndroidClientId;

  @EnviedField(varName: 'GOOGLE_IOS_CLIENT_ID', defaultValue: '')
  static const String googleIosClientId = _Env.googleIosClientId;

  static bool get hasValidSupabaseConfig => supabaseConfigError == null;

  static String? get supabaseConfigError {
    final url = supabaseUrl.trim();
    final anonKey = supabaseAnonKey.trim();

    if (url.isEmpty || anonKey.isEmpty) {
      return 'Supabase environment variables are missing.';
    }

    if (url.contains('example.supabase.co') ||
        anonKey.contains('public-anon-key-placeholder')) {
      return 'Supabase is still using placeholder credentials. Stop the app, regenerate env.g.dart, then run the app again.';
    }

    return null;
  }
}
