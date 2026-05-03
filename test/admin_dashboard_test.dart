import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/admin/domain/entities/admin_entities.dart';
import 'package:my_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:my_app/features/auth/domain/entities/auth_session.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('/admin-dashboard renders access denied for non-admin', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..sessionStream = Stream<AuthSession?>.value(
        const AuthSession(
          userId: 'user-1',
          email: 'user@example.com',
          isAuthenticated: true,
        ),
      );
    final admin = FakeAdminRepository()..currentAdmin = null;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          adminRepositoryProvider.overrideWithValue(admin),
        ],
        child: const MaterialApp(home: AdminAccessGate()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsOneWidget);
  });

  testWidgets('admin dashboard renders KPI cards and TEST MODE badge', (
    tester,
  ) async {
    final adminRepo = FakeAdminRepository()
      ..currentAdmin = const AdminUserEntity(
        userId: 'admin-1',
        role: 'finance_admin',
        isActive: true,
      );

    await _pumpAdmin(tester, adminRepo);

    expect(find.text('TEST MODE'), findsOneWidget);
    expect(find.text('Total paid'), findsOneWidget);
    expect(find.text('Payments today'), findsOneWidget);
    expect(find.text('Coach net payable'), findsOneWidget);
  });

  testWidgets('admin dashboard renders TAIYO Ops Brief card', (tester) async {
    final adminRepo = FakeAdminRepository()
      ..currentAdmin = const AdminUserEntity(
        userId: 'admin-1',
        role: 'finance_admin',
        isActive: true,
      )
      ..taiyoBrief = const AdminTaiyoBriefEntity(
        requestType: 'admin_ops_brief',
        status: 'success',
        issueType: 'dashboard',
        statusSummary: 'Payments and payouts are stable.',
        riskLevel: 'low',
        reason: 'No urgent admin action is needed.',
      );

    await _pumpAdmin(tester, adminRepo);

    expect(find.text('TAIYO Ops Brief'), findsOneWidget);
    expect(find.text('Payments and payouts are stable.'), findsOneWidget);
    expect(adminRepo.requestTaiyoAdminOpsBriefCalls, 1);
  });

  testWidgets('payment list filters by status', (tester) async {
    final adminRepo = FakeAdminRepository()
      ..currentAdmin = const AdminUserEntity(
        userId: 'admin-1',
        role: 'finance_admin',
        isActive: true,
      );

    await _pumpAdmin(tester, adminRepo);
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();

    expect(find.text('Starter Coaching'), findsOneWidget);
    expect(find.text('Cut Plan'), findsOneWidget);

    await tester.tap(find.text('All statuses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('failed').last);
    await tester.pumpAndSettle();

    expect(find.text('Cut Plan'), findsOneWidget);
    expect(find.text('Starter Coaching'), findsNothing);
  });

  testWidgets('payout mark paid form validates required confirmation', (
    tester,
  ) async {
    final adminRepo = FakeAdminRepository()
      ..currentAdmin = const AdminUserEntity(
        userId: 'admin-1',
        role: 'finance_admin',
        isActive: true,
      );

    await _pumpAdmin(tester, adminRepo);
    await tester.tap(find.text('Payouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark paid').first);
    await tester.pumpAndSettle();

    expect(find.text('Mark payout paid'), findsOneWidget);
    await tester.tap(find.text('Mark paid').last);
    await tester.pumpAndSettle();
    expect(adminRepo.calls.where((call) => call['action'] == 'paid'), isEmpty);

    await tester.enterText(
      find.widgetWithText(TextField, 'External reference'),
      'BANK-TEST-1',
    );
    await tester.tap(find.text('Coach was paid outside GymUnity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark paid').last);
    await tester.pumpAndSettle();

    expect(
      adminRepo.calls.any(
        (call) =>
            call['action'] == 'paid' &&
            call['externalReference'] == 'BANK-TEST-1',
      ),
      isTrue,
    );
  });

  testWidgets('support admin does not see enabled mark paid action', (
    tester,
  ) async {
    final adminRepo = FakeAdminRepository()
      ..currentAdmin = const AdminUserEntity(
        userId: 'admin-1',
        role: 'support_admin',
        isActive: true,
      );

    await _pumpAdmin(tester, adminRepo);
    await tester.tap(find.text('Payouts'));
    await tester.pumpAndSettle();

    expect(find.text('Mark paid'), findsNothing);
    expect(find.text('Details'), findsWidgets);
  });

  testWidgets('super admin can view raw Paymob payload section', (
    tester,
  ) async {
    final adminRepo = FakeAdminRepository()
      ..currentAdmin = const AdminUserEntity(
        userId: 'admin-1',
        role: 'super_admin',
        isActive: true,
      )
      ..paymentOrders = const [
        AdminPaymentOrderEntity(
          id: 'payment-raw',
          memberName: 'Mona Member',
          coachName: 'Omar Coach',
          packageTitle: 'Starter Coaching',
          amountGrossCents: 120000,
          status: 'paid',
          rawCreateIntentionResponse: {'id': 'intent-test'},
        ),
      ];

    await _pumpAdmin(tester, adminRepo);
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starter Coaching'));
    await tester.pumpAndSettle();

    expect(find.text('Raw Paymob payload'), findsOneWidget);
  });

  testWidgets('payment details render AI risk explanation without mutation', (
    tester,
  ) async {
    final adminRepo = FakeAdminRepository()
      ..currentAdmin = const AdminUserEntity(
        userId: 'admin-1',
        role: 'finance_admin',
        isActive: true,
      )
      ..taiyoBrief = const AdminTaiyoBriefEntity(
        requestType: 'payment_order_risk',
        status: 'success',
        statusSummary: 'Paid order needs subscription reconciliation.',
        riskLevel: 'high',
        recommendedAdminAction: 'admin_reconcile_payment_order',
        actionLabel: 'Reconcile payment order',
        reason: 'Admin must confirm before running the existing action.',
      );

    await _pumpAdmin(tester, adminRepo);
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starter Coaching'));
    await tester.pumpAndSettle();

    expect(find.text('AI Risk Explanation'), findsOneWidget);
    expect(
      find.text('Paid order needs subscription reconciliation.'),
      findsOneWidget,
    );
    expect(find.text('Manual confirmation required'), findsOneWidget);
    expect(adminRepo.lastTaiyoAdminRequestType, 'payment_order_risk');
    expect(adminRepo.lastTaiyoAdminPaymentOrderId, 'payment-1');
    expect(adminRepo.calls, isEmpty);
  });

  testWidgets('payout details render AI payout review without mutation', (
    tester,
  ) async {
    final adminRepo = FakeAdminRepository()
      ..currentAdmin = const AdminUserEntity(
        userId: 'admin-1',
        role: 'finance_admin',
        isActive: true,
      )
      ..taiyoBrief = const AdminTaiyoBriefEntity(
        requestType: 'payout_review',
        status: 'success',
        statusSummary: 'Payout is ready for manual review.',
        riskLevel: 'medium',
        recommendedAdminAction: 'admin_mark_payout_ready',
        actionLabel: 'Mark payout ready',
      );

    await _pumpAdmin(tester, adminRepo);
    await tester.tap(find.text('Payouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details').first);
    await tester.pumpAndSettle();

    expect(find.text('AI Payout Review'), findsOneWidget);
    expect(find.text('Payout is ready for manual review.'), findsOneWidget);
    expect(adminRepo.lastTaiyoAdminRequestType, 'payout_review');
    expect(adminRepo.lastTaiyoAdminPayoutId, 'payout-1');
    expect(adminRepo.calls, isEmpty);
  });
}

Future<void> _pumpAdmin(
  WidgetTester tester,
  FakeAdminRepository adminRepo,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final auth = FakeAuthRepository()
    ..sessionStream = Stream<AuthSession?>.value(
      const AuthSession(
        userId: 'admin-1',
        email: 'admin@example.com',
        isAuthenticated: true,
      ),
    );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        adminRepositoryProvider.overrideWithValue(adminRepo),
      ],
      child: const MaterialApp(home: AdminAccessGate()),
    ),
  );
  await tester.pumpAndSettle();
}
