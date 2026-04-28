import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/config/app_config.dart';
import 'package:my_app/features/coach/domain/entities/coach_payment_entity.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';

void main() {
  test('Paymob feature flags default to safe values', () {
    final config = AppConfig.fromMap(const <String, String>{
      'APP_ENV': 'dev',
      'SUPABASE_URL': 'https://example.supabase.co',
      'SUPABASE_ANON_KEY': 'anon',
    });

    expect(config.enableCoachPaymobPayments, isFalse);
    expect(config.enableCoachManualPaymentProofs, isTrue);
  });

  test('Paymob subscription reports payment-specific status labels', () {
    const subscription = SubscriptionEntity(
      id: 'sub-1',
      memberId: 'member-1',
      coachId: 'coach-1',
      status: 'checkout_pending',
      checkoutStatus: 'checkout_pending',
      paymentGateway: 'paymob',
      paymentOrderId: 'order-1',
      amount: 1200,
      planName: 'Starter Coaching',
    );

    expect(subscription.isPaymobPayment, isTrue);
    expect(subscription.billingStatusLabel, 'Payment pending');
  });

  test('Paymob checkout session maps public checkout fields only', () {
    final session = CoachPaymobCheckoutSession.fromMap(const <String, dynamic>{
      'payment_order_id': 'order-1',
      'subscription_id': 'sub-1',
      'paymob_client_secret': 'client-secret',
      'paymob_public_key': 'public-key',
      'checkout_url': 'https://accept.paymob.com/unifiedcheckout/',
      'amount_gross_cents': 120000,
      'currency': 'EGP',
      'mode': 'test',
      'status': 'pending',
    });

    expect(session.isTestMode, isTrue);
    expect(session.isPending, isTrue);
    expect(session.clientSecret, 'client-secret');
    expect(session.publicKey, 'public-key');
    expect(session.amountGrossCents, 120000);
  });

  test('payment order maps payout amounts as integer cents', () {
    final order = CoachPaymentOrderEntity.fromMap(const <String, dynamic>{
      'id': 'order-1',
      'subscription_id': 'sub-1',
      'member_id': 'member-1',
      'coach_id': 'coach-1',
      'amount_gross_cents': 120000,
      'platform_fee_cents': 18000,
      'gateway_fee_cents': 0,
      'coach_net_cents': 102000,
      'currency': 'EGP',
      'payment_gateway': 'paymob',
      'mode': 'test',
      'status': 'paid',
    });

    expect(order.isPaid, isTrue);
    expect(order.isTestMode, isTrue);
    expect(order.amountLabel, 'EGP 1200');
    expect(order.coachNetCents, 102000);
  });
}
