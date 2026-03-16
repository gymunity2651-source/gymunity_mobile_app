import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/news/data/models/news_article_model.dart';

void main() {
  test('fromFeedMap parses feed RPC rows into a news entity', () {
    final article = NewsArticleModel.fromFeedMap(<String, dynamic>{
      'article_id': 'article-1',
      'source_id': 'source-1',
      'source_name': 'WHO News (English)',
      'source_base_url': 'https://www.who.int',
      'canonical_url': 'https://www.who.int/article',
      'title': 'Hydration guidance for endurance training',
      'summary': 'A trusted update on fluids, heat, and endurance training.',
      'image_url': 'https://www.who.int/image.jpg',
      'published_at': '2026-03-15T12:00:00Z',
      'language': 'english',
      'category': 'public_health',
      'safety_level': 'general',
      'evidence_level': 'source_reported',
      'trust_score': 89.5,
      'quality_score': 77,
      'topic_codes': <String>['hydration', 'endurance'],
      'relevance_reason': 'Matches your goal',
      'relevance_tags': <String>['goal match', 'trusted source'],
      'ranking_score': 54.2,
      'is_saved': true,
    });

    expect(article.id, 'article-1');
    expect(article.sourceName, 'WHO News (English)');
    expect(article.topicCodes, <String>['hydration', 'endurance']);
    expect(article.relevanceReason, 'Matches your goal');
    expect(article.isSaved, isTrue);
  });

  test('fromDetailParts carries topic and targeting metadata', () {
    final article = NewsArticleModel.fromDetailParts(
      articleRow: <String, dynamic>{
        'id': 'article-1',
        'source_id': 'source-1',
        'canonical_url': 'https://www.who.int/article',
        'title': 'Sleep and recovery basics',
        'summary': 'Summary',
        'content': 'Detailed content',
        'published_at': '2026-03-15T12:00:00Z',
        'language': 'english',
        'safety_level': 'caution',
        'trust_score': 80,
        'quality_score': 72,
        'target_roles': <String>['member'],
        'target_goals': <String>['recovery'],
        'target_levels': <String>['all'],
      },
      sourceRow: <String, dynamic>{
        'name': 'NIH News in Health',
        'base_url': 'https://newsinhealth.nih.gov',
      },
      topicRows: const <Map<String, dynamic>>[
        <String, dynamic>{'topic_code': 'sleep', 'score': 0.9},
        <String, dynamic>{'topic_code': 'recovery', 'score': 0.8},
      ],
      isSaved: false,
    );

    expect(article.sourceBaseUrl, 'https://newsinhealth.nih.gov');
    expect(article.topicCodes, <String>['sleep', 'recovery']);
    expect(article.targetGoals, <String>['recovery']);
    expect(article.safetyLevel, 'caution');
  });
}
