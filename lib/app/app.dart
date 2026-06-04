import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/constants/app_strings.dart';
import '../core/config/app_config.dart';
import '../core/di/providers.dart';
import '../core/lifecycle/lifecycle_providers.dart';
import '../features/ai_coach/presentation/providers/ai_coach_providers.dart';
import '../features/monetization/presentation/providers/monetization_providers.dart';
import '../features/planner/presentation/providers/planner_providers.dart';
import '../features/settings/presentation/providers/settings_providers.dart';
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
      unawaited(ref.read(appStatePersistenceServiceProvider.future));
      ref.read(monetizationBootstrapProvider).start();
      ref.read(plannerReminderBootstrapProvider).start();
      ref.read(aiCoachBootProvider).start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(ref.read(appLifecycleCoordinatorProvider).onDetached());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      ref.read(appLifecycleCoordinatorProvider).handleStateChange(state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValidConfig = AppConfig.current.validationErrorMessage == null;
    final preferences = ref.watch(resolvedSettingsPreferencesProvider);
    if (hasValidConfig) {
      ref.watch(authAwareMonetizationProvider);
      ref.watch(authAwarePlannerRemindersProvider);
      ref.watch(authAwareAiCoachProvider);
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
      restorationScopeId: 'gymunity_app',
      theme: AppTheme.darkTheme,
      locale: Locale(preferences.language == AppLanguage.arabic ? 'ar' : 'en'),
      navigatorKey: ref.watch(appLifecycleNavigatorKeyProvider),
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      navigatorObservers: [ref.watch(appRouteObserverProvider)],
    );
  }
}
