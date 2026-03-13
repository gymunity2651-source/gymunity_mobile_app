import '../config/app_config.dart';

class AppAuthConstants {
  AppAuthConstants._();

  static String get oauthRedirect => AppConfig.current.authRedirectUri;
  static String get oauthScheme => AppConfig.current.authRedirectScheme;
  static String get oauthHost => AppConfig.current.authRedirectHost;
}
