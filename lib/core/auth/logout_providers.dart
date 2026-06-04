import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logout_coordinator.dart';

final logoutCoordinatorProvider = Provider<LogoutCoordinator>((ref) {
  return LogoutCoordinator(
    ref,
    serviceStopper: ref.watch(logoutServiceStopperProvider),
    navigator: ref.watch(logoutNavigatorProvider),
  );
});

final logoutServiceStopperProvider = Provider<LogoutServiceStopper>((ref) {
  return RiverpodLogoutServiceStopper(ref);
});

final logoutNavigatorProvider = Provider<LogoutNavigator>((ref) {
  return AppLogoutNavigator(ref);
});
