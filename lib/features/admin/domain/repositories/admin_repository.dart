import '../entities/admin_entities.dart';

abstract class AdminRepository {
  Future<AdminUserEntity?> getCurrentAdmin();

  Future<AdminDashboardSummaryEntity> getDashboardSummary();

  Future<List<AdminPaymentOrderEntity>> listPaymentOrders({
    String? status,
    String? search,
    String? payoutStatus,
  });

  Future<AdminPaymentOrderEntity> getPaymentOrderDetails(String paymentOrderId);

  Future<List<AdminPayoutEntity>> listPayouts({String? status, String? search});

  Future<AdminPayoutEntity> getPayoutDetails(String payoutId);

  Future<List<AdminCoachBalanceEntity>> listCoachBalances({String? search});

  Future<List<AdminSubscriptionEntity>> listSubscriptions({
    String? status,
    String? search,
  });

  Future<List<AdminAuditEventEntity>> listAuditEvents({
    String? action,
    String? targetType,
  });

  Future<AdminSettingsEntity> getSettings();

  Future<AdminTaiyoBriefEntity> requestTaiyoAdminOpsBrief({
    String requestType = 'admin_ops_brief',
    String? paymentOrderId,
    String? subscriptionId,
    String? payoutId,
    int? limit,
  });

  Future<void> markPayoutReady(String payoutId, {String? note});
  Future<void> holdPayout(String payoutId, {required String reason});
  Future<void> releasePayout(String payoutId, {String? note});
  Future<void> markPayoutProcessing(String payoutId, {String? note});
  Future<void> markPayoutPaid({
    required String payoutId,
    required String method,
    required String externalReference,
    String? adminNote,
  });
  Future<void> markPayoutFailed(String payoutId, {required String reason});
  Future<void> cancelPayout(String payoutId, {required String reason});
  Future<void> reconcilePaymentOrder(String paymentOrderId);
  Future<void> markPaymentNeedsReview(String paymentOrderId, String reason);
  Future<void> cancelUnpaidCheckout(String paymentOrderId, String reason);
  Future<void> ensureSubscriptionThread(String subscriptionId);
  Future<void> verifyCoachPayoutAccount({
    required String coachId,
    required bool isVerified,
    String? note,
  });
}
