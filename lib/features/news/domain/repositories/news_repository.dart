import '../../../../core/result/paged.dart';
import '../entities/news_article.dart';

abstract class NewsRepository {
  Future<Paged<NewsArticleEntity>> listPersonalizedNews({
    String? cursor,
    int limit = 20,
  });

  Future<NewsArticleEntity?> getArticleById(String articleId);

  Future<void> trackInteraction(
    String articleId,
    NewsInteractionType interactionType, {
    Map<String, dynamic> metadata = const <String, dynamic>{},
  });

  Future<bool> saveArticle(String articleId);

  Future<void> removeSavedArticle(String articleId);

  Future<void> dismissArticle(String articleId);
}
