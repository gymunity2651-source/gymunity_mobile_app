import 'package:shared_preferences/shared_preferences.dart';

abstract class LaunchStateStore {
  Future<bool> hasCompletedFirstLaunch();

  Future<void> markFirstLaunchComplete();
}

class SharedPreferencesLaunchStateStore implements LaunchStateStore {
  SharedPreferencesLaunchStateStore(this._preferences);

  static const String _hasCompletedFirstLaunchKey =
      'gymunity.has_completed_first_launch';

  final SharedPreferences _preferences;

  @override
  Future<bool> hasCompletedFirstLaunch() async {
    return _preferences.getBool(_hasCompletedFirstLaunchKey) ?? false;
  }

  @override
  Future<void> markFirstLaunchComplete() async {
    await _preferences.setBool(_hasCompletedFirstLaunchKey, true);
  }
}
