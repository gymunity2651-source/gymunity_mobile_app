import 'launch_context_resolver.dart';

class SplashTimingPolicy {
  const SplashTimingPolicy();

  Duration minimumDurationFor(AppLaunchKind kind) {
    switch (kind) {
      case AppLaunchKind.firstInstallLaunch:
        return const Duration(milliseconds: 900);
      case AppLaunchKind.unauthenticatedLaunch:
        return const Duration(milliseconds: 500);
      case AppLaunchKind.authenticatedColdStart:
        return const Duration(milliseconds: 250);
      case AppLaunchKind.restoredSessionColdStart:
        return const Duration(milliseconds: 100);
      case AppLaunchKind.resumeHandledByLifecycle:
        return Duration.zero;
    }
  }
}
