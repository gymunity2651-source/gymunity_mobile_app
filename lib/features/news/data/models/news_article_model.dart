import '../../domain/entities/news_article.dart';

class NewsArticleModel {
  NewsArticleModel._();

  static NewsArticleEntity fromFeedMap(Map<String, dynamic> map) {
    return NewsArticleEntity(
      id: map['article_id'] as String? ?? '',
      sourceId: map['source_id'] as String? ?? '',
      sourceName: map['source_name'] as String? ?? 'Trusted Source',
      sourceBaseUrl: map['source_base_url'] as String? ?? '',
      canonicalUrl: map['canonical_url'] as String? ?? '',
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      publishedAt: _parseDate(map['published_at']),
      language: map['language'] as String? ?? 'english',
      category: map['category'] as String?,
      safetyLevel: map['safety_level'] as String? ?? 'general',
      evidenceLevel: map['evidence_level'] as String?,
      trustScore: _toDouble(map['trust_score']),
      qualityScore: _toDouble(map['quality_score']),
      topicCodes: _stringList(map['topic_codes']),
      relevanceReason: map['relevance_reason'] as String?,
      relevanceTags: _stringList(map['relevance_tags']),
      rankingScore: _toDouble(map['ranking_score']),
      isSaved: map['is_saved'] as bool? ?? false,
    );
  }

  static NewsArticleEntity fromDetailParts({
    required Map<String, dynamic> articleRow,
    Map<String, dynamic>? sourceRow,
    List<dynamic> topicRows = const <dynamic>[],
    required bool isSaved,
  }) {
    return NewsArticleEntity(
      id: articleRow['id'] as String? ?? '',
      sourceId: articleRow['source_id'] as String? ?? '',
      sourceName: sourceRow?['name'] as String? ?? 'Trusted Source',
      sourceBaseUrl: sourceRow?['base_url'] as String? ?? '',
      canonicalUrl: articleRow['canonical_url'] as String? ?? '',
      title: articleRow['title'] as String? ?? '',
      summary: articleRow['summary'] as String? ?? '',
      content: articleRow['content'] as String?,
      authorName: articleRow['author_name'] as String?,
      imageUrl: articleRow['image_url'] as String?,
      publishedAt: _parseDate(articleRow['published_at']),
      language: articleRow['language'] as String? ?? 'english',
      category: articleRow['category'] as String?,
      safetyLevel: articleRow['safety_level'] as String? ?? 'general',
      evidenceLevel: articleRow['evidence_level'] as String?,
      trustScore: _toDouble(articleRow['trust_score']),
      qualityScore: _toDouble(articleRow['quality_score']),
      topicCodes: topicRows
          .map((dynamic row) => (row as Map<String, dynamic>)['topic_code'])
          .whereType<String>()
          .toList(growable: false),
      targetRoles: _stringList(articleRow['target_roles']),
      targetGoals: _stringList(articleRow['target_goals']),
      targetLevels: _stringList(articleRow['target_levels']),
      isSaved: isSaved,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }
}
