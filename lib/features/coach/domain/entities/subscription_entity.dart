class SubscriptionEntity {
  const SubscriptionEntity({
    required this.id,
    required this.memberId,
    required this.coachId,
    required this.status,
    required this.amount,
    required this.planName,
  });

  final String id;
  final String memberId;
  final String coachId;
  final String status;
  final double amount;
  final String planName;
}

