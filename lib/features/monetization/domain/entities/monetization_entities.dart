import 'dart:io';

import '../../../../core/config/app_config.dart';

enum PaymentPath {
  storeBilling,
  externalPhysicalGoods,
  externalHumanService,
  unclear,
}

enum OfferingCategory {
  physicalGoods,
  physicalServicesConsumedOutsideTheApp,
  realTimeOneToOnePersonToPersonService,
  oneToFewLiveDigitalService,
  oneToManyLiveDigitalService,
  recordedDigitalContent,
  digitalSubscription,
  featureUnlock,
  unclear,
}

enum OfferingCode {
  aiPremium('ai_premium');

  const OfferingCode(this.value);

  final String value;
}

enum AiPremiumPlan {
  monthly('monthly'),
  annual('annual');

  const AiPremiumPlan(this.value);

  final String value;
}

enum SubscriptionLifecycleState {
  pending,
  active,
  renewing,
  cancellationRequestedActiveUntilExpiry,
  expired,
  gracePeriod,
  onHoldOrSuspended,
  restoredOrRestarted,
  revokedOrRefunded,
  unknown,
}

enum EntitlementStatus {
  enabled,
  disabled,
  pending,
  verificationRequired,
}

enum PlanChangeTiming {
  immediate,
  nextRenewal,
  storeManaged,
  unknown,
}

enum PurchaseActionState {
  idle,
  loadingProducts,
  purchasing,
  restoring,
  pending,
  cancelled,
  failed,
  synced,
}

class DigitalOfferingBenefit {
  const DigitalOfferingBenefit({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class StoreProductMapping {
  const StoreProductMapping({
    required this.offeringCode,
    required this.plan,
    required this.appleProductId,
    required this.googleProductId,
    required this.googleBasePlanId,
  });

  final OfferingCode offeringCode;
  final AiPremiumPlan plan;
  final String appleProductId;
  final String googleProductId;
  final String googleBasePlanId;

  String? productIdForCurrentPlatform() {
    if (Platform.isIOS) {
      return appleProductId.trim().isEmpty ? null : appleProductId.trim();
    }
    if (Platform.isAndroid) {
      return googleProductId.trim().isEmpty ? null : googleProductId.trim();
    }
    return null;
  }
}

class StoreProductView {
  const StoreProductView({
    required this.offeringCode,
    required this.plan,
    required this.storeProductId,
    required this.displayTitle,
    required this.description,
    required this.priceLabel,
    required this.currencyCode,
    required this.rawPrice,
    this.billingPeriodLabel,
    this.basePlanId,
    this.offerToken,
    this.isAvailable = true,
  });

  final OfferingCode offeringCode;
  final AiPremiumPlan plan;
  final String storeProductId;
  final String displayTitle;
  final String description;
  final String priceLabel;
  final String currencyCode;
  final double rawPrice;
  final String? billingPeriodLabel;
  final String? basePlanId;
  final String? offerToken;
  final bool isAvailable;
}

class BillingCatalog {
  const BillingCatalog({
    required this.offeringCode,
    required this.paymentPath,
    required this.category,
    required this.benefits,
    required this.productsByPlan,
    required this.billingAvailable,
    this.errorMessage,
  });

  final OfferingCode offeringCode;
  final PaymentPath paymentPath;
  final OfferingCategory category;
  final List<DigitalOfferingBenefit> benefits;
  final Map<AiPremiumPlan, StoreProductView> productsByPlan;
  final bool billingAvailable;
  final String? errorMessage;

  StoreProductView? plan(AiPremiumPlan plan) => productsByPlan[plan];
  bool get hasProducts => productsByPlan.isNotEmpty;
}

class EntitlementState {
  const EntitlementState({
    required this.offeringCode,
    required this.status,
    required this.lifecycleState,
    required this.isActive,
    this.message,
  });

  final OfferingCode offeringCode;
  final EntitlementStatus status;
  final SubscriptionLifecycleState lifecycleState;
  final bool isActive;
  final String? message;
}

class CurrentSubscriptionSummary {
  const CurrentSubscriptionSummary({
    required this.offeringCode,
    required this.entitlement,
    required this.paymentPath,
    this.plan,
    this.storePlatform,
    this.storeProductId,
    this.storeBasePlanId,
    this.latestTransactionId,
    this.latestPurchaseToken,
    this.expiresAt,
    this.renewsAt,
    this.lastVerifiedAt,
    this.cancellationRequestedAt,
    this.gracePeriodUntil,
    this.manageUrl,
  });

  final OfferingCode offeringCode;
  final EntitlementState entitlement;
  final PaymentPath paymentPath;
  final AiPremiumPlan? plan;
  final String? storePlatform;
  final String? storeProductId;
  final String? storeBasePlanId;
  final String? latestTransactionId;
  final String? latestPurchaseToken;
  final DateTime? expiresAt;
  final DateTime? renewsAt;
  final DateTime? lastVerifiedAt;
  final DateTime? cancellationRequestedAt;
  final DateTime? gracePeriodUntil;
  final String? manageUrl;

  bool get hasAccess => entitlement.isActive;
}

class MonetizationConfig {
  const MonetizationConfig({
    required this.enableAiPremium,
    required this.aiPremiumMappings,
  });

  factory MonetizationConfig.fromAppConfig(AppConfig config) {
    return MonetizationConfig(
      enableAiPremium: config.enableAiPremium,
      aiPremiumMappings: <StoreProductMapping>[
        StoreProductMapping(
          offeringCode: OfferingCode.aiPremium,
          plan: AiPremiumPlan.monthly,
          appleProductId: config.appleAiPremiumMonthlyProductId,
          googleProductId: config.googleAiPremiumSubscriptionId,
          googleBasePlanId: config.googleAiPremiumMonthlyBasePlanId,
        ),
        StoreProductMapping(
          offeringCode: OfferingCode.aiPremium,
          plan: AiPremiumPlan.annual,
          appleProductId: config.appleAiPremiumAnnualProductId,
          googleProductId: config.googleAiPremiumSubscriptionId,
          googleBasePlanId: config.googleAiPremiumAnnualBasePlanId,
        ),
      ],
    );
  }

  final bool enableAiPremium;
  final List<StoreProductMapping> aiPremiumMappings;

  List<String> get productIdsForCurrentPlatform {
    final ids = <String>{};
    for (final mapping in aiPremiumMappings) {
      final productId = mapping.productIdForCurrentPlatform();
      if (productId != null && productId.isNotEmpty) {
        ids.add(productId);
      }
    }
    return ids.toList(growable: false);
  }

  StoreProductMapping? mappingForPlan(AiPremiumPlan plan) {
    for (final mapping in aiPremiumMappings) {
      if (mapping.plan == plan) {
        return mapping;
      }
    }
    return null;
  }
}
