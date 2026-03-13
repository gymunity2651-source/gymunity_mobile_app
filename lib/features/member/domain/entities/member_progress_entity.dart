class WeightEntryEntity {
  const WeightEntryEntity({
    required this.id,
    required this.memberId,
    required this.weightKg,
    required this.recordedAt,
    this.note,
  });

  final String id;
  final String memberId;
  final double weightKg;
  final DateTime recordedAt;
  final String? note;
}

class BodyMeasurementEntity {
  const BodyMeasurementEntity({
    required this.id,
    required this.memberId,
    required this.recordedAt,
    this.waistCm,
    this.chestCm,
    this.hipsCm,
    this.armCm,
    this.thighCm,
    this.bodyFatPercent,
    this.note,
  });

  final String id;
  final String memberId;
  final DateTime recordedAt;
  final double? waistCm;
  final double? chestCm;
  final double? hipsCm;
  final double? armCm;
  final double? thighCm;
  final double? bodyFatPercent;
  final String? note;
}

class WorkoutSessionEntity {
  const WorkoutSessionEntity({
    required this.id,
    required this.memberId,
    required this.title,
    required this.performedAt,
    required this.durationMinutes,
    this.workoutPlanId,
    this.coachId,
    this.note,
  });

  final String id;
  final String memberId;
  final String title;
  final DateTime performedAt;
  final int durationMinutes;
  final String? workoutPlanId;
  final String? coachId;
  final String? note;
}
