import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/app_failure.dart';
import '../../domain/entities/monetization_entities.dart';
import '../providers/monetization_providers.dart';

class SubscriptionManagementState {
  const SubscriptionManagementState({
    this.actionState = PurchaseActionState.idle,
    this.activePlan,
    this.message,
  });

  final PurchaseActionState actionState;
  final AiPremiumPlan? activePlan;
  final String? message;

  SubscriptionManagementState copyWith({
    PurchaseActionState? actionState,
    AiPremiumPlan? activePlan,
    String? message,
    bool clearMessage = false,
  }) {
    return SubscriptionManagementState(
      actionState: actionState ?? this.actionState,
      activePlan: activePlan ?? this.activePlan,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class SubscriptionManagementController
    extends StateNotifier<SubscriptionManagementState> {
  SubscriptionManagementController(this._ref)
    : super(const SubscriptionManagementState());

  final Ref _ref;

  Future<void> purchase(AiPremiumPlan plan) async {
    state = state.copyWith(
      actionState: PurchaseActionState.purchasing,
      activePlan: plan,
      clearMessage: true,
    );

    try {
      final config = _ref.read(monetizationConfigProvider);
      final token = await _ref
          .read(entitlementRepositoryProvider)
          .ensureBillingCustomerToken();
      final currentSubscription = _ref.read(
        currentSubscriptionSummaryProvider,
      );

      await _ref
          .read(billingRepositoryProvider)
          .purchaseAiPremium(
            plan: plan,
            config: config,
            applicationUserName: token,
            currentSubscription: currentSubscription.valueOrNull,
          );

      state = state.copyWith(
        actionState: PurchaseActionState.pending,
        message:
            'Complete the purchase in the store dialog. GymUnity will unlock AI Premium after verification succeeds.',
      );
    } on AppFailure catch (error) {
      state = state.copyWith(
        actionState: PurchaseActionState.failed,
        message: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        actionState: PurchaseActionState.failed,
        message: 'GymUnity could not start the purchase flow.',
      );
    }
  }

  Future<void> restore() async {
    state = state.copyWith(
      actionState: PurchaseActionState.restoring,
      clearMessage: true,
    );

    try {
      final token = await _ref
          .read(entitlementRepositoryProvider)
          .ensureBillingCustomerToken();
      await _ref
          .read(billingRepositoryProvider)
          .restorePurchases(applicationUserName: token);
      state = state.copyWith(
        actionState: PurchaseActionState.pending,
        message:
            'GymUnity asked the store to restore purchases. Verified entitlements will appear here automatically.',
      );
    } on AppFailure catch (error) {
      state = state.copyWith(
        actionState: PurchaseActionState.failed,
        message: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        actionState: PurchaseActionState.failed,
        message: 'GymUnity could not start purchase restoration.',
      );
    }
  }

  void clearMessage() {
    state = state.copyWith(
      clearMessage: true,
      actionState: PurchaseActionState.idle,
    );
  }
}
