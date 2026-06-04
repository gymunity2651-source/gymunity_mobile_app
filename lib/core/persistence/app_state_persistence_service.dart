import 'app_state_keys.dart';
import 'app_state_scope.dart';
import 'local_json_store.dart';
import 'offline_action_queue.dart';
import 'persisted_ai_session_store.dart';
import 'persisted_cart_store.dart';
import 'persisted_draft_store.dart';
import 'persisted_onboarding_store.dart';
import 'persisted_preferences_store.dart';
import 'persisted_tab_store.dart';
import 'persisted_workout_state_store.dart';

class AppStatePersistenceService {
  AppStatePersistenceService(LocalJsonStore store)
    : tabs = PersistedTabStore(store),
      drafts = PersistedDraftStore(store),
      cart = PersistedCartStore(store),
      workouts = PersistedWorkoutStateStore(store),
      ai = PersistedAiSessionStore(store),
      onboarding = PersistedOnboardingStore(store),
      preferences = PersistedPreferencesStore(store),
      offlineQueue = OfflineActionQueue(store),
      _store = store;

  final LocalJsonStore _store;
  final PersistedTabStore tabs;
  final PersistedDraftStore drafts;
  final PersistedCartStore cart;
  final PersistedWorkoutStateStore workouts;
  final PersistedAiSessionStore ai;
  final PersistedOnboardingStore onboarding;
  final PersistedPreferencesStore preferences;
  final OfflineActionQueue offlineQueue;

  Future<void> clearUserScopedState(String userId) async {
    for (final prefix in AppStateKeys.userScopedPrefixes) {
      await _store.clearWhere(
        (key) => AppStateScope.belongsToUser(key, prefix, userId),
      );
    }
  }

  Future<void> clearAllLocalStateForDebugOnly() async {
    await _store.clearWhere((_) => true);
  }
}
