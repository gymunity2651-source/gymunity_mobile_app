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
      final memberRepository = FakeMemberRepository()
        ..upsertError = Exception('Onboarding failed');

      await _pumpScreen(
        tester,
        const MemberOnboardingScreen(),
        overrides: <Override>[
          userRepositoryProvider.overrideWithValue(FakeUserRepository()),
          memberRepositoryProvider.overrideWithValue(memberRepository),
          coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        ],
      );

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beginner'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('1-2 days/week'));
      await tester.tap(find.text('1-2 days/week'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('GET STARTED'));
      await tester.tap(find.text('GET STARTED'));
      await tester.pump();

      expect(find.byType(MemberOnboardingScreen), findsOneWidget);
      expect(find.text('Onboarding failed'), findsOneWidget);
    });

    testWidgets('seller onboarding stays on screen when completion fails', (
      tester,
    ) async {
      final sellerRepository = FakeSellerRepository()
        ..upsertError = Exception('Seller onboarding failed');

      await _pumpScreen(
        tester,
        const SellerOnboardingScreen(),
        overrides: <Override>[
          userRepositoryProvider.overrideWithValue(FakeUserRepository()),
          sellerRepositoryProvider.overrideWithValue(sellerRepository),
          coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        ],
      );

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'FitGear Pro');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Supplements and equipment for committed training.',
      );
      await tester.tap(find.text('Continue to Curation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
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

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Performance coach for strength-focused members.',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'Weekly programming, async support, and accountability.',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'A complete starter package with weekly check-ins.',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Coaching'));
      await tester.pump();

      expect(find.byType(CoachOnboardingScreen), findsOneWidget);
      expect(find.text('Coach onboarding failed'), findsOneWidget);
    });

    testWidgets(
      'coach onboarding submits profile and leaves screen on success',
      (tester) async {
        final coachRepository = FakeCoachRepository();

        await _pumpScreen(
          tester,
          const CoachOnboardingScreen(),
          overrides: <Override>[
            userRepositoryProvider.overrideWithValue(FakeUserRepository()),
            coachRepositoryProvider.overrideWithValue(coachRepository),
          ],
        );

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(2),
          'Performance coach for strength-focused members.',
        );
        await tester.enterText(
          find.byType(TextFormField).at(3),
          'Weekly programming, async support, and accountability.',
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'A complete starter package with weekly check-ins.',
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start Coaching'));
        await tester.pumpAndSettle();

        expect(coachRepository.upsertCoachProfileCalls, 1);
        expect(
          coachRepository.lastUpsertCoachProfilePayload?['bio'],
          'Performance coach for strength-focused members.',
        );
        expect(
          coachRepository.lastUpsertCoachProfilePayload?['serviceSummary'],
          'Weekly programming, async support, and accountability.',
        );
        expect(
          coachRepository.lastSavedPackagePayload?['title'],
          'Starter Coaching',
        );
        expect(
          coachRepository.lastSavedPackagePayload?['visibilityStatus'],
          'published',
        );
        expect(coachRepository.lastSavedPackagePayload?['isActive'], isTrue);
        expect(coachRepository.saveAvailabilitySlotCalls, 1);
        expect(find.byType(CoachOnboardingScreen), findsNothing);
        expect(
          find.text('Unable to complete onboarding right now.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'coach onboarding blocks leaving profile step when bio data is missing',
      (tester) async {
        await _pumpScreen(
          tester,
          const CoachOnboardingScreen(),
          overrides: <Override>[
            userRepositoryProvider.overrideWithValue(FakeUserRepository()),
            coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
          ],
        );

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('coach-profile-step')),
          findsOneWidget,
        );

        await tester.tap(find.text('Continue'));
        await tester.pump();

        expect(
          find.byKey(const ValueKey('coach-profile-step')),
          findsOneWidget,
        );
        expect(
          find.text('Complete your coach bio and service summary.'),
          findsOneWidget,
        );
      },
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(1440, 2560);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
