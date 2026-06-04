import '../../../../core/routing/app_navigation_state_store.dart';
import '../../../../core/routing/route_persistence_policy.dart';
import '../../../user/domain/repositories/user_repository.dart';
import '../../data/launch_state_store.dart';

enum AppLaunchKind {
  firstInstallLaunch,
  unauthenticatedLaunch,
  authenticatedColdStart,
  restoredSessionColdStart,
  resumeHandledByLifecycle,
}

class LaunchContextResolver {
  const LaunchContextResolver({
    required UserRepository userRepository,
    required AppNavigationStateStore navigationStateStore,
    required LaunchStateStore launchStateStore,
  }) : _userRepository = userRepository,
       _navigationStateStore = navigationStateStore,
       _launchStateStore = launchStateStore;

  final UserRepository _userRepository;
  final AppNavigationStateStore _navigationStateStore;
  final LaunchStateStore _launchStateStore;

  Future<AppLaunchKind> resolve() async {
    if (!await _launchStateStore.hasCompletedFirstLaunch()) {
      return AppLaunchKind.firstInstallLaunch;
    }

    final currentUser = await _userRepository.getCurrentUser();
    if (currentUser == null) {
      return AppLaunchKind.unauthenticatedLaunch;
    }

    final savedRoute = await _navigationStateStore.readLastSafeRoute();
    if (savedRoute != null &&
        savedRoute.userId == currentUser.id &&
        RoutePersistencePolicy.isPersistable(savedRoute.routeName)) {
      return AppLaunchKind.restoredSessionColdStart;
    }

    return AppLaunchKind.authenticatedColdStart;
  }
}
