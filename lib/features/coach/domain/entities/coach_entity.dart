class CoachEntity {
  const CoachEntity({
    required this.id,
    required this.name,
    this.avatarPath,
    this.bio = '',
    this.specialties = const <String>[],
    this.yearsExperience = 0,
    this.hourlyRate = 0,
    this.pricingCurrency = 'USD',
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.isVerified = false,
    this.city,
    this.languages = const <String>[],
    this.coachGender,
    this.verificationStatus = 'unverified',
    this.responseSlaHours = 12,
    this.trialOfferEnabled = false,
    this.trialPriceEgp = 0,
    this.activeClientCount = 0,
    this.remoteOnly = false,
    this.limitedSpots = false,
    this.testimonials = const <CoachTestimonialEntity>[],
    this.resultMedia = const <CoachResultMediaEntity>[],
    this.deliveryMode,
    this.serviceSummary = '',
    this.startingPackagePrice,
    this.startingPackageBillingCycle,
    this.activePackageCount = 0,
    this.packages = const <CoachPackageEntity>[],
    this.availability = const <CoachAvailabilitySlotEntity>[],
    this.reviews = const <CoachReviewEntity>[],
  });

  final String id;
  final String name;
  final String? avatarPath;
  final String bio;
  final List<String> specialties;
  final int yearsExperience;
  final double hourlyRate;
  final String pricingCurrency;
  final double ratingAvg;
  final int ratingCount;
  final bool isVerified;
  final String? city;
  final List<String> languages;
  final String? coachGender;
  final String verificationStatus;
  final int responseSlaHours;
  final bool trialOfferEnabled;
  final double trialPriceEgp;
  final int activeClientCount;
  final bool remoteOnly;
  final bool limitedSpots;
  final List<CoachTestimonialEntity> testimonials;
  final List<CoachResultMediaEntity> resultMedia;
  final String? deliveryMode;
  final String serviceSummary;
  final double? startingPackagePrice;
  final String? startingPackageBillingCycle;
  final int activePackageCount;
  final List<CoachPackageEntity> packages;
  final List<CoachAvailabilitySlotEntity> availability;
  final List<CoachReviewEntity> reviews;

  String get specialty =>
      specialties.isEmpty ? 'FITNESS' : specialties.join(' & ').toUpperCase();

  String get rateLabel {
    if (hourlyRate <= 0) {
      return 'Contact for pricing';
    }
    final symbol = pricingCurrency.trim().toUpperCase() == 'USD'
        ? '\$'
        : '${pricingCurrency.trim().toUpperCase()} ';
    final normalized = hourlyRate == hourlyRate.roundToDouble()
        ? hourlyRate.toStringAsFixed(0)
        : hourlyRate.toStringAsFixed(2);
    return '$symbol$normalized/hr';
  }

  String get rating => ratingAvg.toStringAsFixed(1);

  String get reviewsLabel =>
      ratingCount == 0 ? 'No reviews yet' : '$ratingCount Reviews';

  String get badge => isVerified ? 'Verified Coach' : 'Coach';

  String get verificationBadge {
    if (verificationStatus == 'verified' || isVerified) {
      return 'Verified Coach';
    }
    if (verificationStatus == 'pending') {
      return 'Verification Pending';
    }
    return 'Coach';
  }

  String get responseSlaLabel => responseSlaHours <= 1
      ? 'Replies in about 1 hour'
      : 'Replies in about $responseSlaHours hours';

  String get locationLabel {
    if (remoteOnly) {
      return city?.trim().isNotEmpty == true
          ? 'Online from ${city!.trim()}'
          : 'Online coaching';
    }
    if (city?.trim().isNotEmpty == true) {
      return '${city!.trim()} • ${deliveryMode?.replaceAll('_', ' ') ?? 'flexible'}';
    }
    return deliveryMode?.replaceAll('_', ' ') ?? 'Flexible coaching';
  }

  String get trialLabel {
    if (!trialOfferEnabled || trialPriceEgp <= 0) {
      return 'No paid trial';
    }
    final normalized = trialPriceEgp == trialPriceEgp.roundToDouble()
        ? trialPriceEgp.toStringAsFixed(0)
        : trialPriceEgp.toStringAsFixed(2);
    return '7-day trial from EGP $normalized';
  }

  String get discoveryPriceLabel {
    if (startingPackagePrice != null && startingPackagePrice! > 0) {
      final normalizedCurrency = pricingCurrency.trim().toUpperCase();
      final symbol = switch (normalizedCurrency) {
        'USD' => '\$',
        'EGP' => 'EGP ',
        _ => normalizedCurrency.isEmpty ? '\$' : '$normalizedCurrency ',
      };
      final normalized =
          startingPackagePrice! == startingPackagePrice!.roundToDouble()
          ? startingPackagePrice!.toStringAsFixed(0)
          : startingPackagePrice!.toStringAsFixed(2);
      final cycle = startingPackageBillingCycle?.trim().isNotEmpty == true
          ? '/${startingPackageBillingCycle!.replaceAll('_', ' ')}'
          : '';
      return '$symbol$normalized$cycle';
    }
    return rateLabel;
  }
}

class CoachPackageEntity {
  const CoachPackageEntity({
    required this.id,
    required this.coachId,
    required this.title,
    required this.description,
    required this.billingCycle,
    required this.price,
    this.subtitle = '',
    this.outcomeSummary = '',
    this.idealFor = const <String>[],
    this.durationWeeks = 4,
    this.sessionsPerWeek = 3,
    this.difficultyLevel = 'beginner',
    this.equipmentTags = const <String>[],
    this.includedFeatures = const <String>[],
    this.checkInFrequency = '',
    this.supportSummary = '',
    this.faqItems = const <CoachPackageFaqEntity>[],
    this.planPreviewJson = const <String, dynamic>{},
    this.visibilityStatus = 'published',
    this.isActive = true,
    this.createdAt,
    this.targetGoalTags = const <String>[],
    this.locationMode = 'online',
    this.deliveryMode = 'chat',
    this.weeklyCheckinType = 'form',
    this.trialDays = 7,
    this.depositAmountEgp = 0,
    this.renewalPriceEgp = 0,
    this.maxSlots = 100,
    this.pauseAllowed = true,
    this.paymentRails = const <String>[],
  });

  final String id;
  final String coachId;
  final String title;
  final String description;
  final String billingCycle;
  final double price;
  final String subtitle;
  final String outcomeSummary;
  final List<String> idealFor;
  final int durationWeeks;
  final int sessionsPerWeek;
  final String difficultyLevel;
  final List<String> equipmentTags;
  final List<String> includedFeatures;
  final String checkInFrequency;
  final String supportSummary;
  final List<CoachPackageFaqEntity> faqItems;
  final Map<String, dynamic> planPreviewJson;
  final String visibilityStatus;
  final bool isActive;
  final DateTime? createdAt;
  final List<String> targetGoalTags;
  final String locationMode;
  final String deliveryMode;
  final String weeklyCheckinType;
  final int trialDays;
  final double depositAmountEgp;
  final double renewalPriceEgp;
  final int maxSlots;
  final bool pauseAllowed;
  final List<String> paymentRails;

  bool get hasPlanPreview => planPreviewJson.isNotEmpty;

  bool get isPublished => visibilityStatus == 'published';

  bool get isDraft => visibilityStatus == 'draft';

  bool get isArchived => visibilityStatus == 'archived';

  String get checkoutPriceLabel {
    final value = depositAmountEgp > 0 ? depositAmountEgp : price;
    final normalized = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return 'EGP $normalized';
  }
}

class CoachPackageFaqEntity {
  const CoachPackageFaqEntity({required this.question, required this.answer});

  final String question;
  final String answer;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'question': question, 'answer': answer};
  }

  factory CoachPackageFaqEntity.fromMap(Map<String, dynamic> map) {
    return CoachPackageFaqEntity(
      question: map['question'] as String? ?? '',
      answer: map['answer'] as String? ?? '',
    );
  }
}

class CoachAvailabilitySlotEntity {
  const CoachAvailabilitySlotEntity({
    required this.id,
    required this.coachId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    this.timezone = 'UTC',
    this.isActive = true,
  });

  final String id;
  final String coachId;
  final int weekday;
  final String startTime;
  final String endTime;
  final String timezone;
  final bool isActive;

  String get weekdayLabel {
    const labels = <String>[
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    if (weekday < 0 || weekday >= labels.length) {
      return 'Unknown day';
    }
    return labels[weekday];
  }
}

class CoachReviewEntity {
  const CoachReviewEntity({
    required this.id,
    required this.memberDisplayName,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
  });

  final String id;
  final String memberDisplayName;
  final int rating;
  final String reviewText;
  final DateTime createdAt;
}

class CoachTestimonialEntity {
  const CoachTestimonialEntity({
    required this.quote,
    this.memberName,
    this.goal,
  });

  final String quote;
  final String? memberName;
  final String? goal;

  factory CoachTestimonialEntity.fromMap(Map<String, dynamic> map) {
    return CoachTestimonialEntity(
      quote: map['quote'] as String? ?? '',
      memberName: map['member_name'] as String?,
      goal: map['goal'] as String?,
    );
  }
}

class CoachResultMediaEntity {
  const CoachResultMediaEntity({
    required this.storagePath,
    this.caption,
    this.mediaType = 'image',
  });

  final String storagePath;
  final String? caption;
  final String mediaType;

  factory CoachResultMediaEntity.fromMap(Map<String, dynamic> map) {
    return CoachResultMediaEntity(
      storagePath: map['storage_path'] as String? ?? '',
      caption: map['caption'] as String?,
      mediaType: map['media_type'] as String? ?? 'image',
    );
  }
}

class CoachClientEntity {
  const CoachClientEntity({
    required this.subscriptionId,
    required this.memberId,
    required this.memberName,
    required this.packageTitle,
    required this.status,
    required this.startedAt,
    required this.activePlanCount,
    this.lastSessionAt,
  });

  final String subscriptionId;
  final String memberId;
  final String memberName;
  final String packageTitle;
  final String status;
  final DateTime startedAt;
  final int activePlanCount;
  final DateTime? lastSessionAt;
}

class CoachDashboardSummaryEntity {
  const CoachDashboardSummaryEntity({
    required this.activeClients,
    required this.pendingRequests,
    required this.activePackages,
    required this.activePlans,
    required this.ratingAvg,
    required this.ratingCount,
  });

  final int activeClients;
  final int pendingRequests;
  final int activePackages;
  final int activePlans;
  final double ratingAvg;
  final int ratingCount;
}
