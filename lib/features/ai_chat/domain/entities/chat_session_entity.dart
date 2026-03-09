class ChatSessionEntity {
  const ChatSessionEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final DateTime updatedAt;
}

