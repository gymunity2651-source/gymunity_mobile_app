import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/constants/app_strings.dart';
import '../core/config/app_config.dart';
import '../features/monetization/presentation/providers/monetization_providers.dart';
import 'routes.dart';

class GymUnityApp extends ConsumerStatefulWidget {
  const GymUnityApp({super.key});

  @override
  ConsumerState<GymUnityApp> createState() => _GymUnityAppState();
}

class _GymUnityAppState extends ConsumerState<GymUnityApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(monetizationBootstrapProvider).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(monetizationBootstrapProvider).dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(monetizationBootstrapProvider).refreshEntitlements();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValidConfig = AppConfig.current.validationErrorMessage == null;
    if (hasValidConfig) {
      ref.watch(authAwareMonetizationProvider);
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
      ),
    );

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
