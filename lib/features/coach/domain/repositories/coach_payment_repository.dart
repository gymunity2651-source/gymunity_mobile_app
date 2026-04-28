import '../entities/coach_payment_entity.dart';
import '../entities/subscription_entity.dart';

abstract class CoachPaymentRepository {
  Future<CoachPaymobCheckoutSession> createPaymobCheckout({
    required String packageId,
    String? coachId,
    CoachSubscriptionIntakeEntity intakeSnapshot =
        const CoachSubscriptionIntakeEntity(),
    String? note,
  });

  Future<CoachPaymentOrderEntity?> getPaymentOrder(String paymentOrderId);
}
