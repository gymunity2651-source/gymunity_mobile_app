import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/auth/presentation/controllers/launch_context_resolver.dart';
import 'package:my_app/features/auth/presentation/controllers/splash_timing_policy.dart';

void main() {
  group('SplashTimingPolicy', () {
    const policy = SplashTimingPolicy();

    test('first install launch uses full splash duration', () {
      expect(
        policy.minimumDurationFor(AppLaunchKind.firstInstallLaunch),
        const Duration(milliseconds: 900),
      );
    });

    test('unauthenticated launch uses shorter splash duration', () {
      expect(
        policy.minimumDurationFor(AppLaunchKind.unauthenticatedLaunch),
        const Duration(milliseconds: 500),
      );
    });

    test('authenticated cold start uses short splash duration', () {
      expect(
        policy.minimumDurationFor(AppLaunchKind.authenticatedColdStart),
        const Duration(milliseconds: 250),
      );
    });

    test('restored session cold start uses very short splash duration', () {
      expect(
        policy.minimumDurationFor(AppLaunchKind.restoredSessionColdStart),
        const Duration(milliseconds: 100),
      );
    });

    test('resume lifecycle does not use splash duration', () {
      expect(
        policy.minimumDurationFor(AppLaunchKind.resumeHandledByLifecycle),
        Duration.zero,
      );
    });
  });
}
