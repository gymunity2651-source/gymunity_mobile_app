import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import 'chat_providers.dart';

class ChatControllerState {
  const ChatControllerState({
    this.isSending = false,
    this.errorMessage,
  });

  final bool isSending;
  final String? errorMessage;

  ChatControllerState copyWith({
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatControllerState(
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ChatController extends StateNotifier<ChatControllerState> {
  ChatController(this._ref) : super(const ChatControllerState());

  final Ref _ref;

  Future<String> createSessionIfNeeded(String? sessionId) async {
    if (sessionId != null && sessionId.isNotEmpty) return sessionId;
    final repo = _ref.read(chatRepositoryProvider);
    final session = await repo.createSession();
    _ref.invalidate(chatSessionsProvider);
    return session.id;
  }

  Future<bool> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final repo = _ref.read(chatRepositoryProvider);
      await repo.sendMessage(sessionId: sessionId, message: message);
      _ref.invalidate(chatSessionsProvider);
      state = state.copyWith(isSending: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatControllerState>((ref) {
  return ChatController(ref);
});
