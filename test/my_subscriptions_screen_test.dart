import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/coach/domain/entities/coach_payment_entity.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/member/presentation/screens/my_subscriptions_screen.dart';

import 'test_doubles.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeMemberRepository repo, {
    FakeCoachPaymentRepository? paymentRepo,
  }) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          memberRepositoryProvider.overrideWithValue(repo),
          coachPaymentRepositoryProvider.overrideWithValue(
            paymentRepo ?? FakeCoachPaymentRepository(),
          ),
        ],
        child: const MaterialApp(home: MySubscriptionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'pause opens confirmation and does not call repository immediately',
    (tester) async {
      final repo = FakeMemberRepository()
        ..subscriptions = <SubscriptionEntity>[_subscription()];

      await pumpScreen(tester, repo);
      await tester.tap(
        find.byKey(const Key('member-subscription-pause-resume-action-sub-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pause subscription?'), findsOneWidget);
      expect(repo.pauseSubscriptionCalls, 0);
    },
  );

  testWidgets('Keep Active closes pause dialog without pausing', (
    tester,
  ) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_subscription()];

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-subscription-pause-resume-action-sub-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep Active'));
    await tester.pumpAndSettle();

    expect(find.text('Pause subscription?'), findsNothing);
    expect(repo.pauseSubscriptionCalls, 0);
  });

  testWidgets('confirm pause calls repository once', (tester) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_subscription()];

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-subscription-pause-resume-action-sub-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('member-confirm-pause-resume-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.pauseSubscriptionCalls, 1);
    expect(repo.lastPausedSubscriptionId, 'sub-1');
    expect(repo.lastPauseNow, isTrue);
    expect(find.text('Subscription paused.'), findsOneWidget);
  });

  testWidgets('resume sends pauseNow false', (tester) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_subscription(status: 'paused')];

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-subscription-pause-resume-action-sub-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('member-confirm-pause-resume-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.pauseSubscriptionCalls, 1);
    expect(repo.lastPauseNow, isFalse);
    expect(find.text('Subscription resumed.'), findsOneWidget);
  });

  testWidgets('pause loading prevents duplicate requests', (tester) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_subscription()]
      ..pauseSubscriptionCompleter = Completer<void>();

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-subscription-pause-resume-action-sub-1')),
    );
    await tester.pumpAndSettle();

    final confirm = find.byKey(const Key('member-confirm-pause-resume-button'));
    await tester.tap(confirm);
    await tester.pump();
    await tester.tap(confirm, warnIfMissed: false);
    await tester.pump();

    expect(find.text('Pausing...'), findsOneWidget);
    expect(repo.pauseSubscriptionCalls, 1);

    repo.pauseSubscriptionCompleter!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Subscription paused.'), findsOneWidget);
  });

  testWidgets('pause failure keeps dialog open and restores action', (
    tester,
  ) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_subscription()]
      ..pauseSubscriptionError = StateError('network down');

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-subscription-pause-resume-action-sub-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('member-confirm-pause-resume-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pause subscription?'), findsOneWidget);
    expect(find.text('Pause Subscription'), findsOneWidget);
    expect(
      find.text('Subscription could not be paused. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('network down'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('resume failure keeps dialog open with sanitized error', (
    tester,
  ) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_subscription(status: 'paused')]
      ..pauseSubscriptionError = StateError('network down');

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-subscription-pause-resume-action-sub-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('member-confirm-pause-resume-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resume subscription?'), findsOneWidget);
    expect(find.text('Resume Subscription'), findsOneWidget);
    expect(
      find.text('Subscription could not be resumed. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('network down'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('empty payment proof is rejected', (tester) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_pendingSubscription()];

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-submit-payment-proof-action-sub-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('member-payment-proof-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Add a payment reference or upload a receipt before submitting.',
      ),
      findsOneWidget,
    );
    expect(repo.uploadCoachPaymentReceiptCalls, 0);
    expect(repo.submitCoachPaymentReceiptCalls, 0);
  });

  testWidgets('reference-only payment proof submits successfully', (
    tester,
  ) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_pendingSubscription()];

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-submit-payment-proof-action-sub-1')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('member-payment-proof-reference-field')),
      'BANK-REF-42',
    );
    await tester.tap(
      find.byKey(const Key('member-payment-proof-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.uploadCoachPaymentReceiptCalls, 0);
    expect(repo.submitCoachPaymentReceiptCalls, 1);
    expect(
      repo.lastSubmittedCoachPaymentReceiptPayload?['paymentReference'],
      'BANK-REF-42',
    );
    expect(
      repo.lastSubmittedCoachPaymentReceiptPayload?['receiptStoragePath'],
      isNull,
    );
    expect(
      find.text('Payment proof submitted for coach verification.'),
      findsOneWidget,
    );
  });

  testWidgets('payment proof submit failure keeps sheet open and reference', (
    tester,
  ) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_pendingSubscription()]
      ..submitCoachPaymentReceiptError = StateError('network down');

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-submit-payment-proof-action-sub-1')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('member-payment-proof-reference-field')),
      'BANK-REF-42',
    );
    await tester.tap(
      find.byKey(const Key('member-payment-proof-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment proof'), findsOneWidget);
    expect(find.text('BANK-REF-42'), findsOneWidget);
    expect(
      find.text('Payment proof could not be submitted. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('network down'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('payment proof loading prevents duplicate submit', (
    tester,
  ) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_pendingSubscription()]
      ..submitCoachPaymentReceiptCompleter = Completer<void>();

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-submit-payment-proof-action-sub-1')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('member-payment-proof-reference-field')),
      'BANK-REF-42',
    );
    final submit = find.byKey(const Key('member-payment-proof-submit-button'));
    await tester.tap(submit);
    await tester.pump();
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();

    expect(find.text('Submitting...'), findsOneWidget);
    expect(repo.submitCoachPaymentReceiptCalls, 1);

    repo.submitCoachPaymentReceiptCompleter!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Payment proof submitted for coach verification.'),
      findsOneWidget,
    );
  });

  testWidgets('receipt upload path is passed to payment proof submit', (
    tester,
  ) async {
    FilePicker? originalPicker;
    try {
      originalPicker = FilePicker.platform;
    } catch (_) {
      originalPicker = null;
    }
    FilePicker.platform = _FakeFilePicker(
      FilePickerResult(<PlatformFile>[
        PlatformFile(
          name: 'receipt.pdf',
          size: 3,
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      ]),
    );
    if (originalPicker != null) {
      addTearDown(() => FilePicker.platform = originalPicker!);
    }

    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_pendingSubscription()]
      ..uploadedCoachPaymentReceiptPath = 'member-1/sub-1/uploaded.pdf';

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-submit-payment-proof-action-sub-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('member-payment-proof-upload-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('member-payment-proof-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(repo.uploadCoachPaymentReceiptCalls, 1);
    expect(repo.lastUploadedCoachPaymentReceiptSubscriptionId, 'sub-1');
    expect(repo.lastUploadedCoachPaymentReceiptFileName, 'receipt.pdf');
    expect(
      repo.lastSubmittedCoachPaymentReceiptPayload?['receiptStoragePath'],
      'member-1/sub-1/uploaded.pdf',
    );
  });

  testWidgets('unreadable receipt file is rejected before upload', (
    tester,
  ) async {
    FilePicker? originalPicker;
    try {
      originalPicker = FilePicker.platform;
    } catch (_) {
      originalPicker = null;
    }
    FilePicker.platform = _FakeFilePicker(
      FilePickerResult(<PlatformFile>[
        PlatformFile(name: 'receipt.pdf', size: 10, bytes: null),
      ]),
    );
    if (originalPicker != null) {
      addTearDown(() => FilePicker.platform = originalPicker!);
    }

    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_pendingSubscription()];

    await pumpScreen(tester, repo);
    await tester.tap(
      find.byKey(const Key('member-submit-payment-proof-action-sub-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('member-payment-proof-upload-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('member-payment-proof-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Selected receipt file could not be read. Please choose another file.',
      ),
      findsOneWidget,
    );
    expect(repo.uploadCoachPaymentReceiptCalls, 0);
    expect(repo.submitCoachPaymentReceiptCalls, 0);
  });

  testWidgets('Paymob retry loading prevents duplicate checkout', (
    tester,
  ) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_paymobSubscription()];
    final paymentRepo = FakeCoachPaymentRepository()
      ..createPaymobCheckoutCompleter = Completer<CoachPaymobCheckoutSession>();

    await pumpScreen(tester, repo, paymentRepo: paymentRepo);

    final retry = find.text('Retry payment', skipOffstage: false);
    await tester.ensureVisible(retry);
    final retryCenter = tester.getCenter(retry);
    await tester.tap(retry);
    await tester.pump();
    await tester.tapAt(retryCenter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Starting...'), findsOneWidget);
    expect(paymentRepo.createPaymobCheckoutCalls, 1);

    paymentRepo.createPaymobCheckoutCompleter!.complete(
      paymentRepo.checkoutSession,
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment checkout reopened.'), findsOneWidget);
  });

  testWidgets('Paymob retry error is sanitized', (tester) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_paymobSubscription()];
    final paymentRepo = FakeCoachPaymentRepository()
      ..createPaymobCheckoutError = StateError('paymob down');

    await pumpScreen(tester, repo, paymentRepo: paymentRepo);

    final retry = find.text('Retry payment', skipOffstage: false);
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(paymentRepo.createPaymobCheckoutCalls, 1);
    expect(
      find.text('Payment retry could not be started. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('paymob down'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('Paymob refresh shows loading and success feedback', (
    tester,
  ) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[
        _paymobSubscription(checkoutStatus: 'payment_pending'),
      ];
    final paymentRepo = FakeCoachPaymentRepository();

    await pumpScreen(tester, repo, paymentRepo: paymentRepo);

    await tester.tap(find.text('Refresh status'));
    await tester.pump();

    expect(find.text('Refreshing...'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(paymentRepo.createPaymobCheckoutCalls, 0);
    expect(find.text('Payment status refreshed.'), findsOneWidget);
  });

  testWidgets('non-Paymob refresh shows visible feedback', (tester) async {
    final repo = FakeMemberRepository()
      ..subscriptions = <SubscriptionEntity>[_manualFailedSubscription()];

    await pumpScreen(tester, repo);

    await tester.tap(find.text('Refresh status'));
    await tester.pumpAndSettle();

    expect(find.text('Subscription status refreshed.'), findsOneWidget);
  });
}

SubscriptionEntity _subscription({String status = 'active'}) {
  return SubscriptionEntity(
    id: 'sub-1',
    memberId: 'member-1',
    coachId: 'coach-1',
    coachName: 'Mona Coach',
    packageTitle: 'Starter Coaching',
    status: status,
    checkoutStatus: 'paid',
    amount: 1200,
    planName: 'Starter Coaching',
    threadId: 'thread-1',
  );
}

SubscriptionEntity _pendingSubscription() {
  return const SubscriptionEntity(
    id: 'sub-1',
    memberId: 'member-1',
    coachId: 'coach-1',
    coachName: 'Mona Coach',
    packageTitle: 'Starter Coaching',
    status: 'checkout_pending',
    checkoutStatus: 'payment_pending',
    amount: 1200,
    planName: 'Starter Coaching',
  );
}

SubscriptionEntity _manualFailedSubscription() {
  return const SubscriptionEntity(
    id: 'sub-1',
    memberId: 'member-1',
    coachId: 'coach-1',
    coachName: 'Mona Coach',
    packageTitle: 'Starter Coaching',
    status: 'failed',
    checkoutStatus: 'failed',
    amount: 1200,
    planName: 'Starter Coaching',
  );
}

SubscriptionEntity _paymobSubscription({String checkoutStatus = 'failed'}) {
  return SubscriptionEntity(
    id: 'sub-1',
    memberId: 'member-1',
    coachId: 'coach-1',
    coachName: 'Mona Coach',
    packageId: 'package-1',
    packageTitle: 'Starter Coaching',
    status: 'checkout_pending',
    checkoutStatus: checkoutStatus,
    paymentGateway: 'paymob',
    paymentMethod: 'paymob',
    amount: 1200,
    planName: 'Starter Coaching',
  );
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return result;
  }
}
