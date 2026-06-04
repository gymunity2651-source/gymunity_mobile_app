import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/routing/app_navigation_state_store.dart';
import 'package:my_app/features/coach/presentation/screens/coach_workspace_shell.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('coach dashboard restores a valid saved tab index', (
    tester,
  ) async {
    await _pumpCoachShell(
      tester,
      _SavedTabNavigationStateStore(area: 'coach_dashboard', index: 3),
    );

    expect(find.text('Calendar'), findsWidgets);
  });

  testWidgets('coach dashboard ignores an invalid saved tab index', (
    tester,
  ) async {
    await _pumpCoachShell(
      tester,
      _SavedTabNavigationStateStore(area: 'coach_dashboard', index: 99),
    );

    expect(find.text('Today'), findsWidgets);
  });
}

Future<void> _pumpCoachShell(
  WidgetTester tester,
  AppNavigationStateStore navigationStateStore,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        appNavigationStateStoreProvider.overrideWithValue(navigationStateStore),
      ],
      child: const MaterialApp(home: CoachWorkspaceShell()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

class _SavedTabNavigationStateStore implements AppNavigationStateStore {
  const _SavedTabNavigationStateStore({
    required this.area,
    required this.index,
  });

  final String area;
  final int index;

  @override
  Future<void> clearLastSafeRoute() async {}

  @override
  Future<void> clearUserScopedState() async {}

  @override
  Future<SavedRouteState?> readLastSafeRoute() async => null;

  @override
  Future<int?> readLastTabIndex(String area) async {
    return area == this.area ? index : null;
  }

  @override
  Future<void> saveLastSafeRoute(
    String routeName, {
    Map<String, dynamic>? params,
  }) async {}

  @override
  Future<void> saveLastTabIndex(String area, int index) async {}
}
