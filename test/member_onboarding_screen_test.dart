import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/member/domain/entities/member_profile_entity.dart';
import 'package:my_app/features/onboarding/presentation/screens/member_onboarding_screen.dart';

import 'test_doubles.dart';

void main() {
  group('Member onboarding', () {
    testWidgets('starts without fake user data or a selected goal', (
      tester,
    ) async {
      await _pumpMemberOnboarding(tester);

      expect(find.text('Lose Weight is the default'), findsNothing);
      expect(find.textContaining('Choose the goal'), findsOneWidget);

      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('goal-step')), findsOneWidget);
      expect(find.text('Choose a goal to continue.'), findsOneWidget);
    });

    testWidgets('requires valid baseline data before leaving baseline step', (
      tester,
    ) async {
      await _pumpMemberOnboarding(tester);
      await _selectGoalAndContinue(tester);

      expect(
        find.byKey(const ValueKey<String>('baseline-step')),
        findsOneWidget,
      );
      expect(_textFieldValues(tester), everyElement(isEmpty));

      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('baseline-step')),
        findsOneWidget,
      );
      expect(find.text('Choose your gender to continue.'), findsOneWidget);

      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();
      await tester.enterText(_fieldByLabel(tester, 'Height'), '60');
      await tester.enterText(_fieldByLabel(tester, 'Weight'), '20');
      await tester.enterText(_fieldByLabel(tester, 'Age'), '12');
      await tester.enterText(_fieldByLabel(tester, 'City'), '   ');
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('baseline-step')),
        findsOneWidget,
      );
      expect(
        find.text('Enter a realistic height in centimeters.'),
        findsOneWidget,
      );

      await tester.enterText(_fieldByLabel(tester, 'Height'), '180');
      await tester.enterText(_fieldByLabel(tester, 'Weight'), '82');
      await tester.enterText(_fieldByLabel(tester, 'Age'), '32');
      await tester.enterText(_fieldByLabel(tester, 'City'), 'Alexandria');
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('match-step')), findsOneWidget);
      expect(_textFieldValues(tester), everyElement(isEmpty));

      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('match-step')), findsOneWidget);
      expect(
        find.text('Add a realistic monthly budget in EGP.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'submits actual user-entered values after all required choices',
      (tester) async {
        final memberRepository = FakeMemberRepository();

        await _pumpMemberOnboarding(tester, memberRepository: memberRepository);
        await _selectGoalAndContinue(tester, goalText: 'Build Muscle');
        await tester.tap(find.text('Female'));
        await tester.pumpAndSettle();
        await tester.enterText(_fieldByLabel(tester, 'Height'), '168');
        await tester.enterText(_fieldByLabel(tester, 'Weight'), '64.5');
        await tester.enterText(_fieldByLabel(tester, 'Age'), '29');
        await tester.enterText(_fieldByLabel(tester, 'City'), 'Dubai');
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        await tester.enterText(_fieldByLabel(tester, 'Monthly budget'), '2200');
        await tester.tap(find.text('Hybrid'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Gym'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Female'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Intermediate'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('3-4 days/week'));
        await tester.tap(find.text('3-4 days/week'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('GET STARTED'));
        await tester.tap(find.text('GET STARTED'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final MemberProfileEntity? profile = memberRepository.profile;
        expect(profile, isNotNull);
        expect(profile!.goal, 'build_muscle');
        expect(profile.age, 29);
        expect(profile.gender, 'female');
        expect(profile.heightCm, 168);
        expect(profile.currentWeightKg, 64.5);
        expect(profile.trainingFrequency, '3_4_days_per_week');
        expect(profile.experienceLevel, 'intermediate');
        expect(profile.budgetEgp, 2200);
        expect(profile.city, 'Dubai');
        expect(profile.coachingPreference, 'hybrid');
        expect(profile.trainingPlace, 'gym');
        expect(profile.preferredLanguage, 'english');
        expect(profile.preferredCoachGender, 'female');
        expect(find.byType(MemberOnboardingScreen), findsNothing);
      },
    );
  });
}

Future<void> _pumpMemberOnboarding(
  WidgetTester tester, {
  FakeMemberRepository? memberRepository,
}) async {
  tester.view.physicalSize = const Size(1440, 2560);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
        memberRepositoryProvider.overrideWithValue(
          memberRepository ?? FakeMemberRepository(),
        ),
        coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
      ],
      child: MaterialApp(
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: const MemberOnboardingScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectGoalAndContinue(
  WidgetTester tester, {
  String goalText = 'Lose Weight',
}) async {
  await tester.tap(find.text(goalText));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CONTINUE'));
  await tester.pumpAndSettle();
}

Finder _fieldByLabel(WidgetTester tester, String label) {
  final fields = tester.widgetList<TextField>(find.byType(TextField));
  var index = 0;
  for (final field in fields) {
    if (field.decoration?.labelText == label) {
      return find.byType(TextField).at(index);
    }
    index++;
  }
  fail('Could not find TextField with label $label');
}

List<String> _textFieldValues(WidgetTester tester) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .map((field) => field.controller?.text ?? '')
      .toList(growable: false);
}
