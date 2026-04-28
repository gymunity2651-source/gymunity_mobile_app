import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/auth/presentation/screens/welcome_screen.dart';

import 'package:my_app/core/di/providers.dart';

import 'test_doubles.dart';

void main() {
  group('WelcomeScreen', () {
    testWidgets('renders the first onboarding slide with NEXT', (
      WidgetTester tester,
    ) async {
      await _pumpWelcomeScreen(tester);

      expect(find.text('WELCOME'), findsOneWidget);
      expect(find.text('Unified.'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
    });

    testWidgets('NEXT advances through the onboarding slides in order', (
      WidgetTester tester,
    ) async {
      await _pumpWelcomeScreen(tester);

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Together.'), findsOneWidget);

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('AI-Powered'), findsOneWidget);
    });

    testWidgets('Skip jumps directly to the final Google CTA page', (
      WidgetTester tester,
    ) async {
      await _pumpWelcomeScreen(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('NEXT'), findsNothing);
    });

    testWidgets('final slide shows the Google CTA without NEXT', (
      WidgetTester tester,
    ) async {
      await _pumpWelcomeScreen(tester);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Empire.'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('NEXT'), findsNothing);
    });
  });
}

Future<void> _pumpWelcomeScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        authCallbackIngressProvider.overrideWithValue(
          FakeAuthCallbackIngress(),
        ),
      ],
      child: const MaterialApp(home: WelcomeScreen()),
    ),
  );

  await tester.pumpAndSettle();
}
