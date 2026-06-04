abstract class RouteGuardResult {
  const RouteGuardResult();
}

class RouteAllowed extends RouteGuardResult {
  const RouteAllowed();
}

class RouteRedirect extends RouteGuardResult {
  const RouteRedirect({
    required this.routeName,
    this.arguments,
    this.clearStack = false,
  });

  final String routeName;
  final Object? arguments;
  final bool clearStack;
}

class RouteDenied extends RouteGuardResult {
  const RouteDenied({required this.reason, required this.fallbackRoute});

  final String reason;
  final String fallbackRoute;
}
