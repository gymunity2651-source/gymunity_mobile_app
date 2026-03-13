class ChatMessageEntity {
  const ChatMessageEntity({
    required this.id,
    required this.sessionId,
    required this.sender,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String sender;
  final String content;
  final DateTime createdAt;
}
