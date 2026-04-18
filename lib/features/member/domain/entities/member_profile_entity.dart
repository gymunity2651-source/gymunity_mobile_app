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
    this.budgetEgp,
    this.city,
    this.coachingPreference,
    this.trainingPlace,
    this.preferredLanguage,
    this.preferredCoachGender,
  });

  final String userId;
  final String? goal;
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? currentWeightKg;
  final String? trainingFrequency;
  final String? experienceLevel;
  final int? budgetEgp;
  final String? city;
  final String? coachingPreference;
  final String? trainingPlace;
  final String? preferredLanguage;
  final String? preferredCoachGender;

  MemberProfileEntity copyWith({
    String? userId,
    String? goal,
    int? age,
    String? gender,
    double? heightCm,
    double? currentWeightKg,
    String? trainingFrequency,
    String? experienceLevel,
    int? budgetEgp,
    String? city,
    String? coachingPreference,
    String? trainingPlace,
    String? preferredLanguage,
    String? preferredCoachGender,
  }) {
    return MemberProfileEntity(
      userId: userId ?? this.userId,
      goal: goal ?? this.goal,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      trainingFrequency: trainingFrequency ?? this.trainingFrequency,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      budgetEgp: budgetEgp ?? this.budgetEgp,
      city: city ?? this.city,
      coachingPreference: coachingPreference ?? this.coachingPreference,
      trainingPlace: trainingPlace ?? this.trainingPlace,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      preferredCoachGender: preferredCoachGender ?? this.preferredCoachGender,
    );
  }
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
