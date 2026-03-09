import '../entities/chat_message_entity.dart';
import '../entities/chat_session_entity.dart';

abstract class ChatRepository {
  Future<List<ChatSessionEntity>> listSessions();

  Future<ChatSessionEntity> createSession({
    String? title,
  });

  Stream<List<ChatMessageEntity>> watchMessages(String sessionId);

  Future<ChatMessageEntity> sendMessage({
    required String sessionId,
    required String message,
  });
}

