import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/routing/app_navigation_state_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesAppNavigationStateStore', () {
    late SharedPreferences preferences;
    var currentUserId = 'user-1';

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferences = await SharedPreferences.getInstance();
      currentUserId = 'user-1';
    });

    SharedPreferencesAppNavigationStateStore buildStore({DateTime? now}) {
      return SharedPreferencesAppNavigationStateStore(
        preferences,
        currentUserIdReader: () async => currentUserId,
        clock: () => now ?? DateTime.utc(2026, 6, 4, 12),
      );
    }

    test('saves last safe route scoped to current user', () async {
      final store = buildStore();

      await store.saveLastSafeRoute(
        AppRoutes.aiConversation,
        params: const <String, dynamic>{'sessionId': 'session-1'},
      );

      final saved = await store.readLastSafeRoute();
      expect(saved, isNotNull);
      expect(saved!.userId, 'user-1');
      expect(saved.routeName, AppRoutes.aiConversation);
      expect(saved.params, containsPair('sessionId', 'session-1'));
    });

    test('clears user scoped state including tabs', () async {
      final store = buildStore();

      await store.saveLastSafeRoute(AppRoutes.memberHome);
      await store.saveLastDashboardRoute(AppRoutes.memberHome);
      await store.saveLastTabIndex('member_home', 2);
      expect(await store.readLastTabIndex('member_home'), 2);

      await store.clearUserScopedState();

      expect(await store.readLastSafeRoute(), isNull);
      expect(await store.readLastDashboardRoute(), isNull);
      expect(await store.readLastTabIndex('member_home'), isNull);
    });

    test('keeps tab indexes scoped by user', () async {
      final store = buildStore();

      await store.saveLastTabIndex('member_home', 3);
      currentUserId = 'user-2';

      expect(await store.readLastTabIndex('member_home'), isNull);
    });
  });
}
