import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../controllers/app_bootstrap_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/google_oauth_controller.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthControllerState>((ref) {
      return AuthController(ref);
    });

final authFlowTimeoutProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 20);
});

final authFlowPollIntervalProvider = Provider<Duration>((ref) {
  return const Duration(milliseconds: 500);
});

final authFlowControllerProvider =
    StateNotifierProvider<AuthFlowController, AuthFlowState>((ref) {
      return AuthFlowController(
        ref,
        authController: ref.read(authControllerProvider.notifier),
        readAuthControllerState: () => ref.read(authControllerProvider),
        authCallbackIngress: ref.read(authCallbackIngressProvider),
        timeout: ref.read(authFlowTimeoutProvider),
        pollInterval: ref.read(authFlowPollIntervalProvider),
      );
    });

final googleOAuthTimeoutProvider = authFlowTimeoutProvider;
final googleOAuthPollIntervalProvider = authFlowPollIntervalProvider;
final googleOAuthControllerProvider = authFlowControllerProvider;

final appBootstrapControllerProvider =
    StateNotifierProvider<AppBootstrapController, AppBootstrapState>((ref) {
      return AppBootstrapController(ref);
    });
