class ChatMessageEntity {
  const ChatMessageEntity({
    required this.id,
    required this.sessionId,
    required this.sender,
    required this.content,
    required this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String sessionId;
  final String sender;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  bool get isPlannerMessage => metadata.isNotEmpty;

  String? get plannerStatus => metadata['planner_status'] as String?;

  String? get draftId => metadata['draft_id'] as String?;

  String? get replyToMessageId => metadata['reply_to_message_id'] as String?;

  String? get conversationMode => metadata['conversation_mode'] as String?;

  List<String> get missingFields {
    final value = metadata['missing_fields'];
    if (value is List) {
      return value
          .map((dynamic item) => item.toString())
          .toList(growable: false);
    }
    return const <String>[];
  }

  List<String> get personalizationUsed {
    final value = metadata['personalization_used'];
    if (value is List) {
      return value
          .map((dynamic item) => item.toString())
          .toList(growable: false);
    }
    return const <String>[];
  }

  List<String> get suggestedReplies {
    final value = metadata['suggested_replies'];
    if (value is List) {
      return value
          .map((dynamic item) => item.toString())
          .where((String item) => item.trim().isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}

List<ChatMessageEntity> sortChatMessages(Iterable<ChatMessageEntity> messages) {
  final indexedMessages = messages.indexed
      .map((entry) => (index: entry.$1, message: entry.$2))
      .toList(growable: false);
  indexedMessages.sort((a, b) => _compareChatMessages(a, b));
  return indexedMessages.map((entry) => entry.message).toList(growable: false);
}

int _compareChatMessages(
  ({int index, ChatMessageEntity message}) a,
  ({int index, ChatMessageEntity message}) b,
) {
  final createdAtComparison = a.message.createdAt.compareTo(
    b.message.createdAt,
  );
  if (createdAtComparison != 0) {
    return createdAtComparison;
  }
  if (a.message.id == b.message.replyToMessageId) {
    return -1;
  }
  if (b.message.id == a.message.replyToMessageId) {
    return 1;
  }
  final senderPriorityComparison = _senderPriority(
    a.message.sender,
  ).compareTo(_senderPriority(b.message.sender));
  if (senderPriorityComparison != 0) {
    return senderPriorityComparison;
  }
  return a.index.compareTo(b.index);
}

int _senderPriority(String sender) {
  switch (sender) {
    case 'user':
      return 0;
    case 'assistant':
      return 1;
    default:
      return 2;
  }
}
