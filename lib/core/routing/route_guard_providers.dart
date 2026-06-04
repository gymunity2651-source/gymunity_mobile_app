import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/logout_providers.dart';
import '../di/providers.dart';
import 'route_guard_service.dart';

final routeGuardServiceProvider = Provider<RouteGuardService>((ref) {
  return RouteGuardService(
    userRepository: ref.watch(userRepositoryProvider),
    logout: ref.watch(logoutCoordinatorProvider).logout,
  );
});
