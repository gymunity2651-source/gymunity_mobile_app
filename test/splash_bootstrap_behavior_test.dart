import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SplashScreen does not own a fixed display delay', () {
    final source = File(
      'lib/features/auth/presentation/screens/splash_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('_minimumSplashDuration')));
    expect(source, isNot(contains('Future<void>.delayed')));
    expect(source, isNot(contains('Future.delayed')));
  });

  test('AppBootstrapController owns adaptive launch timing', () {
    final source = File(
      'lib/features/auth/presentation/controllers/app_bootstrap_controller.dart',
    ).readAsStringSync();

    expect(source, contains('launchContextResolverProvider'));
    expect(source, contains('splashTimingPolicyProvider'));
    expect(source, contains('markFirstLaunchComplete'));
  });

  test('lifecycle resume does not route back to splash', () {
    final source = File(
      'lib/core/lifecycle/app_lifecycle_coordinator.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('AppRoutes.splash')));
  });
}
