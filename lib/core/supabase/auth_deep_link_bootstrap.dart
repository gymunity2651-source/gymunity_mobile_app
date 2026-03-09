import 'auth_callback_ingress.dart';

class AuthDeepLinkBootstrap {
  AuthDeepLinkBootstrap._();

  static final AuthDeepLinkBootstrap instance = AuthDeepLinkBootstrap._();

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await PlatformAuthCallbackIngress.instance.start();
  }

  Future<void> dispose() async {
    await PlatformAuthCallbackIngress.instance.dispose();
    _started = false;
  }
}
