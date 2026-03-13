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
    this.deliveryMode,
    this.serviceSummary = '',
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
  final String? deliveryMode;
  final String serviceSummary;
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
}

class CoachPackageEntity {
  const CoachPackageEntity({
    required this.id,
    required this.coachId,
    required this.title,
    required this.description,
    required this.billingCycle,
    required this.price,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String coachId;
  final String title;
  final String description;
  final String billingCycle;
  final double price;
  final bool isActive;
  final DateTime? createdAt;
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
