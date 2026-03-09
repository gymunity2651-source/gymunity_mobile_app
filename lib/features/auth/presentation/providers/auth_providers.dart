import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../controllers/auth_controller.dart';
import '../controllers/google_oauth_controller.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthControllerState>((ref) {
      return AuthController(ref);
    });

final googleOAuthTimeoutProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 20);
});

final googleOAuthPollIntervalProvider = Provider<Duration>((ref) {
  return const Duration(milliseconds: 500);
});

final googleOAuthControllerProvider =
    StateNotifierProvider<GoogleOAuthController, GoogleOAuthState>((ref) {
      return GoogleOAuthController(
        ref,
        authController: ref.read(authControllerProvider.notifier),
        readAuthControllerState: () => ref.read(authControllerProvider),
        authCallbackIngress: ref.read(authCallbackIngressProvider),
        timeout: ref.read(googleOAuthTimeoutProvider),
        pollInterval: ref.read(googleOAuthPollIntervalProvider),
      );
    });
