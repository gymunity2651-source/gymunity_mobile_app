import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_navigation_state_store.dart';
import 'route_persistence_policy.dart';

class AppRouteObserver extends NavigatorObserver {
  AppRouteObserver(this._store);

  final AppNavigationStateStore _store;
  RouteSettings? _lastPersistableSettings;

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
    _persistSettings(route.settings);
  }

  Future<void> persistCurrentRoute() async {
    final settings = _lastPersistableSettings;
    if (settings == null) {
      return;
    }
    await _persistSettings(settings);
  }

  Future<void> _persistSettings(RouteSettings settings) async {
    final name = settings.name;
    if (name == null ||
        !RoutePersistencePolicy.canPersist(name, settings.arguments)) {
      return;
    }
    final params = RoutePersistencePolicy.extractPersistableParams(
      name,
      settings.arguments,
    );
    _lastPersistableSettings = settings;
    await _store.saveLastSafeRoute(name, params: params);
  }
}
