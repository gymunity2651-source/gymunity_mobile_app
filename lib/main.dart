import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/config/local_runtime_config_loader.dart';
import 'core/supabase/supabase_initializer.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalRuntimeConfigLoader.primeIfNeeded();
  if (AppConfig.current.validationErrorMessage == null) {
    await SupabaseInitializer.initialize();
  }
  runApp(const ProviderScope(child: GymUnityApp()));
}
