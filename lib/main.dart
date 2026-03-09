import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/supabase/auth_deep_link_bootstrap.dart';
import 'core/supabase/supabase_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseInitializer.initialize();
    await AuthDeepLinkBootstrap.instance.start();
  } catch (error) {
    debugPrint('Supabase initialization skipped: $error');
  }
  runApp(const GymUnityApp());
}
