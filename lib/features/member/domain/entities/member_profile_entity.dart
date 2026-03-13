class MemberProfileEntity {
  const MemberProfileEntity({
    required this.userId,
    this.goal,
    this.age,
    this.gender,
    this.heightCm,
    this.currentWeightKg,
    this.trainingFrequency,
    this.experienceLevel,
  });

  final String userId;
  final String? goal;
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? currentWeightKg;
  final String? trainingFrequency;
  final String? experienceLevel;
}

class UserPreferencesEntity {
  const UserPreferencesEntity({
    this.pushNotificationsEnabled = true,
    this.aiTipsEnabled = true,
    this.orderUpdatesEnabled = true,
    this.measurementUnit = 'metric',
    this.language = 'english',
  });

  final bool pushNotificationsEnabled;
  final bool aiTipsEnabled;
  final bool orderUpdatesEnabled;
  final String measurementUnit;
  final String language;
}
