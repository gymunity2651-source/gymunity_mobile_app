import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/ai_branding.dart';
import '../../../../core/error/app_failure.dart';
import '../../domain/entities/monetization_entities.dart';
import '../../domain/repositories/entitlement_repository.dart';

class EntitlementRepositoryImpl implements EntitlementRepository {
  EntitlementRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<String> ensureBillingCustomerToken() async {
    try {
      final response = await _client.rpc('ensure_billing_customer');
      if (response is Map<String, dynamic>) {
        return (response['app_account_token'] as String? ?? '').trim();
      }
      if (response is String) {
        return response.trim();
      }
      throw const NetworkFailure(
        message: 'GymUnity could not create a billing customer token.',
      );
    } on PostgrestException catch (error, stackTrace) {
      throw NetworkFailure(
        message: error.message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<CurrentSubscriptionSummary?> getCurrentSubscription() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return null;
      }

      final row = await _client
          .from('subscription_entitlements')
          .select(
            'offering_code,entitlement_code,entitlement_status,lifecycle_state,'
            'plan_code,source_platform,store_product_id,store_base_plan_id,'
            'latest_transaction_id,latest_purchase_token,access_expires_at,'
            'renews_at,last_verified_at,cancellation_requested_at,'
            'grace_period_until,metadata',
          )
          .eq('user_id', userId)
          .eq('offering_code', OfferingCode.aiPremium.value)
          .maybeSingle();

      if (row == null) {
        return null;
      }
      return _mapSummary(row);
    } on PostgrestException catch (error, stackTrace) {
      throw NetworkFailure(
        message: error.message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<CurrentSubscriptionSummary?> refreshCurrentSubscription() async {
    try {
      final response = await _client.functions.invoke(
        'billing-refresh-entitlement',
        body: <String, dynamic>{'offering_code': OfferingCode.aiPremium.value},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final summary = data['summary'];
        if (summary is Map<String, dynamic>) {
          return _mapSummary(summary);
        }
      }
      return getCurrentSubscription();
    } on FunctionException catch (error, stackTrace) {
      throw PaymentFailure(
        message:
            error.details?.toString() ??
            'GymUnity could not refresh your premium access.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<CurrentSubscriptionSummary?> syncPurchase(
    PurchaseDetails purchase,
  ) async {
    final functionName = _resolveFunctionName(purchase);
    final payload = _purchasePayload(purchase);
    try {
      final response = await _client.functions.invoke(
        functionName,
        body: payload,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final summary = data['summary'];
        if (summary is Map<String, dynamic>) {
          return _mapSummary(summary);
        }
      }
      return getCurrentSubscription();
    } on FunctionException catch (error, stackTrace) {
      throw PaymentFailure(
        message:
            error.details?.toString() ??
            'GymUnity could not verify this purchase yet.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _resolveFunctionName(PurchaseDetails purchase) {
    if (purchase is GooglePlayPurchaseDetails || Platform.isAndroid) {
      return 'billing-verify-google';
    }
    return 'billing-verify-apple';
  }

  Map<String, dynamic> _purchasePayload(PurchaseDetails purchase) {
    final payload = <String, dynamic>{
      'offering_code': OfferingCode.aiPremium.value,
      'product_id': purchase.productID,
      'purchase_id': purchase.purchaseID,
      'transaction_date': purchase.transactionDate,
      'purchase_status': purchase.status.name,
      'verification_data': <String, dynamic>{
        'source': purchase.verificationData.source,
        'local_verification_data':
            purchase.verificationData.localVerificationData,
        'server_verification_data':
            purchase.verificationData.serverVerificationData,
      },
    };

    if (purchase is GooglePlayPurchaseDetails) {
      payload['google'] = <String, dynamic>{
        'purchase_token': purchase.billingClientPurchase.purchaseToken,
        'obfuscated_account_id':
            purchase.billingClientPurchase.obfuscatedAccountId,
        'package_name': purchase.billingClientPurchase.packageName,
        'products': purchase.billingClientPurchase.products,
        'original_json': purchase.billingClientPurchase.originalJson,
      };
    }

    return payload;
  }

  CurrentSubscriptionSummary _mapSummary(Map<String, dynamic> row) {
    final lifecycleState = _lifecycleFromRaw(row['lifecycle_state'] as String?);
    final entitlementStatus = _entitlementStatusFromRaw(
      row['entitlement_status'] as String?,
    );

    final planRaw = row['plan_code'] as String?;
    AiPremiumPlan? plan;
    switch (planRaw) {
      case 'monthly':
        plan = AiPremiumPlan.monthly;
      case 'annual':
        plan = AiPremiumPlan.annual;
      default:
        plan = null;
    }

    final platform = row['source_platform'] as String?;
    return CurrentSubscriptionSummary(
      offeringCode: OfferingCode.aiPremium,
      paymentPath: PaymentPath.storeBilling,
      plan: plan,
      storePlatform: platform,
      storeProductId: row['store_product_id'] as String?,
      storeBasePlanId: row['store_base_plan_id'] as String?,
      latestTransactionId: row['latest_transaction_id'] as String?,
      latestPurchaseToken: row['latest_purchase_token'] as String?,
      expiresAt: _parseDate(row['access_expires_at']),
      renewsAt: _parseDate(row['renews_at']),
      lastVerifiedAt: _parseDate(row['last_verified_at']),
      cancellationRequestedAt: _parseDate(row['cancellation_requested_at']),
      gracePeriodUntil: _parseDate(row['grace_period_until']),
      manageUrl: _manageUrlForPlatform(platform),
      entitlement: EntitlementState(
        offeringCode: OfferingCode.aiPremium,
        status: entitlementStatus,
        lifecycleState: lifecycleState,
        isActive: entitlementStatus == EntitlementStatus.enabled,
        message: _messageForLifecycle(lifecycleState),
      ),
    );
  }

  String? _manageUrlForPlatform(String? platform) {
    switch (platform?.trim().toLowerCase()) {
      case 'android':
        return 'https://play.google.com/store/account/subscriptions';
      case 'ios':
      case 'apple':
        return 'https://apps.apple.com/account/subscriptions';
      default:
        return null;
    }
  }

  SubscriptionLifecycleState _lifecycleFromRaw(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'pending':
        return SubscriptionLifecycleState.pending;
      case 'active':
        return SubscriptionLifecycleState.active;
      case 'renewing':
        return SubscriptionLifecycleState.renewing;
      case 'cancellation_requested_active_until_expiry':
        return SubscriptionLifecycleState
            .cancellationRequestedActiveUntilExpiry;
      case 'expired':
        return SubscriptionLifecycleState.expired;
      case 'grace_period':
        return SubscriptionLifecycleState.gracePeriod;
      case 'on_hold_or_suspended':
        return SubscriptionLifecycleState.onHoldOrSuspended;
      case 'restored_or_restarted':
        return SubscriptionLifecycleState.restoredOrRestarted;
      case 'revoked_or_refunded':
        return SubscriptionLifecycleState.revokedOrRefunded;
      default:
        return SubscriptionLifecycleState.unknown;
    }
  }

  EntitlementStatus _entitlementStatusFromRaw(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'enabled':
        return EntitlementStatus.enabled;
      case 'pending':
        return EntitlementStatus.pending;
      case 'verification_required':
        return EntitlementStatus.verificationRequired;
      default:
        return EntitlementStatus.disabled;
    }
  }

  String _messageForLifecycle(SubscriptionLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case SubscriptionLifecycleState.pending:
        return 'Your purchase is still pending store confirmation.';
      case SubscriptionLifecycleState.active:
        return '${AiBranding.premiumName} is active.';
      case SubscriptionLifecycleState.renewing:
        return '${AiBranding.premiumName} will renew automatically.';
      case SubscriptionLifecycleState.cancellationRequestedActiveUntilExpiry:
        return '${AiBranding.premiumName} stays active until the current term ends.';
      case SubscriptionLifecycleState.expired:
        return 'Your ${AiBranding.premiumName} subscription has expired.';
      case SubscriptionLifecycleState.gracePeriod:
        return 'Your billing is in a grace period. Access is still active for now.';
      case SubscriptionLifecycleState.onHoldOrSuspended:
        return 'Your subscription is on hold. Update billing to regain access.';
      case SubscriptionLifecycleState.restoredOrRestarted:
        return 'Your subscription was restored successfully.';
      case SubscriptionLifecycleState.revokedOrRefunded:
        return 'This purchase was revoked or refunded.';
      case SubscriptionLifecycleState.unknown:
        return 'GymUnity could not determine your current subscription state.';
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
