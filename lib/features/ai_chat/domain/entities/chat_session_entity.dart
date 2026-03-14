enum ChatSessionType { general, planner }

ChatSessionType chatSessionTypeFromString(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'planner':
      return ChatSessionType.planner;
    default:
      return ChatSessionType.general;
  }
}

class ChatSessionEntity {
  const ChatSessionEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.updatedAt,
    this.type = ChatSessionType.general,
    this.plannerStatus = 'idle',
    this.latestDraftId,
    this.plannerProfileJson = const <String, dynamic>{},
  });

  final String id;
  final String userId;
  final String title;
  final DateTime updatedAt;
  final ChatSessionType type;
  final String plannerStatus;
  final String? latestDraftId;
  final Map<String, dynamic> plannerProfileJson;

  bool get isPlanner => type == ChatSessionType.planner;
}
