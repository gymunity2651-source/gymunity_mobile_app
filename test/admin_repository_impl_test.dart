import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/error/app_failure.dart';
import 'package:my_app/features/admin/data/repositories/admin_repository_impl.dart';

void main() {
  group('TAIYO admin ops brief mapping', () {
    test('builds request body for the Edge Function', () {
      final body = adminTaiyoOpsBriefRequestBody(
        requestType: 'payment_order_risk',
        paymentOrderId: 'payment-1',
        subscriptionId: 'sub-1',
        payoutId: 'payout-1',
        limit: 20,
      );

      expect(body['request_type'], 'payment_order_risk');
      expect(body['payment_order_id'], 'payment-1');
      expect(body['subscription_id'], 'sub-1');
      expect(body['payout_id'], 'payout-1');
      expect(body['limit'], 20);
    });

    test('omits empty scoped identifiers', () {
      final body = adminTaiyoOpsBriefRequestBody(
        requestType: 'admin_ops_brief',
        paymentOrderId: '',
        subscriptionId: ' ',
      );

      expect(body['request_type'], 'admin_ops_brief');
      expect(body.containsKey('payment_order_id'), isFalse);
      expect(body.containsKey('subscription_id'), isFalse);
    });

    test('maps normalized success response safely', () {
      final brief = adminTaiyoBriefFromResponse(<String, dynamic>{
        'request_type': 'payment_order_risk',
        'status': 'success',
        'result': <String, dynamic>{
          'issue_type': 'paid_subscription_mismatch',
          'status_summary': 'Paid payment has incomplete subscription state.',
          'risk_level': 'high',
          'recommended_admin_action': 'admin_reconcile_payment_order',
          'action_label': 'Reconcile payment order',
          'reason': 'Repair payment-derived subscription state first.',
          'audit_notes': <String>['Recommendation only'],
          'manual_confirmation_required': true,
          'sensitive_data_excluded': true,
        },
        'data_quality': <String, dynamic>{
          'missing_fields': <String>[],
          'confidence': 'high',
        },
        'metadata': <String, dynamic>{'generated_at': '2026-05-03T10:00:00Z'},
      });

      expect(brief.status, 'success');
      expect(brief.riskLevel, 'high');
      expect(brief.hasRecommendedAction, isTrue);
      expect(brief.manualConfirmationRequired, isTrue);
      expect(brief.sensitiveDataExcluded, isTrue);
    });

    test('maps security-blocked response without throwing', () {
      final brief = adminTaiyoBriefFromResponse(<String, dynamic>{
        'request_type': 'admin_ops_brief',
        'status': 'blocked_for_security',
        'result': <String, dynamic>{
          'issue_type': 'security_request',
          'status_summary': 'Secrets cannot be exposed.',
          'risk_level': 'high',
          'manual_confirmation_required': true,
          'sensitive_data_excluded': true,
        },
        'data_quality': <String, dynamic>{},
        'metadata': <String, dynamic>{},
      });

      expect(brief.isSecurityBlocked, isTrue);
      expect(brief.statusSummary, contains('Secrets'));
    });

    test('throws NetworkFailure for malformed response', () {
      expect(
        () => adminTaiyoBriefFromResponse(null),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
