import 'package:in_app_purchase/in_app_purchase.dart';

import '../entities/monetization_entities.dart';

abstract class BillingRepository {
  Stream<List<PurchaseDetails>> get purchaseUpdates;

  Future<BillingCatalog> loadAiPremiumCatalog(MonetizationConfig config);

  Future<void> purchaseAiPremium({
    required AiPremiumPlan plan,
    required MonetizationConfig config,
    required String applicationUserName,
    CurrentSubscriptionSummary? currentSubscription,
  });

  Future<void> restorePurchases({required String applicationUserName});

  Future<List<PurchaseDetails>> queryExistingPurchases();

  Future<void> completePurchase(PurchaseDetails purchaseDetails);
}
