import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/paged.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/repositories/news_repository.dart';
import '../models/news_article_model.dart';

class NewsRepositoryImpl implements NewsRepository {
  NewsRepositoryImpl(this._client);

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'No authenticated user found.');
    }
    return userId;
  }

  @override
  Future<Paged<NewsArticleEntity>> listPersonalizedNews({
    String? cursor,
    int limit = 20,
  }) async {
    final offset = int.tryParse(cursor ?? '') ?? 0;
    try {
      final rows = await _client.rpc(
        'list_personalized_news',
        params: <String, dynamic>{'p_limit': limit, 'p_offset': offset},
      );
      final items = _rowList(
        rows,
      ).map(NewsArticleModel.fromFeedMap).toList(growable: false);
      final nextCursor = items.length < limit
          ? null
          : (offset + items.length).toString();
      return Paged<NewsArticleEntity>(items: items, nextCursor: nextCursor);
    } on PostgrestException catch (error, stackTrace) {
      throw NetworkFailure(
        message: error.message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to load personalized articles.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<NewsArticleEntity?> getArticleById(String articleId) async {
    try {
      final articleRow = await _client
          .from('news_articles')
          .select(
            'id,source_id,canonical_url,title,summary,content,author_name,image_url,published_at,language,category,safety_level,evidence_level,trust_score,quality_score,target_roles,target_goals,target_levels',
          )
          .eq('id', articleId)
          .maybeSingle();
      if (articleRow == null) {
        return null;
      }

      final sourceRow = await _client
          .from('news_sources')
          .select('name,base_url')
          .eq('id', articleRow['source_id'] as String)
          .maybeSingle();
      final topics = await _client.rpc(
        'list_news_article_topics',
        params: <String, dynamic>{'p_article_id': articleId},
      );
      final savedRow = await _client
          .from('news_article_bookmarks')
          .select('article_id')
          .eq('user_id', _userId)
          .eq('article_id', articleId)
          .maybeSingle();

      return NewsArticleModel.fromDetailParts(
        articleRow: articleRow,
        sourceRow: sourceRow,
        topicRows: topics is List ? topics : const <dynamic>[],
        isSaved: savedRow != null,
      );
    } on PostgrestException catch (error, stackTrace) {
      throw NetworkFailure(
        message: error.message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to load the article.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> trackInteraction(
    String articleId,
    NewsInteractionType interactionType, {
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    try {
      await _client.rpc(
        'track_news_interaction',
        params: <String, dynamic>{
          'p_article_id': articleId,
          'p_interaction_type': interactionType.wireValue,
          'p_metadata': metadata,
        },
      );
    } on PostgrestException catch (error, stackTrace) {
      throw NetworkFailure(
        message: error.message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to track article interaction.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<bool> saveArticle(String articleId) async {
    try {
      final response = await _client.rpc(
        'save_news_article',
        params: <String, dynamic>{'p_article_id': articleId},
      );
      return response == true;
    } on PostgrestException catch (error, stackTrace) {
      throw NetworkFailure(
        message: error.message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to save the article.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> removeSavedArticle(String articleId) async {
    try {
      await _client
          .from('news_article_bookmarks')
          .delete()
          .eq('user_id', _userId)
          .eq('article_id', articleId);
    } on PostgrestException catch (error, stackTrace) {
      throw NetworkFailure(
        message: error.message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to remove the saved article.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> dismissArticle(String articleId) async {
    try {
      await _client.rpc(
        'dismiss_news_article',
        params: <String, dynamic>{'p_article_id': articleId},
      );
    } on PostgrestException catch (error, stackTrace) {
      throw NetworkFailure(
        message: error.message,
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw NetworkFailure(
        message: 'Unable to dismiss the article.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  List<Map<String, dynamic>> _rowList(dynamic rows) {
    if (rows is! List) {
      return const <Map<String, dynamic>>[];
    }
    return rows
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}
