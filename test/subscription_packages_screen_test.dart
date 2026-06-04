import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/coach/domain/entities/coach_entity.dart';
import 'package:my_app/features/coaches/presentation/screens/subscription_packages_screen.dart';
import 'package:my_app/features/member/presentation/providers/member_providers.dart';

import 'test_doubles.dart';

void main() {
  setUp(() {
    AppConfig.debugOverrideForTests(
      AppConfig.fromMap(const <String, String>{
        'APP_ENV': 'dev',
        'SUPABASE_URL': 'https://example.supabase.co',
        'SUPABASE_ANON_KEY': 'anon',
        'ENABLE_COACH_SUBSCRIPTIONS': 'true',
        'ENABLE_COACH_PAYMOB_PAYMENTS': 'false',
      }),
    );
  });

  tearDown(AppConfig.clearDebugOverride);

  testWidgets('manual checkout refreshes member subscriptions cache', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final package = _package();
    final coach = _coach(packages: <CoachPackageEntity>[package]);
    final coachRepo = FakeCoachRepository()
      ..coaches = <CoachEntity>[coach]
      ..packages = <CoachPackageEntity>[package];
    final memberRepo = FakeMemberRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          coachRepositoryProvider.overrideWithValue(coachRepo),
          memberRepositoryProvider.overrideWithValue(memberRepo),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(memberSubscriptionsProvider);
              return SubscriptionPackagesScreen(coach: coach);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(memberRepo.listSubscriptionsCalls, 1);

    final checkoutButton = find.text('Start paid checkout').first;
    await tester.ensureVisible(checkoutButton);
    await tester.tap(checkoutButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Primary goal'),
      'Build strength',
    );
    await tester.tap(find.text('Submit request'));
    await tester.pumpAndSettle();

    expect(coachRepo.lastRequestedSubscription?.packageId, 'package-1');
    expect(memberRepo.listSubscriptionsCalls, greaterThan(1));
    expect(
      find.text(
        'Checkout started. Confirm payment from My Coaching to activate the coach thread.',
      ),
      findsOneWidget,
    );
  });
}

CoachEntity _coach({List<CoachPackageEntity> packages = const []}) {
  return CoachEntity(
    id: 'coach-1',
    name: 'Mona Coach',
    pricingCurrency: 'EGP',
    packages: packages,
  );
}

CoachPackageEntity _package() {
  return const CoachPackageEntity(
    id: 'package-1',
    coachId: 'coach-1',
    title: 'Starter Coaching',
    description: 'Starter offer',
    billingCycle: 'monthly',
    price: 1200,
    outcomeSummary: 'A focused starter plan.',
  );
}
