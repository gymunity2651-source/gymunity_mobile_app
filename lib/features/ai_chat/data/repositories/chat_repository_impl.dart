import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_session_entity.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ChatSessionEntity>> listSessions() async {
    final user = _client.auth.currentUser;
    if (user == null) return <ChatSessionEntity>[];

    try {
      final rows = await _client
          .from('chat_sessions')
          .select('id,user_id,title,updated_at')
          .eq('user_id', user.id)
          .order('updated_at', ascending: false);

      return (rows as List<dynamic>).map((dynamic row) {
        final map = row as Map<String, dynamic>;
        return ChatSessionEntity(
          id: map['id'] as String,
          userId: map['user_id'] as String,
          title: map['title'] as String? ?? 'New chat',
          updatedAt:
              DateTime.tryParse(map['updated_at'] as String? ?? '') ??
              DateTime.now(),
        );
      }).toList();
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
  Future<ChatSessionEntity> createSession({String? title}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated user found.');
    }

    final row = await _client
        .from('chat_sessions')
        .insert(<String, dynamic>{
          'user_id': user.id,
          'title': title ?? 'New chat',
        })
        .select('id,user_id,title,updated_at')
        .single();

    return ChatSessionEntity(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String? ?? 'New chat',
      updatedAt:
          DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  Stream<List<ChatMessageEntity>> watchMessages(String sessionId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: <String>['id'])
        .eq('session_id', sessionId)
        .order('created_at')
        .map(
          (rows) => rows.map((row) {
            final map = row;
            return ChatMessageEntity(
              id: map['id'] as String,
              sessionId: map['session_id'] as String,
              sender: map['sender'] as String? ?? 'assistant',
              content: map['content'] as String? ?? '',
              createdAt:
                  DateTime.tryParse(map['created_at'] as String? ?? '') ??
                  DateTime.now(),
            );
          }).toList(),
        );
  }

  @override
  Future<ChatMessageEntity> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated user found.');
    }

    await _client.from('chat_messages').insert(<String, dynamic>{
      'session_id': sessionId,
      'sender': 'user',
      'content': message,
    });

    try {
      final functionResponse = await _client.functions.invoke(
        'ai-chat',
        body: <String, dynamic>{
          'session_id': sessionId,
          'message': message,
          'user_id': user.id,
        },
      );
      final data = functionResponse.data;
      var assistantContent = 'I could not generate a response right now.';
      if (data is Map<String, dynamic>) {
        final errorMessage = data['error'] as String?;
        if (errorMessage != null && errorMessage.trim().isNotEmpty) {
          throw NetworkFailure(message: errorMessage);
        }
        assistantContent =
            data['assistant_message'] as String? ?? assistantContent;
      }
      final row = await _client
          .from('chat_messages')
          .insert(<String, dynamic>{
            'session_id': sessionId,
            'sender': 'assistant',
            'content': assistantContent,
          })
          .select('id,session_id,sender,content,created_at')
          .single();

      await _client
          .from('chat_sessions')
          .update(<String, dynamic>{
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', sessionId);

      return ChatMessageEntity(
        id: row['id'] as String,
        sessionId: row['session_id'] as String,
        sender: row['sender'] as String? ?? 'assistant',
        content: row['content'] as String? ?? assistantContent,
        createdAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
    } on FunctionException catch (e, st) {
      throw NetworkFailure(
        message: e.details?.toString() ?? 'Unable to reach the AI assistant.',
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
}
