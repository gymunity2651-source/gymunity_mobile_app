import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/supabase/auth_token_project_ref.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_session_entity.dart';
import '../../domain/entities/planner_turn_result.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._client);

  final SupabaseClient _client;
  static const Duration _tokenRefreshMargin = Duration(minutes: 1);

  @override
  Future<List<ChatSessionEntity>> listSessions() async {
    final user = _client.auth.currentUser;
    if (user == null) return <ChatSessionEntity>[];

    try {
      final rows = await _client
          .from('chat_sessions')
          .select(
            'id,user_id,title,updated_at,session_type,planner_status,latest_draft_id,planner_profile_json',
          )
          .eq('user_id', user.id)
          .order('updated_at', ascending: false);

      return (rows as List<dynamic>)
          .map((dynamic row) {
            final map = _rowMap(row);
            return ChatSessionEntity(
              id: map['id'] as String? ?? '',
              userId: map['user_id'] as String? ?? '',
              title: map['title'] as String? ?? 'New chat',
              updatedAt:
                  DateTime.tryParse(map['updated_at'] as String? ?? '') ??
                  DateTime.now(),
              type: chatSessionTypeFromString(map['session_type'] as String?),
              plannerStatus: map['planner_status'] as String? ?? 'idle',
              latestDraftId: map['latest_draft_id'] as String?,
              plannerProfileJson: _rowMap(map['planner_profile_json']),
            );
          })
          .toList(growable: false);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw NetworkFailure(
        message: 'Unable to load AI chat sessions.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<ChatSessionEntity> createSession({
    String? title,
    ChatSessionType type = ChatSessionType.general,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated user found.');
    }

    try {
      final row = await _client
          .from('chat_sessions')
          .insert(<String, dynamic>{
            'user_id': user.id,
            'title':
                title ??
                (type == ChatSessionType.planner ? 'AI Plan' : 'New chat'),
            'session_type': type.name,
            'planner_status': type == ChatSessionType.planner
                ? 'collecting_info'
                : 'idle',
          })
          .select(
            'id,user_id,title,updated_at,session_type,planner_status,latest_draft_id,planner_profile_json',
          )
          .single();

      return ChatSessionEntity(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        title: row['title'] as String? ?? 'New chat',
        updatedAt:
            DateTime.tryParse(row['updated_at'] as String? ?? '') ??
            DateTime.now(),
        type: chatSessionTypeFromString(row['session_type'] as String?),
        plannerStatus: row['planner_status'] as String? ?? 'idle',
        latestDraftId: row['latest_draft_id'] as String?,
        plannerProfileJson: _rowMap(row['planner_profile_json']),
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Stream<List<ChatMessageEntity>> watchMessages(String sessionId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: <String>['id'])
        .eq('session_id', sessionId)
        .order('created_at')
        .map(
          (rows) => rows
              .map((dynamic row) {
                final map = _rowMap(row);
                return ChatMessageEntity(
                  id: map['id'] as String? ?? '',
                  sessionId: map['session_id'] as String? ?? '',
                  sender: map['sender'] as String? ?? 'assistant',
                  content: map['content'] as String? ?? '',
                  createdAt:
                      DateTime.tryParse(map['created_at'] as String? ?? '') ??
                      DateTime.now(),
                  metadata: _rowMap(map['metadata']),
                );
              })
              .toList(growable: false),
        );
  }

  @override
  Future<PlannerTurnResult> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated user found.');
    }

    try {
      await _ensureSessionReady();
      final userMessageRow = await _client
          .from('chat_messages')
          .insert(<String, dynamic>{
            'session_id': sessionId,
            'sender': 'user',
            'content': message,
          })
          .select('id')
          .single();

      return await _invokeAiChat(
        body: <String, dynamic>{
          'session_id': sessionId,
          'message_id': userMessageRow['id'],
          'action': 'reply',
        },
      );
    } on FunctionException catch (e, st) {
      throw _mapFunctionException(
        e,
        st,
        fallbackMessage: 'Unable to reach the AI assistant.',
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is AppFailure) {
        rethrow;
      }
      throw NetworkFailure(
        message: 'Unable to reach the AI assistant right now.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<PlannerTurnResult> regeneratePlan({
    required String sessionId,
    required String draftId,
  }) async {
    try {
      await _ensureSessionReady();
      return await _invokeAiChat(
        body: <String, dynamic>{
          'session_id': sessionId,
          'draft_id': draftId,
          'action': 'regenerate_plan',
        },
      );
    } on FunctionException catch (e, st) {
      throw _mapFunctionException(
        e,
        st,
        fallbackMessage: 'Unable to regenerate this AI plan.',
      );
    } catch (e, st) {
      if (e is AppFailure) {
        rethrow;
      }
      throw NetworkFailure(
        message: 'Unable to regenerate this AI plan right now.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  PlannerTurnResult _mapTurnResult(dynamic value) {
    if (value is Map<String, dynamic>) {
      return PlannerTurnResult.fromMap(value);
    }
    if (value is Map) {
      return PlannerTurnResult.fromMap(
        value.map(
          (dynamic key, dynamic rowValue) => MapEntry(key.toString(), rowValue),
        ),
      );
    }
    return const PlannerTurnResult(
      assistantMessage: 'I could not generate a response right now.',
      status: 'error',
    );
  }

  Future<PlannerTurnResult> _invokeAiChat({
    required Map<String, dynamic> body,
    bool retryOnUnauthorized = true,
  }) async {
    final accessToken = await _ensureSessionReady(
      forceRefresh: !retryOnUnauthorized,
    );
    try {
      final functionResponse = await _client.functions.invoke(
        'ai-chat',
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        body: body,
      );
      return _mapTurnResult(functionResponse.data);
    } on FunctionException catch (e, st) {
      if (retryOnUnauthorized && e.status == 401) {
        try {
          await _ensureSessionReady(forceRefresh: true);
        } catch (_) {
          // Fall through to the clearer error mapping below.
        }
        return _invokeAiChat(body: body, retryOnUnauthorized: false);
      }
      if (_isInvalidJwtError(e)) {
        await _clearLocalSession();
      }
      throw _mapFunctionException(
        e,
        st,
        fallbackMessage: 'Unable to reach the AI assistant.',
      );
    }
  }

  Future<String> _ensureSessionReady({bool forceRefresh = false}) async {
    Session? session = _client.auth.currentSession;
    if (session == null) {
      throw const AuthFailure(
        message: 'Please sign in again to use GymUnity AI.',
      );
    }

    if (_tokenBelongsToDifferentProject(session.accessToken)) {
      await _clearLocalSession();
      throw const AuthFailure(
        message:
            'Your saved GymUnity session belongs to a different backend. Please sign in again.',
      );
    }

    final expiresAt = session.expiresAt;
    final shouldRefresh =
        forceRefresh ||
        (expiresAt != null &&
            DateTime.now().isAfter(
              DateTime.fromMillisecondsSinceEpoch(
                expiresAt * 1000,
              ).subtract(_tokenRefreshMargin),
            ));

    if (shouldRefresh) {
      try {
        final refreshed = await _client.auth.refreshSession();
        session = refreshed.session ?? _client.auth.currentSession;
      } on AuthException catch (e, st) {
        throw AuthFailure(
          message: 'Please sign in again to use GymUnity AI.',
          cause: e,
          stackTrace: st,
        );
      }
    }

    final accessToken = session?.accessToken.trim() ?? '';
    if (accessToken.isEmpty) {
      throw const AuthFailure(
        message: 'Please sign in again to use GymUnity AI.',
      );
    }
    if (_tokenBelongsToDifferentProject(accessToken)) {
      await _clearLocalSession();
      throw const AuthFailure(
        message:
            'Your saved GymUnity session belongs to a different backend. Please sign in again.',
      );
    }
    return accessToken;
  }

  bool _tokenBelongsToDifferentProject(String token) {
    return !AuthTokenProjectRef.matchesProject(
      token,
      AppConfig.current.supabaseUrl,
    );
  }

  bool _isInvalidJwtError(FunctionException error) {
    if (error.status != 401) {
      return false;
    }
    final details = _rowMap(error.details);
    final detailMessage =
        details['message']?.toString() ??
        details['error']?.toString() ??
        error.details?.toString() ??
        '';
    return detailMessage.toLowerCase().contains('invalid jwt');
  }

  Future<void> _clearLocalSession() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Clearing a stale local session should not block user-facing recovery.
    }
  }

  AppFailure _mapFunctionException(
    FunctionException error,
    StackTrace stackTrace, {
    required String fallbackMessage,
  }) {
    final details = _rowMap(error.details);
    final detailCode = details['code']?.toString();
    final detailMessage =
        details['message']?.toString() ??
        details['error']?.toString() ??
        error.details?.toString() ??
        fallbackMessage;

    if (error.status == 401 &&
        detailMessage.toLowerCase().contains('invalid jwt')) {
      return AuthFailure(
        code: detailCode ?? error.status.toString(),
        message:
            'Your GymUnity session is no longer valid, or the ai-chat Edge Function is linked to a different Supabase project. Sign out and sign in again. If it still fails, redeploy ai-chat on the same Supabase project as the app.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error.status == 401) {
      return AuthFailure(
        code: detailCode ?? error.status.toString(),
        message: detailMessage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return NetworkFailure(
      code: detailCode ?? error.status.toString(),
      message: detailMessage,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  Map<String, dynamic> _rowMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic rowValue) => MapEntry(key.toString(), rowValue),
      );
    }
    return const <String, dynamic>{};
  }
}
