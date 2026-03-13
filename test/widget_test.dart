import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/features/auth/presentation/controllers/app_bootstrap_controller.dart';
import 'package:my_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_app/features/auth/presentation/screens/splash_screen.dart';

import 'test_doubles.dart';

void main() {
  setUpAll(() {
    AppConfig.debugOverrideForTests(
      AppConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'test-anon-key',
        authRedirectScheme: 'gymunity-dev',
        authRedirectHost: 'auth-callback',
        privacyPolicyUrl: '',
        termsUrl: '',
        supportUrl: '',
        supportEmail: '',
        supportEmailSubject: 'GymUnity support request',
        reviewerLoginHelpUrl: '',
        openAiModel: 'gpt-4o-mini',
        enableCoachRole: true,
        enableSellerRole: true,
        enableAppleSignIn: true,
        enableStorePurchases: true,
        enableCoachSubscriptions: true,
      ),
    );
  });

  tearDownAll(AppConfig.clearDebugOverride);

  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          userRepositoryProvider.overrideWithValue(FakeUserRepository()),
          authCallbackIngressProvider.overrideWithValue(
            FakeAuthCallbackIngress(),
          ),
          appBootstrapControllerProvider.overrideWith(
            (ref) => _FakeAppBootstrapController(ref),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const SplashScreen(),
        ),
      ),
    );

    expect(find.text('GymUnity'), findsOneWidget);
  });

  testWidgets(
    'Splash navigates when bootstrap already resolved the destination',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
            userRepositoryProvider.overrideWithValue(FakeUserRepository()),
            authCallbackIngressProvider.overrideWithValue(
              FakeAuthCallbackIngress(),
            ),
            appBootstrapControllerProvider.overrideWith(
              (ref) => _ResolvedBootstrapController(ref),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            routes: <String, WidgetBuilder>{
              AppRoutes.welcome: (_) =>
                  const Scaffold(body: Text('Welcome route')),
            },
            home: const SplashScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Welcome route'), findsOneWidget);
    },
  );
}

class _FakeAppBootstrapController extends AppBootstrapController {
  _FakeAppBootstrapController(super.ref);

  @override
  Future<void> load() async {
    state = const AppBootstrapState(status: AppBootstrapStatus.loading);
  }
}

class _ResolvedBootstrapController extends AppBootstrapController {
  _ResolvedBootstrapController(super.ref);

  @override
  Future<void> load() async {
    state = const AppBootstrapState(
      status: AppBootstrapStatus.unauthenticated,
      routeName: AppRoutes.welcome,
    );
  }
}
