import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/ai_branding.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/supabase/supabase_initializer.dart';
import '../../../../features/auth/domain/entities/auth_session.dart';
import '../../domain/entities/monetization_entities.dart';
import '../controllers/subscription_management_controller.dart';

class BillingInteractionEvent {
  const BillingInteractionEvent({
    required this.state,
    this.purchaseStatus,
    this.message,
  });

  final PurchaseActionState state;
  final PurchaseStatus? purchaseStatus;
  final String? message;
}

class AiPremiumGateDecision {
  const AiPremiumGateDecision._({
    required this.requiresBilling,
    required this.hasAccess,
    required this.title,
    required this.message,
    this.summary,
  });

  factory AiPremiumGateDecision.freeAccess() {
    return const AiPremiumGateDecision._(
      requiresBilling: false,
      hasAccess: true,
      title: '${AiBranding.assistantName} available',
      message: '${AiBranding.premiumName} is disabled in this build.',
    );
  }

  factory AiPremiumGateDecision.unlocked(CurrentSubscriptionSummary? summary) {
    return AiPremiumGateDecision._(
      requiresBilling: true,
      hasAccess: true,
      title: '${AiBranding.premiumName} active',
      message:
          summary?.entitlement.message ??
          '${AiBranding.premiumName} is active for this account.',
      summary: summary,
    );
  }

  factory AiPremiumGateDecision.locked(CurrentSubscriptionSummary? summary) {
    return AiPremiumGateDecision._(
      requiresBilling: true,
      hasAccess: false,
      title: '${AiBranding.premiumName} required',
      message:
          summary?.entitlement.message ??
          'Subscribe to ${AiBranding.premiumName} to use TAIYO chat and TAIYO-guided plans.',
      summary: summary,
    );
  }

  final bool requiresBilling;
  final bool hasAccess;
  final String title;
  final String message;
  final CurrentSubscriptionSummary? summary;
}

class CurrentSubscriptionController
    extends AsyncNotifier<CurrentSubscriptionSummary?> {
  @override
  Future<CurrentSubscriptionSummary?> build() {
    final config = ref.watch(monetizationConfigProvider);
    if (!config.enableAiPremium) {
      return Future<CurrentSubscriptionSummary?>.value(null);
    }
    return ref.read(entitlementRepositoryProvider).getCurrentSubscription();
  }

  Future<void> refreshFromBackend() async {
    state = await AsyncValue.guard(
      () =>
          ref.read(entitlementRepositoryProvider).refreshCurrentSubscription(),
    );
  }

  Future<void> syncPurchase(PurchaseDetails purchase) async {
    state = await AsyncValue.guard(
      () => ref.read(entitlementRepositoryProvider).syncPurchase(purchase),
    );
  }
}

class MonetizationBootstrapService {
  MonetizationBootstrapService(this._ref);

  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    final config = _ref.read(monetizationConfigProvider);
    if (!config.enableAiPremium) {
      return;
    }

    _purchaseSubscription = _ref
        .read(billingRepositoryProvider)
        .purchaseUpdates
        .listen(_handlePurchaseBatch);

    await refreshEntitlements();
    if (Platform.isAndroid) {
      await _reconcileExistingAndroidPurchases();
    }
  }

  Future<void> refreshEntitlements() async {
    final session = _ref.read(authSessionProvider).valueOrNull;
    if (session == null || !session.isAuthenticated) {
      _ref.read(billingInteractionEventProvider.notifier).state = null;
      _ref.invalidate(currentSubscriptionSummaryProvider);
      return;
    }

    await _ref
        .read(currentSubscriptionSummaryProvider.notifier)
        .refreshFromBackend();
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _started = false;
  }

  Future<void> _reconcileExistingAndroidPurchases() async {
    try {
      final purchases = await _ref
          .read(billingRepositoryProvider)
          .queryExistingPurchases();
      if (purchases.isNotEmpty) {
        await _handlePurchaseBatch(purchases);
      }
    } catch (_) {
      _ref
          .read(billingInteractionEventProvider.notifier)
          .state = const BillingInteractionEvent(
        state: PurchaseActionState.failed,
        message: 'GymUnity could not reconcile previous Google Play purchases.',
      );
    }
  }

  Future<void> _handlePurchaseBatch(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _ref
              .read(billingInteractionEventProvider.notifier)
              .state = const BillingInteractionEvent(
            state: PurchaseActionState.pending,
            purchaseStatus: PurchaseStatus.pending,
            message: 'Your purchase is pending store confirmation.',
          );
          break;
        case PurchaseStatus.canceled:
          _ref
              .read(billingInteractionEventProvider.notifier)
              .state = const BillingInteractionEvent(
            state: PurchaseActionState.cancelled,
            purchaseStatus: PurchaseStatus.canceled,
            message: 'Purchase cancelled. No premium access was granted.',
          );
          break;
        case PurchaseStatus.error:
          _ref
              .read(billingInteractionEventProvider.notifier)
              .state = BillingInteractionEvent(
            state: PurchaseActionState.failed,
            purchaseStatus: PurchaseStatus.error,
            message:
                purchase.error?.message ??
                'The store reported a purchase error.',
          );
          if (purchase.pendingCompletePurchase) {
            await _ref
                .read(billingRepositoryProvider)
                .completePurchase(purchase);
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            await _ref
                .read(currentSubscriptionSummaryProvider.notifier)
                .syncPurchase(purchase);
            _ref
                .read(billingInteractionEventProvider.notifier)
                .state = BillingInteractionEvent(
              state: PurchaseActionState.synced,
              purchaseStatus: purchase.status,
              message: purchase.status == PurchaseStatus.restored
                  ? 'Your purchase was restored and ${AiBranding.premiumName} is refreshed.'
                  : 'Purchase verified. ${AiBranding.premiumName} access is now refreshed.',
            );
          } catch (error) {
            _ref
                .read(billingInteractionEventProvider.notifier)
                .state = BillingInteractionEvent(
              state: PurchaseActionState.failed,
              purchaseStatus: purchase.status,
              message: error is Exception
                  ? error.toString().replaceFirst('Exception: ', '')
                  : 'GymUnity could not verify this purchase.',
            );
          }
          if (purchase.pendingCompletePurchase) {
            await _ref
                .read(billingRepositoryProvider)
                .completePurchase(purchase);
          }
          break;
      }
    }
  }
}

final monetizationConfigProvider = Provider<MonetizationConfig>((ref) {
  return MonetizationConfig.fromAppConfig(AppConfig.current);
});

final billingCatalogProvider = FutureProvider<BillingCatalog?>((ref) async {
  final config = ref.watch(monetizationConfigProvider);
  if (!config.enableAiPremium) {
    return null;
  }
  return ref.read(billingRepositoryProvider).loadAiPremiumCatalog(config);
});

final currentSubscriptionSummaryProvider =
    AsyncNotifierProvider<
      CurrentSubscriptionController,
      CurrentSubscriptionSummary?
    >(CurrentSubscriptionController.new);

final billingInteractionEventProvider = StateProvider<BillingInteractionEvent?>(
  (ref) => null,
);

final subscriptionManagementControllerProvider =
    StateNotifierProvider<
      SubscriptionManagementController,
      SubscriptionManagementState
    >((ref) {
      return SubscriptionManagementController(ref);
    });

final aiPremiumGateProvider = Provider<AsyncValue<AiPremiumGateDecision>>((
  ref,
) {
  final config = ref.watch(monetizationConfigProvider);
  if (!config.enableAiPremium) {
    return AsyncValue<AiPremiumGateDecision>.data(
      AiPremiumGateDecision.freeAccess(),
    );
  }

  final summaryAsync = ref.watch(currentSubscriptionSummaryProvider);
  return summaryAsync.whenData((summary) {
    if (summary?.hasAccess ?? false) {
      return AiPremiumGateDecision.unlocked(summary);
    }
    return AiPremiumGateDecision.locked(summary);
  });
});

final monetizationBootstrapProvider = Provider<MonetizationBootstrapService>((
  ref,
) {
  return MonetizationBootstrapService(ref);
});

final isAiPremiumEnabledProvider = Provider<bool>((ref) {
  return ref.watch(monetizationConfigProvider).enableAiPremium;
});

final shouldShowSubscriptionSettingsProvider = Provider<bool>((ref) {
  return ref.watch(isAiPremiumEnabledProvider);
});

final authAwareMonetizationProvider = Provider<void>((ref) {
  if (AppConfig.current.validationErrorMessage != null ||
      !SupabaseInitializer.isInitialized) {
    return;
  }

  ref.listen<AsyncValue<AuthSession?>>(authSessionProvider, (previous, next) {
    final previousId = previous?.valueOrNull?.userId;
    final nextId = next.valueOrNull?.userId;
    if (previousId == nextId) {
      return;
    }

    ref.invalidate(currentSubscriptionSummaryProvider);
    ref.read(billingInteractionEventProvider.notifier).state = null;

    final bootstrap = ref.read(monetizationBootstrapProvider);
    unawaited(bootstrap.refreshEntitlements());
  });
});
