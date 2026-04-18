import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

import '../../../../core/constants/ai_branding.dart';
import '../../../../core/error/app_failure.dart';
import '../../domain/entities/monetization_entities.dart';
import '../../domain/repositories/billing_repository.dart';

class BillingRepositoryImpl implements BillingRepository {
  BillingRepositoryImpl(this._inAppPurchase);

  final InAppPurchase _inAppPurchase;

  @override
  Stream<List<PurchaseDetails>> get purchaseUpdates =>
      _inAppPurchase.purchaseStream;

  @override
  Future<BillingCatalog> loadAiPremiumCatalog(MonetizationConfig config) async {
    const benefits = <DigitalOfferingBenefit>[
      DigitalOfferingBenefit(
        title: 'Unlimited TAIYO chat',
        description: 'Start and continue TAIYO conversations on demand.',
      ),
      DigitalOfferingBenefit(
        title: 'TAIYO-guided plans',
        description:
            'Generate and revisit TAIYO-driven workout planning flows.',
      ),
      DigitalOfferingBenefit(
        title: 'Cross-device restore',
        description:
            'Restore your subscription after reinstalling or switching devices.',
      ),
    ];

    if (!config.enableAiPremium) {
      return const BillingCatalog(
        offeringCode: OfferingCode.aiPremium,
        paymentPath: PaymentPath.storeBilling,
        category: OfferingCategory.digitalSubscription,
        benefits: benefits,
        productsByPlan: <AiPremiumPlan, StoreProductView>{},
        billingAvailable: false,
        errorMessage: '${AiBranding.premiumName} is disabled in this build.',
      );
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      return const BillingCatalog(
        offeringCode: OfferingCode.aiPremium,
        paymentPath: PaymentPath.storeBilling,
        category: OfferingCategory.digitalSubscription,
        benefits: benefits,
        productsByPlan: <AiPremiumPlan, StoreProductView>{},
        billingAvailable: false,
        errorMessage: 'Store billing is only available on iOS and Android.',
      );
    }

    final isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      return const BillingCatalog(
        offeringCode: OfferingCode.aiPremium,
        paymentPath: PaymentPath.storeBilling,
        category: OfferingCategory.digitalSubscription,
        benefits: benefits,
        productsByPlan: <AiPremiumPlan, StoreProductView>{},
        billingAvailable: false,
        errorMessage: 'Store billing is unavailable on this device.',
      );
    }

    final ids = config.productIdsForCurrentPlatform.toSet();
    if (ids.isEmpty) {
      throw const ConfigFailure(
        message:
            '${AiBranding.premiumName} product IDs are missing for this platform.',
      );
    }

    final response = await _inAppPurchase.queryProductDetails(ids);
    if (response.error != null) {
      throw PaymentFailure(
        message: response.error!.message,
        code: response.error!.code,
      );
    }

    final productsByPlan = <AiPremiumPlan, StoreProductView>{};
    for (final mapping in config.aiPremiumMappings) {
      final product = _matchProductDetails(
        mapping: mapping,
        details: response.productDetails,
      );
      if (product != null) {
        productsByPlan[mapping.plan] = product;
      }
    }

    return BillingCatalog(
      offeringCode: OfferingCode.aiPremium,
      paymentPath: PaymentPath.storeBilling,
      category: OfferingCategory.digitalSubscription,
      benefits: benefits,
      productsByPlan: productsByPlan,
      billingAvailable: true,
      errorMessage: response.notFoundIDs.isEmpty
          ? null
          : 'Missing store products: ${response.notFoundIDs.join(', ')}',
    );
  }

  @override
  Future<void> purchaseAiPremium({
    required AiPremiumPlan plan,
    required MonetizationConfig config,
    required String applicationUserName,
    CurrentSubscriptionSummary? currentSubscription,
  }) async {
    final catalog = await loadAiPremiumCatalog(config);
    final product = catalog.plan(plan);
    if (product == null) {
      throw const ConfigFailure(
        message:
            'The selected ${AiBranding.premiumName} plan is not available.',
      );
    }

    final productDetails = await _resolveProductDetails(
      plan: plan,
      config: config,
    );
    final purchaseParam = await _buildPurchaseParam(
      productDetails: productDetails,
      applicationUserName: applicationUserName,
      currentSubscription: currentSubscription,
    );

    final launched = await _inAppPurchase.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
    if (!launched) {
      throw const PaymentFailure(
        message: 'GymUnity could not open the store purchase flow.',
      );
    }
  }

  @override
  Future<void> restorePurchases({required String applicationUserName}) {
    return _inAppPurchase.restorePurchases(
      applicationUserName: applicationUserName,
    );
  }

  @override
  Future<List<PurchaseDetails>> queryExistingPurchases() async {
    if (!Platform.isAndroid) {
      return const <PurchaseDetails>[];
    }

    final addition = _inAppPurchase
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    if (response.error != null) {
      throw PaymentFailure(
        message: response.error!.message,
        code: response.error!.code,
      );
    }
    return response.pastPurchases;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchaseDetails) async {
    if (!purchaseDetails.pendingCompletePurchase) {
      return;
    }
    await _inAppPurchase.completePurchase(purchaseDetails);
  }

  Future<ProductDetails> _resolveProductDetails({
    required AiPremiumPlan plan,
    required MonetizationConfig config,
  }) async {
    final mapping = config.mappingForPlan(plan);
    if (mapping == null) {
      throw const ConfigFailure(message: 'Unknown TAIYO Premium plan mapping.');
    }

    final ids = config.productIdsForCurrentPlatform.toSet();
    final response = await _inAppPurchase.queryProductDetails(ids);
    if (response.error != null) {
      throw PaymentFailure(
        message: response.error!.message,
        code: response.error!.code,
      );
    }

    final product = _matchNativeProductDetails(
      mapping: mapping,
      details: response.productDetails,
    );
    if (product == null) {
      throw ConfigFailure(
        message:
            'The ${plan.value} ${AiBranding.premiumName} plan is missing from store metadata.',
      );
    }
    return product;
  }

  StoreProductView? _matchProductDetails({
    required StoreProductMapping mapping,
    required List<ProductDetails> details,
  }) {
    final product = _matchNativeProductDetails(
      mapping: mapping,
      details: details,
    );
    if (product == null) {
      return null;
    }

    final basePlanId = _basePlanId(product);
    return StoreProductView(
      offeringCode: mapping.offeringCode,
      plan: mapping.plan,
      storeProductId: product.id,
      displayTitle: product.title,
      description: product.description,
      priceLabel: product.price,
      currencyCode: _currencyCode(product),
      rawPrice: product.rawPrice,
      billingPeriodLabel: _billingPeriodLabel(mapping.plan),
      basePlanId: basePlanId,
      offerToken: _offerToken(product),
      isAvailable: true,
    );
  }

  ProductDetails? _matchNativeProductDetails({
    required StoreProductMapping mapping,
    required List<ProductDetails> details,
  }) {
    if (Platform.isIOS) {
      final wanted = mapping.appleProductId.trim();
      for (final product in details) {
        if (product.id == wanted) {
          return product;
        }
      }
      return null;
    }

    if (Platform.isAndroid) {
      final wantedProductId = mapping.googleProductId.trim();
      final wantedBasePlanId = mapping.googleBasePlanId.trim();
      for (final product in details) {
        if (product.id != wantedProductId) {
          continue;
        }
        if (product is GooglePlayProductDetails) {
          final basePlanId = _basePlanId(product);
          if (basePlanId == wantedBasePlanId) {
            return product;
          }
        }
      }
    }

    return null;
  }

  Future<PurchaseParam> _buildPurchaseParam({
    required ProductDetails productDetails,
    required String applicationUserName,
    required CurrentSubscriptionSummary? currentSubscription,
  }) async {
    if (Platform.isAndroid && productDetails is GooglePlayProductDetails) {
      ChangeSubscriptionParam? changeSubscriptionParam;
      final existing = await _findCurrentGoogleSubscription(
        currentSubscription: currentSubscription,
      );
      if (existing != null && existing.productID == productDetails.id) {
        changeSubscriptionParam = ChangeSubscriptionParam(
          oldPurchaseDetails: existing,
          replacementMode: ReplacementMode.withTimeProration,
        );
      }

      return GooglePlayPurchaseParam(
        productDetails: productDetails,
        applicationUserName: applicationUserName,
        offerToken: productDetails.offerToken,
        changeSubscriptionParam: changeSubscriptionParam,
      );
    }

    return PurchaseParam(
      productDetails: productDetails,
      applicationUserName: applicationUserName,
    );
  }

  Future<GooglePlayPurchaseDetails?> _findCurrentGoogleSubscription({
    required CurrentSubscriptionSummary? currentSubscription,
  }) async {
    if (!Platform.isAndroid) {
      return null;
    }
    if (currentSubscription == null || !currentSubscription.hasAccess) {
      return null;
    }

    final purchases = await queryExistingPurchases();
    for (final purchase in purchases) {
      if (purchase is! GooglePlayPurchaseDetails) {
        continue;
      }
      if (purchase.productID != currentSubscription.storeProductId) {
        continue;
      }
      return purchase;
    }
    return null;
  }

  String _currencyCode(ProductDetails productDetails) {
    return productDetails.currencyCode;
  }

  String _billingPeriodLabel(AiPremiumPlan plan) {
    switch (plan) {
      case AiPremiumPlan.monthly:
        return 'Monthly';
      case AiPremiumPlan.annual:
        return 'Annual';
    }
  }

  String? _basePlanId(ProductDetails productDetails) {
    if (productDetails is! GooglePlayProductDetails ||
        productDetails.subscriptionIndex == null) {
      return null;
    }
    return productDetails
        .productDetails
        .subscriptionOfferDetails?[productDetails.subscriptionIndex!]
        .basePlanId;
  }

  String? _offerToken(ProductDetails productDetails) {
    if (productDetails is! GooglePlayProductDetails) {
      return null;
    }
    return productDetails.offerToken;
  }
}
