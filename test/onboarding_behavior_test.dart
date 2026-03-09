import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:my_app/features/onboarding/presentation/screens/coach_onboarding_screen.dart';
import 'package:my_app/features/onboarding/presentation/screens/member_onboarding_screen.dart';
import 'package:my_app/features/onboarding/presentation/screens/seller_onboarding_screen.dart';

import 'test_doubles.dart';

void main() {
  group('Onboarding flows', () {
    testWidgets('role selection does not navigate when saving role fails', (
      tester,
    ) async {
      final userRepository = FakeUserRepository()
        ..saveRoleError = Exception('Role save failed');

      await _pumpScreen(
        tester,
        const RoleSelectionScreen(),
        overrides: <Override>[
          userRepositoryProvider.overrideWithValue(userRepository),
          coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        ],
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Select').first);
      await tester.pump();

      expect(find.byType(RoleSelectionScreen), findsOneWidget);
      expect(find.text('Role save failed'), findsOneWidget);
    });

    testWidgets('role selection navigates to member onboarding on success', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        const RoleSelectionScreen(),
        overrides: <Override>[
          userRepositoryProvider.overrideWithValue(FakeUserRepository()),
          coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        ],
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Select').first);
      await tester.pumpAndSettle();

      expect(find.byType(MemberOnboardingScreen), findsOneWidget);
    });

    testWidgets('member onboarding stays on screen when completion fails', (
      tester,
    ) async {
      final userRepository = FakeUserRepository()
        ..completeOnboardingError = Exception('Onboarding failed');

      await _pumpScreen(
        tester,
        const MemberOnboardingScreen(),
        overrides: <Override>[
          userRepositoryProvider.overrideWithValue(userRepository),
          coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        ],
      );

      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('GET STARTED'));
      await tester.pump();

      expect(find.byType(MemberOnboardingScreen), findsOneWidget);
      expect(find.text('Onboarding failed'), findsOneWidget);
    });

    testWidgets('seller onboarding stays on screen when completion fails', (
      tester,
    ) async {
      final userRepository = FakeUserRepository()
        ..completeOnboardingError = Exception('Seller onboarding failed');

      await _pumpScreen(
        tester,
        const SellerOnboardingScreen(),
        overrides: <Override>[
          userRepositoryProvider.overrideWithValue(userRepository),
          coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        ],
      );

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LAUNCH STORE'));
      await tester.pump();

      expect(find.byType(SellerOnboardingScreen), findsOneWidget);
      expect(find.text('Seller onboarding failed'), findsOneWidget);
    });

    testWidgets('coach onboarding stays on screen when completion fails', (
      tester,
    ) async {
      final coachRepository = FakeCoachRepository()
        ..upsertError = Exception('Coach onboarding failed');

      await _pumpScreen(
        tester,
        const CoachOnboardingScreen(),
        overrides: <Override>[
          userRepositoryProvider.overrideWithValue(FakeUserRepository()),
          coachRepositoryProvider.overrideWithValue(coachRepository),
        ],
      );

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('START COACHING'));
      await tester.pump();

      expect(find.byType(CoachOnboardingScreen), findsOneWidget);
      expect(find.text('Coach onboarding failed'), findsOneWidget);
    });
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const <Override>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
