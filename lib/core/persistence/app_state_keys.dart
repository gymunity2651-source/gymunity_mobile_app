const int currentLocalStateSchemaVersion = 1;

class AppStateKeys {
  const AppStateKeys._();

  static const String tabsPrefix = 'tabs';
  static const String draftsPrefix = 'drafts';
  static const String cartPrefix = 'cart';
  static const String workoutsPrefix = 'workouts';
  static const String aiPrefix = 'ai';
  static const String onboardingPrefix = 'onboarding';
  static const String offlineQueuePrefix = 'offline_queue';
  static const String userPreferencesPrefix = 'preferences.user';
  static const String devicePreferencesPrefix = 'preferences.device';

  static const List<String> userScopedPrefixes = <String>[
    tabsPrefix,
    draftsPrefix,
    cartPrefix,
    workoutsPrefix,
    aiPrefix,
    onboardingPrefix,
    offlineQueuePrefix,
    userPreferencesPrefix,
  ];
}
