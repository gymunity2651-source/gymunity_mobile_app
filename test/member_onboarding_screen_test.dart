import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/member/domain/entities/member_profile_entity.dart';
import 'package:my_app/features/onboarding/presentation/screens/member_onboarding_screen.dart';

import 'test_doubles.dart';

void main() {
  group('MemberOnboardingScreen', () {
    testWidgets(
      'initial field render has no prefilled fake values for baseline or budget',
      (tester) async {
        await _pumpMemberOnboarding(tester);
        await _goToBaselineStep(tester);

        expect(_fieldText(tester, 'Height'), isEmpty);
        expect(_fieldText(tester, 'Weight'), isEmpty);
        expect(_fieldText(tester, 'Age'), isEmpty);
        expect(_fieldText(tester, 'City'), isEmpty);
        expect(_fieldHint(tester, 'Height'), 'e.g. 170');
        expect(_fieldHint(tester, 'Weight'), 'e.g. 82');
        expect(_fieldHint(tester, 'Age'), 'e.g. 26');
        expect(_fieldHint(tester, 'City'), 'e.g. Cairo');

        await _fillValidBaseline(tester);
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('match-step')),
          findsOneWidget,
        );
        expect(_fieldText(tester, 'Monthly budget'), isEmpty);
        expect(_fieldHint(tester, 'Monthly budget'), 'e.g. 1500');
      },
    );

    testWidgets('no goal is selected initially', (tester) async {
      await _pumpMemberOnboarding(tester);

      await tester.tap(find.text('CONTINUE'));
      await tester.pump();

      expect(find.byKey(const ValueKey<String>('goal-step')), findsOneWidget);
      expect(find.text('Choose a goal to continue.'), findsOneWidget);
    });

    testWidgets('goal setup fits compact phone layout without overflow', (
      tester,
    ) async {
      await _pumpMemberOnboarding(tester, physicalSize: const Size(360, 800));

      expect(find.text('What result do you want first?'), findsOneWidget);
      expect(find.text('Lose Weight'), findsOneWidget);
      expect(find.text('General Fitness'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'pressing continue on step 0 without goal does not advance and shows feedback',
      (tester) async {
        await _pumpMemberOnboarding(tester);

        await tester.tap(find.text('CONTINUE'));
        await tester.pump();

        expect(find.byKey(const ValueKey<String>('goal-step')), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('baseline-step')),
          findsNothing,
        );
        expect(find.text('Choose a goal to continue.'), findsOneWidget);
      },
    );

    testWidgets('selecting a goal then continue advances to baseline step', (
      tester,
    ) async {
      await _pumpMemberOnboarding(tester);

      await _selectGoal(tester, 'Lose Weight');
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('goal-step')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('baseline-step')),
        findsOneWidget,
      );
    });

    testWidgets(
      'pressing continue on baseline step with empty fields does not advance',
      (tester) async {
        await _pumpMemberOnboarding(tester);
        await _goToBaselineStep(tester);

        await tester.tap(find.text('CONTINUE'));
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('baseline-step')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey<String>('match-step')), findsNothing);
        expect(find.text('Choose your gender to continue.'), findsOneWidget);
      },
    );

    testWidgets('invalid height, weight, and age show validation feedback', (
      tester,
    ) async {
      await _pumpMemberOnboarding(tester);
      await _goToBaselineStep(tester);

      await _fillBaseline(
        tester,
        gender: 'Male',
        height: '60',
        weight: '82',
        age: '32',
        city: 'Alexandria',
      );
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a realistic height in centimeters.'),
        findsOneWidget,
      );

      await _fillBaseline(
        tester,
        height: '180',
        weight: '20',
        age: '32',
        city: 'Alexandria',
      );
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a realistic weight in kilograms.'),
        findsOneWidget,
      );

      await _fillBaseline(
        tester,
        height: '180',
        weight: '82',
        age: '12',
        city: 'Alexandria',
      );
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a valid age between 13 and 100.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('baseline-step')),
        findsOneWidget,
      );
    });

    testWidgets('valid baseline values advance to coach match step', (
      tester,
    ) async {
      await _pumpMemberOnboarding(tester);
      await _goToBaselineStep(tester);

      await _fillValidBaseline(tester);
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('baseline-step')), findsNothing);
      expect(find.byKey(const ValueKey<String>('match-step')), findsOneWidget);
    });

    testWidgets(
      'step 2 requires budget, mode, place, language, and coach gender',
      (tester) async {
        await _pumpMemberOnboarding(tester);
        await _goToMatchStep(tester);

        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        expect(
          find.text('Add a realistic monthly budget in EGP.'),
          findsOneWidget,
        );

        await tester.enterText(_fieldByLabel(tester, 'Monthly budget'), '2200');
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        expect(
          find.text('Choose the coaching mode that fits you best.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Hybrid'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        expect(find.text('Choose where you plan to train.'), findsOneWidget);

        await tester.tap(find.text('Gym'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        expect(
          find.text('Choose your preferred coaching language.'),
          findsOneWidget,
        );

        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
        expect(
          find.text('Choose your preferred coach gender.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Female'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('training-step')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'final submit calls completeMemberOnboarding with exact entered values',
      (tester) async {
        final memberRepository = FakeMemberRepository();

        await _pumpMemberOnboarding(tester, memberRepository: memberRepository);
        await _goToBaselineStep(tester, goalText: 'Build Muscle');
        await _fillBaseline(
          tester,
          gender: 'Female',
          height: '168',
          weight: '64.5',
          age: '29',
          city: 'Dubai',
        );
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        await _fillMatchStep(
          tester,
          budget: '2200',
          mode: 'Hybrid',
          place: 'Gym',
          language: 'English',
          coachGender: 'Female',
        );
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
  Size physicalSize = const Size(1440, 2560),
}) async {
  tester.view.physicalSize = physicalSize;
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

Future<void> _goToBaselineStep(
  WidgetTester tester, {
  String goalText = 'Lose Weight',
}) async {
  await _selectGoal(tester, goalText);
  await tester.tap(find.text('CONTINUE'));
  await tester.pumpAndSettle();
}

Future<void> _goToMatchStep(WidgetTester tester) async {
  await _goToBaselineStep(tester);
  await _fillValidBaseline(tester);
  await tester.tap(find.text('CONTINUE'));
  await tester.pumpAndSettle();
}

Future<void> _selectGoal(WidgetTester tester, String goalText) async {
  await tester.tap(find.text(goalText));
  await tester.pumpAndSettle();
}

Future<void> _fillValidBaseline(WidgetTester tester) async {
  await _fillBaseline(
    tester,
    gender: 'Male',
    height: '180',
    weight: '82',
    age: '32',
    city: 'Alexandria',
  );
}

Future<void> _fillBaseline(
  WidgetTester tester, {
  String? gender,
  required String height,
  required String weight,
  required String age,
  required String city,
}) async {
  if (gender != null) {
    await tester.tap(find.text(gender));
    await tester.pumpAndSettle();
  }
  await tester.enterText(_fieldByLabel(tester, 'Height'), height);
  await tester.enterText(_fieldByLabel(tester, 'Weight'), weight);
  await tester.enterText(_fieldByLabel(tester, 'Age'), age);
  await tester.enterText(_fieldByLabel(tester, 'City'), city);
}

Future<void> _fillMatchStep(
  WidgetTester tester, {
  required String budget,
  required String mode,
  required String place,
  required String language,
  required String coachGender,
}) async {
  await tester.enterText(_fieldByLabel(tester, 'Monthly budget'), budget);
  await tester.tap(find.text(mode));
  await tester.pumpAndSettle();
  await tester.tap(find.text(place));
  await tester.pumpAndSettle();
  await tester.tap(find.text(language));
  await tester.pumpAndSettle();
  await tester.tap(find.text(coachGender));
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

TextField _fieldWidget(WidgetTester tester, String label) {
  return tester.widget<TextField>(_fieldByLabel(tester, label));
}

String _fieldText(WidgetTester tester, String label) {
  return _fieldWidget(tester, label).controller?.text ?? '';
}

String? _fieldHint(WidgetTester tester, String label) {
  return _fieldWidget(tester, label).decoration?.hintText;
}
