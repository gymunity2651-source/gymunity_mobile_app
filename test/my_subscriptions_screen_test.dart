import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/member/presentation/screens/my_subscriptions_screen.dart';

import 'test_doubles.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    FakeMemberRepository repo,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[memberRepositoryProvider.overrideWithValue(repo)],
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
      find.textContaining('Subscription could not be paused:'),
      findsOneWidget,
    );
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
      find.textContaining('Payment proof could not be submitted:'),
      findsOneWidget,
    );
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
