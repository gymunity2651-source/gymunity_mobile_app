import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_navigation_state_store.dart';
import 'route_persistence_policy.dart';

class AppRouteObserver extends NavigatorObserver {
  AppRouteObserver(this._store);

  final AppNavigationStateStore _store;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _persist(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _persist(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _persist(previousRoute);
    }
  }

  void _persist(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null ||
        !RoutePersistencePolicy.canPersist(name, route.settings.arguments)) {
      return;
    }
    final params = RoutePersistencePolicy.extractPersistableParams(
      name,
      route.settings.arguments,
    );
    unawaited(_store.saveLastSafeRoute(name, params: params));
    if (RoutePersistencePolicy.isDashboardRoute(name)) {
      unawaited(_store.saveLastDashboardRoute(name));
    }
  }
}
