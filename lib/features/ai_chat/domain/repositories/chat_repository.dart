import '../entities/chat_message_entity.dart';
import '../entities/chat_session_entity.dart';
import '../entities/planner_turn_result.dart';

abstract class ChatRepository {
  Future<List<ChatSessionEntity>> listSessions();

  Future<ChatSessionEntity> createSession({
    String? title,
    ChatSessionType type = ChatSessionType.general,
  });

  Stream<List<ChatMessageEntity>> watchMessages(String sessionId);

  Future<PlannerTurnResult> sendMessage({
    required String sessionId,
    required String message,
  });

  Future<PlannerTurnResult> regeneratePlan({
    required String sessionId,
    required String draftId,
  });
}
