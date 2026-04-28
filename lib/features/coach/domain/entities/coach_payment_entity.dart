class CoachPaymobCheckoutSession {
  const CoachPaymobCheckoutSession({
    required this.paymentOrderId,
    required this.subscriptionId,
    required this.clientSecret,
    required this.publicKey,
    required this.checkoutUrl,
    required this.amountGrossCents,
    required this.currency,
    required this.mode,
    this.status = 'pending',
  });

  final String paymentOrderId;
  final String subscriptionId;
  final String clientSecret;
  final String publicKey;
  final String checkoutUrl;
  final int amountGrossCents;
  final String currency;
  final String mode;
  final String status;

  bool get isTestMode => mode.toLowerCase() == 'test';
  bool get isPending => status == 'created' || status == 'pending';

  factory CoachPaymobCheckoutSession.fromMap(Map<String, dynamic> map) {
    return CoachPaymobCheckoutSession(
      paymentOrderId: _string(map['payment_order_id']),
      subscriptionId: _string(map['subscription_id']),
      clientSecret: _string(
        map['paymob_client_secret'] ?? map['client_secret'],
      ),
      publicKey: _string(map['paymob_public_key'] ?? map['public_key']),
      checkoutUrl: _string(map['checkout_url']),
      amountGrossCents: _int(map['amount_gross_cents']),
      currency: _string(map['currency'], fallback: 'EGP'),
      mode: _string(map['mode'], fallback: 'test'),
      status: _string(map['status'], fallback: 'pending'),
    );
  }
}

class CoachPaymentOrderEntity {
  const CoachPaymentOrderEntity({
    required this.id,
    required this.subscriptionId,
    required this.memberId,
    required this.coachId,
    this.packageId,
    this.amountGrossCents = 0,
    this.platformFeeCents = 0,
    this.gatewayFeeCents = 0,
    this.coachNetCents = 0,
    this.currency = 'EGP',
    this.paymentGateway = 'paymob',
    this.mode = 'test',
    this.status = 'created',
    this.checkoutUrl,
    this.failureReason,
    this.paidAt,
    this.failedAt,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String subscriptionId;
  final String memberId;
  final String coachId;
  final String? packageId;
  final int amountGrossCents;
  final int platformFeeCents;
  final int gatewayFeeCents;
  final int coachNetCents;
  final String currency;
  final String paymentGateway;
  final String mode;
  final String status;
  final String? checkoutUrl;
  final String? failureReason;
  final DateTime? paidAt;
  final DateTime? failedAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPaymob => paymentGateway.toLowerCase() == 'paymob';
  bool get isTestMode => mode.toLowerCase() == 'test';
  bool get isPaid => status == 'paid';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'created' || status == 'pending';

  String get amountLabel {
    final major = amountGrossCents / 100;
    return '$currency ${major.toStringAsFixed(0)}';
  }

  factory CoachPaymentOrderEntity.fromMap(Map<String, dynamic> map) {
    return CoachPaymentOrderEntity(
      id: _string(map['id']),
      subscriptionId: _string(map['subscription_id']),
      memberId: _string(map['member_id']),
      coachId: _string(map['coach_id']),
      packageId: _nullableString(map['package_id']),
      amountGrossCents: _int(map['amount_gross_cents']),
      platformFeeCents: _int(map['platform_fee_cents']),
      gatewayFeeCents: _int(map['gateway_fee_cents']),
      coachNetCents: _int(map['coach_net_cents']),
      currency: _string(map['currency'], fallback: 'EGP'),
      paymentGateway: _string(map['payment_gateway'], fallback: 'paymob'),
      mode: _string(map['mode'], fallback: 'test'),
      status: _string(map['status'], fallback: 'created'),
      checkoutUrl: _nullableString(map['checkout_url']),
      failureReason: _nullableString(map['failure_reason']),
      paidAt: _date(map['paid_at']),
      failedAt: _date(map['failed_at']),
      cancelledAt: _date(map['cancelled_at']),
      createdAt: _date(map['created_at']),
      updatedAt: _date(map['updated_at']),
    );
  }
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
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
