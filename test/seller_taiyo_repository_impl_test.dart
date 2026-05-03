import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/error/app_failure.dart';
import 'package:my_app/features/seller/data/repositories/seller_repository_impl.dart';

void main() {
  group('TAIYO seller copilot mapping', () {
    test('builds request body without empty optional ids', () {
      final body = sellerCopilotRequestBody(
        requestType: 'seller_dashboard_brief',
        productId: '',
        orderId: 'order-1',
      );

      expect(body['request_type'], 'seller_dashboard_brief');
      expect(body.containsKey('product_id'), isFalse);
      expect(body['order_id'], 'order-1');
    });

    test('maps normalized success response safely', () {
      final brief = sellerTaiyoCopilotFromResponse(<String, dynamic>{
        'request_type': 'seller_dashboard_brief',
        'status': 'success',
        'result': <String, dynamic>{
          'summary': 'Orders are steady.',
          'priority_actions': <String>['Restock bands'],
          'product_opportunities': <String>['Bundle accessories'],
          'order_notes': <String>['Two pending orders'],
          'risk_level': 'medium',
          'recommended_next_step': 'Review inventory.',
        },
        'data_quality': <String, dynamic>{
          'missing_fields': <String>[],
          'confidence': 'high',
        },
        'metadata': <String, dynamic>{'generated_at': '2026-05-02T10:00:00Z'},
      });

      expect(brief.status, 'success');
      expect(brief.summary, 'Orders are steady.');
      expect(brief.priorityActions, contains('Restock bands'));
      expect(brief.riskLevel, 'medium');
      expect(brief.confidence, 'high');
    });

    test('throws NetworkFailure for malformed response', () {
      expect(
        () => sellerTaiyoCopilotFromResponse(null),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
