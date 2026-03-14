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

  List<String> get missingFields {
    final value = metadata['missing_fields'];
    if (value is List) {
      return value
          .map((dynamic item) => item.toString())
          .toList(growable: false);
    }
    return const <String>[];
  }
}
