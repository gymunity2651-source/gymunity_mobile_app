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
    this.memberName,
    this.memberNote,
    this.intakeSnapshot = const CoachSubscriptionIntakeEntity(),
    this.billingCycle = 'monthly',
    this.paymentMethod = 'manual',
    this.checkoutStatus = 'not_started',
    this.paymentGateway,
    this.paymentOrderId,
    this.amountCents,
    this.currency = 'EGP',
    this.platformFeeCents = 0,
    this.coachNetCents = 0,
    this.startsAt,
    this.endsAt,
    this.activatedAt,
    this.cancelledAt,
    this.createdAt,
    this.nextRenewalAt,
    this.pausedAt,
    this.cancelAtPeriodEnd = false,
    this.coachCity,
    this.trialDays,
    this.renewalPriceEgp,
    this.responseSlaHours,
    this.verificationStatus,
    this.weeklyCheckinType,
    this.deliveryMode,
    this.locationMode,
    this.threadId,
  });

  final String id;
  final String memberId;
  final String coachId;
  final String? coachName;
  final String? packageId;
  final String? packageTitle;
  final String? memberName;
  final String? memberNote;
  final CoachSubscriptionIntakeEntity intakeSnapshot;
  final String status;
  final double amount;
  final String planName;
  final String billingCycle;
  final String paymentMethod;
  final String checkoutStatus;
  final String? paymentGateway;
  final String? paymentOrderId;
  final int? amountCents;
  final String currency;
  final int platformFeeCents;
  final int coachNetCents;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? activatedAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? nextRenewalAt;
  final DateTime? pausedAt;
  final bool cancelAtPeriodEnd;
  final String? coachCity;
  final int? trialDays;
  final double? renewalPriceEgp;
  final int? responseSlaHours;
  final String? verificationStatus;
  final String? weeklyCheckinType;
  final String? deliveryMode;
  final String? locationMode;
  final String? threadId;

  String get displayTitle =>
      packageTitle?.trim().isNotEmpty == true ? packageTitle!.trim() : planName;

  bool get isActive => status == 'active';

  bool get isPaused => status == 'paused';

  bool get isPaymobPayment =>
      paymentGateway?.toLowerCase() == 'paymob' ||
      paymentMethod.toLowerCase() == 'paymob';

  bool get isCheckoutPending =>
      status == 'checkout_pending' ||
      status == 'pending_payment' ||
      status == 'pending_activation' ||
      checkoutStatus == 'checkout_pending' ||
      checkoutStatus == 'payment_pending';

  String get billingStatusLabel {
    if (status == 'active' || checkoutStatus == 'paid') {
      return 'Activated';
    }
    if (checkoutStatus == 'failed') {
      return isPaymobPayment ? 'Payment failed' : 'Failed / needs follow-up';
    }
    if (isPaymobPayment && checkoutStatus == 'paid') {
      return 'Payment confirmed';
    }
    if (isPaymobPayment && isCheckoutPending) {
      return 'Payment pending';
    }
    if (checkoutStatus == 'under_verification') {
      return 'Under verification';
    }
    if (checkoutStatus == 'receipt_uploaded') {
      return 'Receipt uploaded';
    }
    if (checkoutStatus == 'submitted') {
      return 'Payment submitted';
    }
    if (isCheckoutPending) {
      return 'Awaiting payment';
    }
    return status.replaceAll('_', ' ');
  }

  bool get isPaymentConfirmed => checkoutStatus == 'paid';

  bool get hasMessageThread => threadId?.trim().isNotEmpty == true;

  bool get canPause =>
      status == 'active' || status == 'paused' || cancelAtPeriodEnd;

  SubscriptionEntity copyWith({
    String? id,
    String? memberId,
    String? coachId,
    String? coachName,
    String? packageId,
    String? packageTitle,
    String? memberName,
    String? memberNote,
    CoachSubscriptionIntakeEntity? intakeSnapshot,
    String? status,
    double? amount,
    String? planName,
    String? billingCycle,
    String? paymentMethod,
    String? checkoutStatus,
    String? paymentGateway,
    String? paymentOrderId,
    int? amountCents,
    String? currency,
    int? platformFeeCents,
    int? coachNetCents,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? activatedAt,
    DateTime? cancelledAt,
    DateTime? createdAt,
    DateTime? nextRenewalAt,
    DateTime? pausedAt,
    bool? cancelAtPeriodEnd,
    String? coachCity,
    int? trialDays,
    double? renewalPriceEgp,
    int? responseSlaHours,
    String? verificationStatus,
    String? weeklyCheckinType,
    String? deliveryMode,
    String? locationMode,
    String? threadId,
  }) {
    return SubscriptionEntity(
      id: id ?? this.id,
      memberId: memberId ?? this.memberId,
      coachId: coachId ?? this.coachId,
      coachName: coachName ?? this.coachName,
      packageId: packageId ?? this.packageId,
      packageTitle: packageTitle ?? this.packageTitle,
      memberName: memberName ?? this.memberName,
      memberNote: memberNote ?? this.memberNote,
      intakeSnapshot: intakeSnapshot ?? this.intakeSnapshot,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      planName: planName ?? this.planName,
      billingCycle: billingCycle ?? this.billingCycle,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      checkoutStatus: checkoutStatus ?? this.checkoutStatus,
      paymentGateway: paymentGateway ?? this.paymentGateway,
      paymentOrderId: paymentOrderId ?? this.paymentOrderId,
      amountCents: amountCents ?? this.amountCents,
      currency: currency ?? this.currency,
      platformFeeCents: platformFeeCents ?? this.platformFeeCents,
      coachNetCents: coachNetCents ?? this.coachNetCents,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      activatedAt: activatedAt ?? this.activatedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      createdAt: createdAt ?? this.createdAt,
      nextRenewalAt: nextRenewalAt ?? this.nextRenewalAt,
      pausedAt: pausedAt ?? this.pausedAt,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      coachCity: coachCity ?? this.coachCity,
      trialDays: trialDays ?? this.trialDays,
      renewalPriceEgp: renewalPriceEgp ?? this.renewalPriceEgp,
      responseSlaHours: responseSlaHours ?? this.responseSlaHours,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      weeklyCheckinType: weeklyCheckinType ?? this.weeklyCheckinType,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      locationMode: locationMode ?? this.locationMode,
      threadId: threadId ?? this.threadId,
    );
  }
}

class CoachSubscriptionIntakeEntity {
  const CoachSubscriptionIntakeEntity({
    this.goal,
    this.experienceLevel,
    this.daysPerWeek,
    this.sessionMinutes,
    this.equipment = const <String>[],
    this.limitations = const <String>[],
    this.budgetEgp,
    this.city,
    this.coachingPreference,
    this.trainingPlace,
    this.preferredLanguage,
    this.preferredCoachGender,
  });

  final String? goal;
  final String? experienceLevel;
  final int? daysPerWeek;
  final int? sessionMinutes;
  final List<String> equipment;
  final List<String> limitations;
  final int? budgetEgp;
  final String? city;
  final String? coachingPreference;
  final String? trainingPlace;
  final String? preferredLanguage;
  final String? preferredCoachGender;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'goal': goal,
      'experience_level': experienceLevel,
      'days_per_week': daysPerWeek,
      'session_minutes': sessionMinutes,
      'equipment': equipment,
      'limitations': limitations,
      'budget_egp': budgetEgp,
      'city': city,
      'coaching_preference': coachingPreference,
      'training_place': trainingPlace,
      'preferred_language': preferredLanguage,
      'preferred_coach_gender': preferredCoachGender,
    };
  }

  factory CoachSubscriptionIntakeEntity.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const CoachSubscriptionIntakeEntity();
    }
    return CoachSubscriptionIntakeEntity(
      goal: map['goal'] as String?,
      experienceLevel: map['experience_level'] as String?,
      daysPerWeek: (map['days_per_week'] as num?)?.toInt(),
      sessionMinutes: (map['session_minutes'] as num?)?.toInt(),
      equipment: _stringList(map['equipment']),
      limitations: _stringList(map['limitations']),
      budgetEgp: (map['budget_egp'] as num?)?.toInt(),
      city: map['city'] as String?,
      coachingPreference: map['coaching_preference'] as String?,
      trainingPlace: map['training_place'] as String?,
      preferredLanguage: map['preferred_language'] as String?,
      preferredCoachGender: map['preferred_coach_gender'] as String?,
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((dynamic item) => item.toString()).toList(growable: false);
  }
  return const <String>[];
}
