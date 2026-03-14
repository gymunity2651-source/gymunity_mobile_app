import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/chat_session_entity.dart';
import '../../domain/entities/planner_turn_result.dart';
import 'chat_providers.dart';

class ChatControllerState {
  const ChatControllerState({
    this.isSending = false,
    this.isRegenerating = false,
    this.errorMessage,
    this.lastTurn,
  });

  final bool isSending;
  final bool isRegenerating;
  final String? errorMessage;
  final PlannerTurnResult? lastTurn;

  ChatControllerState copyWith({
    bool? isSending,
    bool? isRegenerating,
    String? errorMessage,
    PlannerTurnResult? lastTurn,
    bool clearError = false,
  }) {
    return ChatControllerState(
      isSending: isSending ?? this.isSending,
      isRegenerating: isRegenerating ?? this.isRegenerating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastTurn: lastTurn ?? this.lastTurn,
    );
  }
}

class ChatController extends StateNotifier<ChatControllerState> {
  ChatController(this._ref) : super(const ChatControllerState());

  final Ref _ref;

  Future<String> createSessionIfNeeded(
    String? sessionId, {
    ChatSessionType type = ChatSessionType.general,
  }) async {
    if (sessionId != null && sessionId.isNotEmpty) return sessionId;
    final repo = _ref.read(chatRepositoryProvider);
    final session = await repo.createSession(type: type);
    _ref.invalidate(chatSessionsProvider);
    return session.id;
  }

  Future<PlannerTurnResult?> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    state = state.copyWith(isSending: true, clearError: true);
    try {
      final repo = _ref.read(chatRepositoryProvider);
      final result = await repo.sendMessage(
        sessionId: sessionId,
        message: message,
      );
      _ref.invalidate(chatSessionsProvider);
      state = state.copyWith(
        isSending: false,
        clearError: true,
        lastTurn: result,
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        errorMessage: _messageForError(e),
      );
      return null;
    }
  }

  Future<PlannerTurnResult?> regeneratePlan({
    required String sessionId,
    required String draftId,
  }) async {
    state = state.copyWith(isRegenerating: true, clearError: true);
    try {
      final repo = _ref.read(chatRepositoryProvider);
      final result = await repo.regeneratePlan(
        sessionId: sessionId,
        draftId: draftId,
      );
      _ref.invalidate(chatSessionsProvider);
      state = state.copyWith(
        isRegenerating: false,
        clearError: true,
        lastTurn: result,
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        isRegenerating: false,
        errorMessage: _messageForError(e),
      );
      return null;
    }
  }

  String _messageForError(Object error) {
    if (error is AppFailure) {
      return error.message;
    }
    return error.toString();
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatControllerState>((ref) {
      return ChatController(ref);
    });
