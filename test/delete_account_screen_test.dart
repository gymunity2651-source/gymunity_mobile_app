import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/auth/domain/entities/auth_provider_type.dart';
import 'package:my_app/features/settings/presentation/screens/delete_account_screen.dart';

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
        enableCoachRole: true,
        enableSellerRole: true,
        enableAppleSignIn: true,
        enableStorePurchases: true,
        enableCoachSubscriptions: true,
      ),
    );
  });

  tearDownAll(AppConfig.clearDebugOverride);

  testWidgets(
    'delete account screen explains permanent deletion and email reuse',
    (tester) async {
      final authRepository = FakeAuthRepository()
        ..currentProvider = AuthProviderType.emailPassword;

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authRepositoryProvider.overrideWithValue(authRepository),
          ],
          child: const MaterialApp(home: DeleteAccountScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Account'), findsOneWidget);
      expect(
        find.textContaining('permanently delete this account'),
        findsOneWidget,
      );
      expect(
        find.textContaining('same email address as a brand new account'),
        findsOneWidget,
      );
      expect(find.text('Current Password'), findsOneWidget);
    },
  );
}
