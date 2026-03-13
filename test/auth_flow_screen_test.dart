import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/supabase/auth_callback_utils.dart';
import 'package:my_app/features/auth/domain/entities/auth_session.dart';
import 'package:my_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:my_app/features/auth/presentation/screens/login_screen.dart';
import 'package:my_app/features/auth/presentation/screens/otp_screen.dart';
import 'package:my_app/features/auth/presentation/screens/register_screen.dart';
import 'package:my_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_app/features/member/presentation/screens/member_home_screen.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';

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

  group('Auth screens', () {
    testWidgets('register routes to OTP when email verification is required', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository()
        ..registerResult = const AuthSession(
          userId: 'user-1',
          email: 'user@test.com',
          isAuthenticated: false,
          requiresOtpVerification: true,
        );
      final userRepository = FakeUserRepository();

      await _pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: _overrides(
          authRepository: authRepository,
          userRepository: userRepository,
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
      await tester.enterText(find.byType(TextFormField).at(1), 'user@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'Password123');

      await tester.ensureVisible(find.text('CREATE ACCOUNT'));
      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();

      expect(find.byType(OtpScreen), findsOneWidget);
      expect(userRepository.ensureUserCalls, 1);
    });

    testWidgets('register triggers Google OAuth launch', (tester) async {
      final authRepository = FakeAuthRepository()
        ..signInWithGoogleResult = true;
      final authCallbackIngress = FakeAuthCallbackIngress();

      await _pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: _overrides(
          authRepository: authRepository,
          authCallbackIngress: authCallbackIngress,
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(authRepository.signInWithGoogleCalls, 1);
    });

    testWidgets(
      'register completes Google OAuth session through the shared coordinator',
      (tester) async {
        final controller = StreamController<AuthSession?>();
        addTearDown(controller.close);

        final authRepository = FakeAuthRepository()
          ..sessionStream = controller.stream
          ..signInWithGoogleResult = true;
        final authCallbackIngress = FakeAuthCallbackIngress();
        final userRepository = FakeUserRepository()
          ..currentUser = const UserEntity(id: 'user-1', email: 'user@test.com')
          ..profile = const ProfileEntity(
            userId: 'user-1',
            role: AppRole.member,
            onboardingCompleted: true,
          );

        await _pumpScreen(
          tester,
          const RegisterScreen(),
          overrides: _overrides(
            authRepository: authRepository,
            authCallbackIngress: authCallbackIngress,
            userRepository: userRepository,
          ),
        );

        await tester.tap(find.text('Continue with Google'));
        await tester.pump();

        controller.add(
          const AuthSession(
            userId: 'user-1',
            email: 'user@test.com',
            fullName: 'John Google',
            isAuthenticated: true,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(MemberHomeScreen), findsOneWidget);
        expect(userRepository.ensureUserCalls, 1);
      },
    );

    testWidgets(
      'register routes directly to resolved destination when OTP is not required',
      (tester) async {
        final authRepository = FakeAuthRepository()
          ..registerResult = const AuthSession(
            userId: 'user-1',
            email: 'user@test.com',
            isAuthenticated: true,
            requiresOtpVerification: false,
          );
        final userRepository = FakeUserRepository()
          ..currentUser = const UserEntity(id: 'user-1', email: 'user@test.com')
          ..profile = const ProfileEntity(
            userId: 'user-1',
            role: AppRole.member,
            onboardingCompleted: true,
          );

        await _pumpScreen(
          tester,
          const RegisterScreen(),
          overrides: _overrides(
            authRepository: authRepository,
            userRepository: userRepository,
          ),
        );

        await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'user@test.com',
        );
        await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
        await tester.enterText(find.byType(TextFormField).at(3), 'Password123');

        await tester.ensureVisible(find.text('CREATE ACCOUNT'));
        await tester.tap(find.text('CREATE ACCOUNT'));
        await tester.pumpAndSettle();

        expect(find.byType(MemberHomeScreen), findsOneWidget);
        expect(userRepository.ensureUserCalls, 1);
      },
    );

    testWidgets('forgot password sends reset link and returns to login', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        const ForgotPasswordScreen(),
        overrides: _overrides(
          authRepository: FakeAuthRepository(),
          userRepository: FakeUserRepository(),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'user@test.com');
      await tester.ensureVisible(find.text('SEND RESET LINK'));
      await tester.tap(find.text('SEND RESET LINK'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('login triggers Google OAuth launch', (tester) async {
      final authRepository = FakeAuthRepository()
        ..signInWithGoogleResult = true;
      final authCallbackIngress = FakeAuthCallbackIngress();

      await _pumpScreen(
        tester,
        const LoginScreen(),
        overrides: _overrides(
          authRepository: authRepository,
          authCallbackIngress: authCallbackIngress,
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(authRepository.signInWithGoogleCalls, 1);
    });

    testWidgets('login shows Google OAuth launch errors', (tester) async {
      final authRepository = FakeAuthRepository()
        ..signInWithGoogleError = Exception('Google OAuth is not configured.');
      final authCallbackIngress = FakeAuthCallbackIngress();

      await _pumpScreen(
        tester,
        const LoginScreen(),
        overrides: _overrides(
          authRepository: authRepository,
          authCallbackIngress: authCallbackIngress,
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(find.text('Google OAuth is not configured.'), findsOneWidget);
    });

    testWidgets('login completes Google OAuth session through route resolver', (
      tester,
    ) async {
      final controller = StreamController<AuthSession?>();
      addTearDown(controller.close);

      final authRepository = FakeAuthRepository()
        ..sessionStream = controller.stream
        ..signInWithGoogleResult = true;
      final authCallbackIngress = FakeAuthCallbackIngress();
      final userRepository = FakeUserRepository()
        ..currentUser = const UserEntity(id: 'user-1', email: 'user@test.com')
        ..profile = const ProfileEntity(
          userId: 'user-1',
          role: AppRole.member,
          onboardingCompleted: true,
        );

      await _pumpScreen(
        tester,
        const LoginScreen(),
        overrides: _overrides(
          authRepository: authRepository,
          authCallbackIngress: authCallbackIngress,
          userRepository: userRepository,
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      controller.add(
        const AuthSession(
          userId: 'user-1',
          email: 'user@test.com',
          fullName: 'John Google',
          isAuthenticated: true,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(MemberHomeScreen), findsOneWidget);
      expect(userRepository.ensureUserCalls, 1);
    });

    testWidgets('login shows timeout failure only after Google OAuth timeout', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository()
        ..signInWithGoogleResult = true;
      final authCallbackIngress = FakeAuthCallbackIngress();

      await _pumpScreen(
        tester,
        const LoginScreen(),
        overrides: _overrides(
          authRepository: authRepository,
          authCallbackIngress: authCallbackIngress,
          googleOAuthTimeout: const Duration(milliseconds: 50),
          googleOAuthPollInterval: const Duration(milliseconds: 10),
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();

      expect(
        find.text(
          'Google sign-in did not complete. Check provider configuration and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('login surfaces explicit callback errors without timeout', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository()
        ..signInWithGoogleResult = true;
      final authCallbackIngress = FakeAuthCallbackIngress();

      await _pumpScreen(
        tester,
        const LoginScreen(),
        overrides: _overrides(
          authRepository: authRepository,
          authCallbackIngress: authCallbackIngress,
          googleOAuthTimeout: const Duration(seconds: 5),
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      await authCallbackIngress.emit(
        AuthCallbackUtils.uriFromRouteName(
              '/?error=access_denied&error_description=Google%20denied',
            ) ??
            Uri(),
      );
      await tester.pump();

      expect(find.text('Google denied'), findsOneWidget);
    });
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[..._overrides(), ...overrides],
      child: MaterialApp(
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Override> _overrides({
  FakeAuthRepository? authRepository,
  FakeUserRepository? userRepository,
  FakeCoachRepository? coachRepository,
  FakeStoreRepository? storeRepository,
  FakeChatRepository? chatRepository,
  FakeAuthCallbackIngress? authCallbackIngress,
  Duration? googleOAuthTimeout,
  Duration? googleOAuthPollInterval,
}) {
  return <Override>[
    authRepositoryProvider.overrideWithValue(
      authRepository ?? FakeAuthRepository(),
    ),
    userRepositoryProvider.overrideWithValue(
      userRepository ?? FakeUserRepository(),
    ),
    authCallbackIngressProvider.overrideWithValue(
      authCallbackIngress ?? FakeAuthCallbackIngress(),
    ),
    coachRepositoryProvider.overrideWithValue(
      coachRepository ?? FakeCoachRepository(),
    ),
    storeRepositoryProvider.overrideWithValue(
      storeRepository ?? FakeStoreRepository(),
    ),
    chatRepositoryProvider.overrideWithValue(
      chatRepository ?? FakeChatRepository(),
    ),
    if (googleOAuthTimeout != null)
      googleOAuthTimeoutProvider.overrideWithValue(googleOAuthTimeout),
    if (googleOAuthPollInterval != null)
      googleOAuthPollIntervalProvider.overrideWithValue(
        googleOAuthPollInterval,
      ),
  ];
}
