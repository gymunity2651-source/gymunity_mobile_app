class CoachingThreadEntity {
  const CoachingThreadEntity({
    required this.id,
    required this.subscriptionId,
    required this.memberId,
    required this.coachId,
    this.coachName,
    this.packageTitle,
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
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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
  final List<ProgressPhotoEntity> photos;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
