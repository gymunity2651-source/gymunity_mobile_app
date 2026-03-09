import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_session_entity.dart';

final activeChatSessionIdProvider = StateProvider<String?>((ref) => null);
final pendingChatPromptProvider = StateProvider<String?>((ref) => null);

final chatSessionsProvider = FutureProvider<List<ChatSessionEntity>>((
  ref,
) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.listSessions();
});

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageEntity>, String>((ref, sessionId) {
      final repo = ref.watch(chatRepositoryProvider);
      return repo.watchMessages(sessionId);
    });
