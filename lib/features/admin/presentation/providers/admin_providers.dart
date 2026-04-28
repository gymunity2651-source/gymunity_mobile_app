import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/admin_entities.dart';

final adminPaymentStatusFilterProvider = StateProvider<String?>((ref) => null);
final adminPaymentSearchProvider = StateProvider<String>((ref) => '');
final adminPayoutStatusFilterProvider = StateProvider<String?>((ref) => null);
final adminPayoutSearchProvider = StateProvider<String>((ref) => '');
final adminCoachSearchProvider = StateProvider<String>((ref) => '');
final adminSubscriptionStatusFilterProvider = StateProvider<String?>(
  (ref) => null,
);
final adminSubscriptionSearchProvider = StateProvider<String>((ref) => '');

final currentAdminProvider = FutureProvider<AdminUserEntity?>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getCurrentAdmin();
});

final adminPermissionsProvider = Provider<AdminUserEntity?>((ref) {
  return ref.watch(currentAdminProvider).valueOrNull;
});

final adminDashboardSummaryProvider =
    FutureProvider<AdminDashboardSummaryEntity>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      return repo.getDashboardSummary();
    });

final adminPaymentOrdersProvider =
    FutureProvider<List<AdminPaymentOrderEntity>>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      return repo.listPaymentOrders(
        status: ref.watch(adminPaymentStatusFilterProvider),
        search: ref.watch(adminPaymentSearchProvider),
      );
    });

final adminPaymentOrderDetailsProvider =
    FutureProvider.family<AdminPaymentOrderEntity, String>((
      ref,
      paymentOrderId,
    ) async {
      final repo = ref.watch(adminRepositoryProvider);
      return repo.getPaymentOrderDetails(paymentOrderId);
    });

final adminPayoutsProvider = FutureProvider<List<AdminPayoutEntity>>((
  ref,
) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.listPayouts(
    status: ref.watch(adminPayoutStatusFilterProvider),
    search: ref.watch(adminPayoutSearchProvider),
  );
});

final adminPayoutDetailsProvider =
    FutureProvider.family<AdminPayoutEntity, String>((ref, payoutId) async {
      final repo = ref.watch(adminRepositoryProvider);
      return repo.getPayoutDetails(payoutId);
    });

final adminCoachBalancesProvider =
    FutureProvider<List<AdminCoachBalanceEntity>>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      return repo.listCoachBalances(
        search: ref.watch(adminCoachSearchProvider),
      );
    });

final adminSubscriptionsProvider =
    FutureProvider<List<AdminSubscriptionEntity>>((ref) async {
      final repo = ref.watch(adminRepositoryProvider);
      return repo.listSubscriptions(
        status: ref.watch(adminSubscriptionStatusFilterProvider),
        search: ref.watch(adminSubscriptionSearchProvider),
      );
    });

final adminAuditEventsProvider = FutureProvider<List<AdminAuditEventEntity>>((
  ref,
) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.listAuditEvents();
});

final adminSettingsProvider = FutureProvider<AdminSettingsEntity>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getSettings();
});

final adminActionsControllerProvider = Provider<AdminActionsController>((ref) {
  return AdminActionsController(ref);
});

class AdminActionsController {
  AdminActionsController(this._ref);

  final Ref _ref;

  Future<void> markPayoutReady(String payoutId, {String? note}) async {
    await _ref
        .read(adminRepositoryProvider)
        .markPayoutReady(payoutId, note: note);
    _refreshPayouts();
  }

  Future<void> holdPayout(String payoutId, String reason) async {
    await _ref
        .read(adminRepositoryProvider)
        .holdPayout(payoutId, reason: reason);
    _refreshPayouts();
  }

  Future<void> releasePayout(String payoutId, {String? note}) async {
    await _ref
        .read(adminRepositoryProvider)
        .releasePayout(payoutId, note: note);
    _refreshPayouts();
  }

  Future<void> markPayoutProcessing(String payoutId, {String? note}) async {
    await _ref
        .read(adminRepositoryProvider)
        .markPayoutProcessing(payoutId, note: note);
    _refreshPayouts();
  }

  Future<void> markPayoutPaid({
    required String payoutId,
    required String method,
    required String externalReference,
    String? adminNote,
  }) async {
    await _ref
        .read(adminRepositoryProvider)
        .markPayoutPaid(
          payoutId: payoutId,
          method: method,
          externalReference: externalReference,
          adminNote: adminNote,
        );
    _refreshPayouts();
  }

  Future<void> markPayoutFailed(String payoutId, String reason) async {
    await _ref
        .read(adminRepositoryProvider)
        .markPayoutFailed(payoutId, reason: reason);
    _refreshPayouts();
  }

  Future<void> reconcilePayment(String paymentOrderId) async {
    await _ref
        .read(adminRepositoryProvider)
        .reconcilePaymentOrder(paymentOrderId);
    _refreshPayments();
  }

  Future<void> cancelUnpaidCheckout(
    String paymentOrderId,
    String reason,
  ) async {
    await _ref
        .read(adminRepositoryProvider)
        .cancelUnpaidCheckout(paymentOrderId, reason);
    _refreshPayments();
  }

  Future<void> ensureSubscriptionThread(String subscriptionId) async {
    await _ref
        .read(adminRepositoryProvider)
        .ensureSubscriptionThread(subscriptionId);
    _ref.invalidate(adminSubscriptionsProvider);
    _ref.invalidate(adminDashboardSummaryProvider);
  }

  void _refreshPayouts() {
    _ref.invalidate(adminPayoutsProvider);
    _ref.invalidate(adminDashboardSummaryProvider);
    _ref.invalidate(adminAuditEventsProvider);
  }

  void _refreshPayments() {
    _ref.invalidate(adminPaymentOrdersProvider);
    _ref.invalidate(adminDashboardSummaryProvider);
    _ref.invalidate(adminAuditEventsProvider);
  }
}
