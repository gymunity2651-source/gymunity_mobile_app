import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/routing/access_denied_screen.dart';
import 'package:my_app/core/routing/guarded_route_factory.dart';
import 'package:my_app/core/routing/route_guard_providers.dart';
import 'package:my_app/core/routing/route_guard_result.dart';
import 'package:my_app/core/routing/route_guard_service.dart';

void main() {
  testWidgets('protected child is not built before guard allows', (tester) async {
    var childBuilds = 0;
    final guard = _FakeRouteGuardService(
      result: Future<RouteGuardResult>.delayed(
        const Duration(milliseconds: 50),
        () => const RouteAllowed(),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [routeGuardServiceProvider.overrideWithValue(guard)],
        child: MaterialApp(
          home: GuardedRouteScreen(
            routeName: AppRoutes.memberHome,
            arguments: null,
            childBuilder: (_) {
              childBuilds++;
              return const Text('protected');
            },
          ),
        ),
      ),
    );

    expect(childBuilds, 0);
    expect(find.text('protected'), findsNothing);

    await tester.pump(const Duration(milliseconds: 60));

    expect(childBuilds, 1);
    expect(find.text('protected'), findsOneWidget);
  });

  testWidgets('denied route shows access denied fallback', (tester) async {
    final guard = _FakeRouteGuardService(
      result: Future<RouteGuardResult>.value(
        const RouteDenied(
          reason: 'Coach access required',
          fallbackRoute: AppRoutes.memberHome,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [routeGuardServiceProvider.overrideWithValue(guard)],
        child: MaterialApp(
          routes: {AppRoutes.memberHome: (_) => const Text('home')},
          home: GuardedRouteScreen(
            routeName: AppRoutes.coachDashboard,
            arguments: null,
            childBuilder: (_) => const Text('protected'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AccessDeniedScreen), findsOneWidget);
    expect(find.text('Coach access required'), findsOneWidget);
    expect(find.text('protected'), findsNothing);
  });
}

class _FakeRouteGuardService implements RouteGuardService {
  _FakeRouteGuardService({required this.result});

  final Future<RouteGuardResult> result;

  @override
  Future<RouteGuardResult> guardRoute({
    required String routeName,
    Object? arguments,
  }) {
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
