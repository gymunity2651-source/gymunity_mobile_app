class AppAuthConstants {
  AppAuthConstants._();

  // This redirect must match Supabase Dashboard -> Authentication
  // -> URL Configuration -> Additional Redirect URLs.
  static const String googleOAuthRedirect = 'gymunity://auth-callback';
  static const String googleOAuthScheme = 'gymunity';
  static const String googleOAuthHost = 'auth-callback';
}
