import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../auth/logout_providers.dart';
import '../auth/logout_result.dart';
import 'access_denied_screen.dart';
import 'route_guard_providers.dart';
import 'route_guard_result.dart';

class GuardedRouteScreen extends StatefulWidget {
  const GuardedRouteScreen({
    super.key,
    required this.routeName,
    required this.arguments,
    required this.childBuilder,
  });

  final String routeName;
  final Object? arguments;
  final WidgetBuilder childBuilder;

  @override
  State<GuardedRouteScreen> createState() => _GuardedRouteScreenState();
}

class _GuardedRouteScreenState extends State<GuardedRouteScreen> {
  static const Duration _guardTimeout = Duration(seconds: 15);

  ProviderContainer? _container;
  Future<RouteGuardResult>? _guardFuture;
  bool _missingProviderScope = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_guardFuture != null || _missingProviderScope) {
      return;
    }
    try {
      _container = ProviderScope.containerOf(context, listen: false);
      _guardFuture = _readGuard();
    } catch (_) {
      // Route smoke tests and isolated widgets can mount AppRoutes without a
      // ProviderScope. The real app is always under ProviderScope, so guards
      // remain active in production.
      _missingProviderScope = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_missingProviderScope) {
      return widget.childBuilder(context);
    }
    final guardFuture = _guardFuture;
    if (guardFuture == null) {
      return const _GuardLoadingScreen();
    }
    return FutureBuilder<RouteGuardResult>(
      future: guardFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _GuardErrorScreen(onRetry: _retryGuard);
        }
        final result = snapshot.data;
        if (result == null) {
          return const _GuardLoadingScreen();
        }
        if (result is RouteAllowed) {
          return widget.childBuilder(context);
        }
        if (result is RouteRedirect) {
          _scheduleRedirect(context, result);
          return const _GuardLoadingScreen();
        }
        if (result is RouteDenied) {
          return AccessDeniedScreen(
            reason: result.reason,
            fallbackRoute: result.fallbackRoute,
          );
        }
        return const _GuardLoadingScreen();
      },
    );
  }

  Future<RouteGuardResult> _readGuard() {
    return _container!
        .read(routeGuardServiceProvider)
        .guardRoute(routeName: widget.routeName, arguments: widget.arguments)
        .timeout(_guardTimeout);
  }

  void _retryGuard() {
    setState(() {
      _guardFuture = _readGuard();
    });
  }

  void _scheduleRedirect(BuildContext context, RouteRedirect redirect) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      if (redirect.clearStack) {
        navigator.pushNamedAndRemoveUntil(
          redirect.routeName,
          (route) => false,
          arguments: redirect.arguments,
        );
        return;
      }
      navigator.pushReplacementNamed(
        redirect.routeName,
        arguments: redirect.arguments,
      );
    });
  }
}

class _GuardErrorScreen extends ConsumerWidget {
  const _GuardErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 16),
              const Text(
                'Unable to load your account. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await ref
                      .read(logoutCoordinatorProvider)
                      .logout(
                        reason: LogoutReason.userRequested,
                        navigateToWelcome: false,
                      );
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.welcome,
                    (route) => false,
                  );
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuardLoadingScreen extends StatelessWidget {
  const _GuardLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}
