class CoachingThreadEntity {
  const CoachingThreadEntity({
    required this.id,
    required this.subscriptionId,
    required this.memberId,
    required this.coachId,
    this.coachName,
    this.packageTitle,
    this.subscriptionStatus = 'active',
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String subscriptionId;
  final String memberId;
  final String coachId;
  final String? coachName;
  final String? packageTitle;
  final String subscriptionStatus;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CoachingThreadEntity.fromMap(Map<String, dynamic> map) {
    return CoachingThreadEntity(
      id: map['id'] as String? ?? '',
      subscriptionId: map['subscription_id'] as String? ?? '',
      memberId: map['member_id'] as String? ?? '',
      coachId: map['coach_id'] as String? ?? '',
      coachName: map['coach_name'] as String?,
      packageTitle: map['package_title'] as String?,
      subscriptionStatus: map['subscription_status'] as String? ?? 'active',
      lastMessagePreview: map['last_message_preview'] as String? ?? '',
      lastMessageAt: _parseDate(map['last_message_at']),
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }
}

class CoachingMessageEntity {
  const CoachingMessageEntity({
    required this.id,
    required this.threadId,
    required this.senderUserId,
    required this.senderRole,
    required this.content,
    required this.createdAt,
    this.messageType = 'text',
  });

  final String id;
  final String threadId;
  final String senderUserId;
  final String senderRole;
  final String messageType;
  final String content;
  final DateTime createdAt;

  bool get isSystem => senderRole == 'system' || messageType == 'system';

  bool get isCoach => senderRole == 'coach';

  factory CoachingMessageEntity.fromMap(Map<String, dynamic> map) {
    return CoachingMessageEntity(
      id: map['id'] as String? ?? '',
      threadId: map['thread_id'] as String? ?? '',
      senderUserId: map['sender_user_id'] as String? ?? '',
      senderRole: map['sender_role'] as String? ?? 'system',
      content: map['content'] as String? ?? '',
      createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      messageType: map['message_type'] as String? ?? 'text',
    );
  }
}

class ProgressPhotoEntity {
  const ProgressPhotoEntity({
    required this.id,
    required this.storagePath,
    this.angle = 'front',
    this.createdAt,
  });

  final String id;
  final String storagePath;
  final String angle;
  final DateTime? createdAt;

  factory ProgressPhotoEntity.fromMap(Map<String, dynamic> map) {
    return ProgressPhotoEntity(
      id: map['id'] as String? ?? '',
      storagePath: map['storage_path'] as String? ?? '',
      angle: map['angle'] as String? ?? 'front',
      createdAt: _parseDate(map['created_at']),
    );
  }
}

class WeeklyCheckinEntity {
  const WeeklyCheckinEntity({
    required this.id,
    required this.subscriptionId,
    required this.memberId,
    required this.coachId,
    required this.weekStart,
    this.threadId,
    this.weightKg,
    this.waistCm,
    this.adherenceScore = 0,
    this.energyScore,
    this.sleepScore,
    this.wins,
    this.blockers,
    this.questions,
    this.coachReply,
    this.workoutsCompleted,
    this.missedWorkouts,
    this.missedWorkoutsReason,
    this.sorenessScore,
    this.fatigueScore,
    this.painWarning,
    this.nutritionAdherenceScore,
    this.habitAdherenceScore,
    this.biggestObstacle,
    this.supportNeeded,
    this.checkinMetadata = const <String, dynamic>{},
    this.coachFeedback = const <String, dynamic>{},
    this.coachFeedbackAt,
    this.nextCheckinDate,
    this.photos = const <ProgressPhotoEntity>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String subscriptionId;
  final String? threadId;
  final String memberId;
  final String coachId;
  final DateTime weekStart;
  final double? weightKg;
  final double? waistCm;
  final int adherenceScore;
  final int? energyScore;
  final int? sleepScore;
  final String? wins;
  final String? blockers;
  final String? questions;
  final String? coachReply;
  final int? workoutsCompleted;
  final int? missedWorkouts;
  final String? missedWorkoutsReason;
  final int? sorenessScore;
  final int? fatigueScore;
  final String? painWarning;
  final int? nutritionAdherenceScore;
  final int? habitAdherenceScore;
  final String? biggestObstacle;
  final String? supportNeeded;
  final Map<String, dynamic> checkinMetadata;
  final Map<String, dynamic> coachFeedback;
  final DateTime? coachFeedbackAt;
  final DateTime? nextCheckinDate;
  final List<ProgressPhotoEntity> photos;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get onePriority =>
      coachFeedback['one_priority'] as String? ?? coachReply ?? '';

  factory WeeklyCheckinEntity.fromMap(Map<String, dynamic> map) {
    final photos = map['progress_photos'] is List
        ? (map['progress_photos'] as List)
              .whereType<Map>()
              .map(
                (item) => ProgressPhotoEntity.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <ProgressPhotoEntity>[];
    return WeeklyCheckinEntity(
      id: map['id'] as String? ?? '',
      subscriptionId: map['subscription_id'] as String? ?? '',
      memberId: map['member_id'] as String? ?? '',
      coachId: map['coach_id'] as String? ?? '',
      weekStart: _parseDate(map['week_start']) ?? DateTime.now(),
      threadId: map['thread_id'] as String?,
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      waistCm: (map['waist_cm'] as num?)?.toDouble(),
      adherenceScore: (map['adherence_score'] as num?)?.toInt() ?? 0,
      energyScore: (map['energy_score'] as num?)?.toInt(),
      sleepScore: (map['sleep_score'] as num?)?.toInt(),
      wins: map['wins'] as String?,
      blockers: map['blockers'] as String?,
      questions: map['questions'] as String?,
      coachReply: map['coach_reply'] as String?,
      workoutsCompleted: (map['workouts_completed'] as num?)?.toInt(),
      missedWorkouts: (map['missed_workouts'] as num?)?.toInt(),
      missedWorkoutsReason: map['missed_workouts_reason'] as String?,
      sorenessScore: (map['soreness_score'] as num?)?.toInt(),
      fatigueScore: (map['fatigue_score'] as num?)?.toInt(),
      painWarning: map['pain_warning'] as String?,
      nutritionAdherenceScore: (map['nutrition_adherence_score'] as num?)
          ?.toInt(),
      habitAdherenceScore: (map['habit_adherence_score'] as num?)?.toInt(),
      biggestObstacle: map['biggest_obstacle'] as String?,
      supportNeeded: map['support_needed'] as String?,
      checkinMetadata: _map(map['checkin_metadata_json']),
      coachFeedback: _map(map['coach_feedback_json']),
      coachFeedbackAt: _parseDate(map['coach_feedback_at']),
      nextCheckinDate: _parseDate(map['next_checkin_date']),
      photos: photos,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}
