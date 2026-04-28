class AdminUserEntity {
  const AdminUserEntity({
    required this.userId,
    required this.role,
    this.permissions = const <String, bool>{},
    this.isActive = false,
  });

  final String userId;
  final String role;
  final Map<String, bool> permissions;
  final bool isActive;

  bool get isSuperAdmin => role == 'super_admin';
  bool get canMarkPayoutPaid =>
      isSuperAdmin ||
      role == 'finance_admin' ||
      permissions['payouts.mark_paid'] == true;
  bool get canWritePayouts =>
      isSuperAdmin ||
      role == 'finance_admin' ||
      permissions['payouts.write'] == true;
  bool get canWritePayments =>
      isSuperAdmin ||
      role == 'finance_admin' ||
      permissions['payments.write'] == true;
  bool get canViewRawPayload => isSuperAdmin;

  factory AdminUserEntity.fromMap(Map<String, dynamic> map) {
    return AdminUserEntity(
      userId: _string(map['user_id']),
      role: _string(map['role'], fallback: 'support_admin'),
      permissions: _boolMap(map['permissions']),
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class AdminDashboardSummaryEntity {
  const AdminDashboardSummaryEntity({
    this.mode = 'test',
    this.paymentKpis = const <String, num>{},
    this.payoutKpis = const <String, num>{},
    this.operationalKpis = const <String, num>{},
    this.successfulPayments = const <AdminPaymentOrderEntity>[],
    this.failedPayments = const <AdminPaymentOrderEntity>[],
    this.auditEvents = const <AdminAuditEventEntity>[],
    this.alerts = const <String, List<Map<String, dynamic>>>{},
  });

  final String mode;
  final Map<String, num> paymentKpis;
  final Map<String, num> payoutKpis;
  final Map<String, num> operationalKpis;
  final List<AdminPaymentOrderEntity> successfulPayments;
  final List<AdminPaymentOrderEntity> failedPayments;
  final List<AdminAuditEventEntity> auditEvents;
  final Map<String, List<Map<String, dynamic>>> alerts;

  factory AdminDashboardSummaryEntity.fromMap(Map<String, dynamic> map) {
    final recent = _map(map['recent_activity']);
    return AdminDashboardSummaryEntity(
      mode: _string(map['mode'], fallback: 'test'),
      paymentKpis: _numMap(map['payment_kpis']),
      payoutKpis: _numMap(map['payout_kpis']),
      operationalKpis: _numMap(map['operational_kpis']),
      successfulPayments: _list(recent['successful_payments'])
          .map((item) => AdminPaymentOrderEntity.fromMap(_map(item)))
          .toList(growable: false),
      failedPayments: _list(recent['failed_payments'])
          .map((item) => AdminPaymentOrderEntity.fromMap(_map(item)))
          .toList(growable: false),
      auditEvents: _list(recent['audit_events'])
          .map((item) => AdminAuditEventEntity.fromMap(_map(item)))
          .toList(growable: false),
      alerts: _alertsMap(map['alerts']),
    );
  }
}

class AdminPaymentOrderEntity {
  const AdminPaymentOrderEntity({
    required this.id,
    this.subscriptionId,
    this.memberId,
    this.coachId,
    this.packageId,
    this.memberName = 'Member',
    this.memberEmail,
    this.coachName = 'Coach',
    this.coachEmail,
    this.packageTitle = 'Coaching',
    this.amountGrossCents = 0,
    this.platformFeeCents = 0,
    this.gatewayFeeCents = 0,
    this.coachNetCents = 0,
    this.currency = 'EGP',
    this.status = 'created',
    this.mode = 'test',
    this.specialReference,
    this.paymobOrderId,
    this.paymobTransactionId,
    this.paymobIntentionId,
    this.subscriptionStatus,
    this.checkoutStatus,
    this.threadId,
    this.payoutId,
    this.payoutStatus,
    this.needsReview = false,
    this.reviewReason,
    this.adminNote,
    this.failureReason,
    this.transactions = const <AdminPaymentTransactionEntity>[],
    this.auditEvents = const <AdminAuditEventEntity>[],
    this.rawCreateIntentionResponse,
    this.createdAt,
    this.updatedAt,
    this.paidAt,
    this.failedAt,
    this.cancelledAt,
  });

  final String id;
  final String? subscriptionId;
  final String? memberId;
  final String? coachId;
  final String? packageId;
  final String memberName;
  final String? memberEmail;
  final String coachName;
  final String? coachEmail;
  final String packageTitle;
  final int amountGrossCents;
  final int platformFeeCents;
  final int gatewayFeeCents;
  final int coachNetCents;
  final String currency;
  final String status;
  final String mode;
  final String? specialReference;
  final String? paymobOrderId;
  final String? paymobTransactionId;
  final String? paymobIntentionId;
  final String? subscriptionStatus;
  final String? checkoutStatus;
  final String? threadId;
  final String? payoutId;
  final String? payoutStatus;
  final bool needsReview;
  final String? reviewReason;
  final String? adminNote;
  final String? failureReason;
  final List<AdminPaymentTransactionEntity> transactions;
  final List<AdminAuditEventEntity> auditEvents;
  final Map<String, dynamic>? rawCreateIntentionResponse;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;
  final DateTime? failedAt;
  final DateTime? cancelledAt;

  String get amountLabel => _money(amountGrossCents, currency);
  bool get isPaid => status == 'paid';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'created' || status == 'pending';

  factory AdminPaymentOrderEntity.fromMap(Map<String, dynamic> map) {
    return AdminPaymentOrderEntity(
      id: _string(map['id']),
      subscriptionId: _nullableString(map['subscription_id']),
      memberId: _nullableString(map['member_id']),
      coachId: _nullableString(map['coach_id']),
      packageId: _nullableString(map['package_id']),
      memberName: _string(map['member_name'], fallback: 'Member'),
      memberEmail: _nullableString(map['member_email']),
      coachName: _string(map['coach_name'], fallback: 'Coach'),
      coachEmail: _nullableString(map['coach_email']),
      packageTitle: _string(map['package_title'], fallback: 'Coaching'),
      amountGrossCents: _int(map['amount_gross_cents']),
      platformFeeCents: _int(map['platform_fee_cents']),
      gatewayFeeCents: _int(map['gateway_fee_cents']),
      coachNetCents: _int(map['coach_net_cents']),
      currency: _string(map['currency'], fallback: 'EGP'),
      status: _string(map['status'], fallback: 'created'),
      mode: _string(map['mode'], fallback: 'test'),
      specialReference: _nullableString(map['special_reference']),
      paymobOrderId: _nullableString(map['paymob_order_id']),
      paymobTransactionId: _nullableString(map['paymob_transaction_id']),
      paymobIntentionId: _nullableString(map['paymob_intention_id']),
      subscriptionStatus: _nullableString(map['subscription_status']),
      checkoutStatus: _nullableString(map['checkout_status']),
      threadId: _nullableString(map['thread_id']),
      payoutId: _nullableString(map['payout_id']),
      payoutStatus: _nullableString(map['payout_status']),
      needsReview: map['needs_review'] as bool? ?? false,
      reviewReason: _nullableString(map['review_reason']),
      adminNote: _nullableString(map['admin_note']),
      failureReason: _nullableString(map['failure_reason']),
      transactions: _list(map['transactions'])
          .map((item) => AdminPaymentTransactionEntity.fromMap(_map(item)))
          .toList(growable: false),
      auditEvents: _list(map['audit_events'])
          .map((item) => AdminAuditEventEntity.fromMap(_map(item)))
          .toList(growable: false),
      rawCreateIntentionResponse: _nullableMap(
        map['raw_create_intention_response'],
      ),
      createdAt: _date(map['created_at']),
      updatedAt: _date(map['updated_at']),
      paidAt: _date(map['paid_at']),
      failedAt: _date(map['failed_at']),
      cancelledAt: _date(map['cancelled_at']),
    );
  }
}

class AdminPaymentTransactionEntity {
  const AdminPaymentTransactionEntity({
    required this.id,
    this.paymobTransactionId,
    this.success,
    this.pending,
    this.amountCents,
    this.currency,
    this.hmacVerified = false,
    this.processingResult,
    this.rawPayload,
    this.receivedAt,
  });

  final String id;
  final String? paymobTransactionId;
  final bool? success;
  final bool? pending;
  final int? amountCents;
  final String? currency;
  final bool hmacVerified;
  final String? processingResult;
  final Map<String, dynamic>? rawPayload;
  final DateTime? receivedAt;

  factory AdminPaymentTransactionEntity.fromMap(Map<String, dynamic> map) {
    return AdminPaymentTransactionEntity(
      id: _string(map['id']),
      paymobTransactionId: _nullableString(map['paymob_transaction_id']),
      success: map['success'] as bool?,
      pending: map['pending'] as bool?,
      amountCents: map['amount_cents'] == null
          ? null
          : _int(map['amount_cents']),
      currency: _nullableString(map['currency']),
      hmacVerified: map['hmac_verified'] as bool? ?? false,
      processingResult: _nullableString(map['processing_result']),
      rawPayload: _nullableMap(map['raw_payload']),
      receivedAt: _date(map['received_at']),
    );
  }
}

class AdminPayoutEntity {
  const AdminPayoutEntity({
    required this.id,
    required this.coachId,
    this.coachName = 'Coach',
    this.coachEmail,
    this.amountCents = 0,
    this.currency = 'EGP',
    this.status = 'pending',
    this.method = 'manual',
    this.adminName,
    this.externalReference,
    this.adminNote,
    this.itemCount = 0,
    this.account = const <String, dynamic>{},
    this.items = const <AdminPayoutItemEntity>[],
    this.auditEvents = const <AdminAuditEventEntity>[],
    this.createdAt,
    this.readyAt,
    this.paidAt,
    this.failedAt,
    this.cancelledAt,
  });

  final String id;
  final String coachId;
  final String coachName;
  final String? coachEmail;
  final int amountCents;
  final String currency;
  final String status;
  final String method;
  final String? adminName;
  final String? externalReference;
  final String? adminNote;
  final int itemCount;
  final Map<String, dynamic> account;
  final List<AdminPayoutItemEntity> items;
  final List<AdminAuditEventEntity> auditEvents;
  final DateTime? createdAt;
  final DateTime? readyAt;
  final DateTime? paidAt;
  final DateTime? failedAt;
  final DateTime? cancelledAt;

  String get amountLabel => _money(amountCents, currency);
  bool get canMarkPaid => status == 'ready' || status == 'processing';

  factory AdminPayoutEntity.fromMap(Map<String, dynamic> map) {
    return AdminPayoutEntity(
      id: _string(map['id']),
      coachId: _string(map['coach_id']),
      coachName: _string(map['coach_name'], fallback: 'Coach'),
      coachEmail: _nullableString(map['coach_email']),
      amountCents: _int(map['amount_cents']),
      currency: _string(map['currency'], fallback: 'EGP'),
      status: _string(map['status'], fallback: 'pending'),
      method: _string(map['method'], fallback: 'manual'),
      adminName: _nullableString(map['admin_name']),
      externalReference: _nullableString(map['external_reference']),
      adminNote: _nullableString(map['admin_note']),
      itemCount: _int(map['item_count']),
      account: _map(map['account']),
      items: _list(map['items'])
          .map((item) => AdminPayoutItemEntity.fromMap(_map(item)))
          .toList(growable: false),
      auditEvents: _list(map['audit_events'])
          .map((item) => AdminAuditEventEntity.fromMap(_map(item)))
          .toList(growable: false),
      createdAt: _date(map['created_at']),
      readyAt: _date(map['ready_at']),
      paidAt: _date(map['paid_at']),
      failedAt: _date(map['failed_at']),
      cancelledAt: _date(map['cancelled_at']),
    );
  }
}

class AdminPayoutItemEntity {
  const AdminPayoutItemEntity({
    required this.id,
    required this.paymentOrderId,
    this.subscriptionId,
    this.grossCents = 0,
    this.platformFeeCents = 0,
    this.gatewayFeeCents = 0,
    this.coachNetCents = 0,
    this.paymentOrder,
  });

  final String id;
  final String paymentOrderId;
  final String? subscriptionId;
  final int grossCents;
  final int platformFeeCents;
  final int gatewayFeeCents;
  final int coachNetCents;
  final AdminPaymentOrderEntity? paymentOrder;

  factory AdminPayoutItemEntity.fromMap(Map<String, dynamic> map) {
    final orderMap = _nullableMap(map['payment_order']);
    return AdminPayoutItemEntity(
      id: _string(map['id']),
      paymentOrderId: _string(map['payment_order_id']),
      subscriptionId: _nullableString(map['subscription_id']),
      grossCents: _int(map['gross_cents']),
      platformFeeCents: _int(map['platform_fee_cents']),
      gatewayFeeCents: _int(map['gateway_fee_cents']),
      coachNetCents: _int(map['coach_net_cents']),
      paymentOrder: orderMap == null
          ? null
          : AdminPaymentOrderEntity.fromMap(orderMap),
    );
  }
}

class AdminCoachBalanceEntity {
  const AdminCoachBalanceEntity({
    required this.coachId,
    this.coachName = 'Coach',
    this.coachEmail,
    this.activeClientsCount = 0,
    this.totalPaidClientPaymentsCents = 0,
    this.totalPlatformFeesCents = 0,
    this.totalCoachNetEarnedCents = 0,
    this.pendingPayoutAmountCents = 0,
    this.paidPayoutAmountCents = 0,
    this.onHoldAmountCents = 0,
    this.payoutAccount = const <String, dynamic>{},
    this.lastPayoutDate,
  });

  final String coachId;
  final String coachName;
  final String? coachEmail;
  final int activeClientsCount;
  final int totalPaidClientPaymentsCents;
  final int totalPlatformFeesCents;
  final int totalCoachNetEarnedCents;
  final int pendingPayoutAmountCents;
  final int paidPayoutAmountCents;
  final int onHoldAmountCents;
  final Map<String, dynamic> payoutAccount;
  final DateTime? lastPayoutDate;

  factory AdminCoachBalanceEntity.fromMap(Map<String, dynamic> map) {
    return AdminCoachBalanceEntity(
      coachId: _string(map['coach_id']),
      coachName: _string(map['coach_name'], fallback: 'Coach'),
      coachEmail: _nullableString(map['coach_email']),
      activeClientsCount: _int(map['active_clients_count']),
      totalPaidClientPaymentsCents: _int(
        map['total_paid_client_payments_cents'],
      ),
      totalPlatformFeesCents: _int(map['total_platform_fees_cents']),
      totalCoachNetEarnedCents: _int(map['total_coach_net_earned_cents']),
      pendingPayoutAmountCents: _int(map['pending_payout_amount_cents']),
      paidPayoutAmountCents: _int(map['paid_payout_amount_cents']),
      onHoldAmountCents: _int(map['on_hold_amount_cents']),
      payoutAccount: _map(map['payout_account']),
      lastPayoutDate: _date(map['last_payout_date']),
    );
  }
}

class AdminSubscriptionEntity {
  const AdminSubscriptionEntity({
    required this.subscriptionId,
    this.memberName = 'Member',
    this.coachName = 'Coach',
    this.packageTitle = 'Coaching',
    this.status = 'checkout_pending',
    this.checkoutStatus = 'not_started',
    this.paymentOrderId,
    this.paymentOrderStatus,
    this.threadExists = false,
    this.threadId,
    this.payoutStatus,
    this.activatedAt,
    this.currentPeriodEnd,
  });

  final String subscriptionId;
  final String memberName;
  final String coachName;
  final String packageTitle;
  final String status;
  final String checkoutStatus;
  final String? paymentOrderId;
  final String? paymentOrderStatus;
  final bool threadExists;
  final String? threadId;
  final String? payoutStatus;
  final DateTime? activatedAt;
  final DateTime? currentPeriodEnd;

  factory AdminSubscriptionEntity.fromMap(Map<String, dynamic> map) {
    return AdminSubscriptionEntity(
      subscriptionId: _string(map['subscription_id']),
      memberName: _string(map['member_name'], fallback: 'Member'),
      coachName: _string(map['coach_name'], fallback: 'Coach'),
      packageTitle: _string(map['package_title'], fallback: 'Coaching'),
      status: _string(map['status'], fallback: 'checkout_pending'),
      checkoutStatus: _string(map['checkout_status'], fallback: 'not_started'),
      paymentOrderId: _nullableString(map['payment_order_id']),
      paymentOrderStatus: _nullableString(map['payment_order_status']),
      threadExists: map['thread_exists'] as bool? ?? false,
      threadId: _nullableString(map['thread_id']),
      payoutStatus: _nullableString(map['payout_status']),
      activatedAt: _date(map['activated_at']),
      currentPeriodEnd: _date(map['current_period_end']),
    );
  }
}

class AdminAuditEventEntity {
  const AdminAuditEventEntity({
    required this.id,
    this.actorUserId,
    this.actorName,
    required this.action,
    required this.targetType,
    this.targetId,
    this.metadata = const <String, dynamic>{},
    this.createdAt,
  });

  final String id;
  final String? actorUserId;
  final String? actorName;
  final String action;
  final String targetType;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  factory AdminAuditEventEntity.fromMap(Map<String, dynamic> map) {
    return AdminAuditEventEntity(
      id: _string(map['id']),
      actorUserId: _nullableString(map['actor_user_id']),
      actorName: _nullableString(map['actor_name']),
      action: _string(map['action']),
      targetType: _string(map['target_type']),
      targetId: _nullableString(map['target_id']),
      metadata: _map(map['metadata']),
      createdAt: _date(map['created_at']),
    );
  }
}

class AdminSettingsEntity {
  const AdminSettingsEntity({
    this.mode = 'test',
    this.currency = 'EGP',
    this.platformFeeBps = 0,
    this.payoutHoldDays = 0,
    this.apiBaseUrl = '',
    this.notificationUrlConfigured = false,
    this.redirectionUrlConfigured = false,
    this.testIntegrationIdsConfigured = false,
    this.secretKeyConfigured = false,
    this.hmacKeyConfigured = false,
  });

  final String mode;
  final String currency;
  final int platformFeeBps;
  final int payoutHoldDays;
  final String apiBaseUrl;
  final bool notificationUrlConfigured;
  final bool redirectionUrlConfigured;
  final bool testIntegrationIdsConfigured;
  final bool secretKeyConfigured;
  final bool hmacKeyConfigured;

  factory AdminSettingsEntity.fromMap(Map<String, dynamic> map) {
    return AdminSettingsEntity(
      mode: _string(map['mode'], fallback: 'test'),
      currency: _string(map['currency'], fallback: 'EGP'),
      platformFeeBps: _int(map['platform_fee_bps']),
      payoutHoldDays: _int(map['payout_hold_days']),
      apiBaseUrl: _string(map['api_base_url']),
      notificationUrlConfigured:
          map['notification_url_configured'] as bool? ?? false,
      redirectionUrlConfigured:
          map['redirection_url_configured'] as bool? ?? false,
      testIntegrationIdsConfigured:
          map['test_integration_ids_configured'] as bool? ?? false,
      secretKeyConfigured: map['secret_key_configured'] as bool? ?? false,
      hmacKeyConfigured: map['hmac_key_configured'] as bool? ?? false,
    );
  }
}

String formatAdminMoney(int cents, [String currency = 'EGP']) {
  return _money(cents, currency);
}

String _money(int cents, String currency) {
  final amount = cents / 100;
  return '$currency ${amount.toStringAsFixed(0)}';
}

String _string(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

Map<String, dynamic>? _nullableMap(dynamic value) {
  final map = _map(value);
  return map.isEmpty ? null : map;
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

Map<String, bool> _boolMap(dynamic value) {
  final map = _map(value);
  return map.map((key, value) => MapEntry(key, value == true));
}

Map<String, num> _numMap(dynamic value) {
  final map = _map(value);
  return map.map((key, value) {
    final number = value is num ? value : num.tryParse(value.toString()) ?? 0;
    return MapEntry(key, number);
  });
}

Map<String, List<Map<String, dynamic>>> _alertsMap(dynamic value) {
  final map = _map(value);
  return map.map((key, value) {
    return MapEntry(
      key,
      _list(value).map((item) => _map(item)).toList(growable: false),
    );
  });
}
