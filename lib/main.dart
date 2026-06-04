import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_config.dart';
import 'core/config/local_runtime_config_loader.dart';
import 'core/di/providers.dart';
import 'core/supabase/supabase_initializer.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalRuntimeConfigLoader.primeIfNeeded();
  if (AppConfig.current.validationErrorMessage == null) {
    await SupabaseInitializer.initialize();
  }
  final sharedPreferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const GymUnityApp(),
    ),
  );
}
