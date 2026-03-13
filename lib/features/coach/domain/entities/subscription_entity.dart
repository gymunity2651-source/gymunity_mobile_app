class SubscriptionEntity {
  const SubscriptionEntity({
    required this.id,
    required this.memberId,
    required this.coachId,
    required this.status,
    required this.amount,
    required this.planName,
    this.coachName,
    this.packageId,
    this.packageTitle,
    this.billingCycle = 'monthly',
    this.paymentMethod = 'manual',
    this.startsAt,
    this.endsAt,
    this.activatedAt,
    this.cancelledAt,
    this.createdAt,
  });

  final String id;
  final String memberId;
  final String coachId;
  final String? coachName;
  final String? packageId;
  final String? packageTitle;
  final String status;
  final double amount;
  final String planName;
  final String billingCycle;
  final String paymentMethod;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? activatedAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;

  String get displayTitle =>
      packageTitle?.trim().isNotEmpty == true ? packageTitle!.trim() : planName;
}
