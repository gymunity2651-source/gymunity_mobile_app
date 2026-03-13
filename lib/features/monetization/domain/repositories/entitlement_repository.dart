import 'package:in_app_purchase/in_app_purchase.dart';

import '../entities/monetization_entities.dart';

abstract class EntitlementRepository {
  Future<String> ensureBillingCustomerToken();

  Future<CurrentSubscriptionSummary?> getCurrentSubscription();

  Future<CurrentSubscriptionSummary?> refreshCurrentSubscription();

  Future<CurrentSubscriptionSummary?> syncPurchase(PurchaseDetails purchase);
}
