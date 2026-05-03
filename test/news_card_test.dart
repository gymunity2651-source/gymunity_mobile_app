import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/news/domain/entities/news_article.dart';
import 'package:my_app/features/news/presentation/widgets/news_card.dart';

void main() {
  testWidgets('news card fallback no longer renders Trusted read text', (
    tester,
  ) async {
    final article = NewsArticleEntity(
      id: 'article-1',
      sourceId: 'source-1',
      sourceName: 'NIH News Releases',
      sourceBaseUrl: 'https://www.nih.gov',
      canonicalUrl: 'https://www.nih.gov/news-events/news-releases/article-1',
      title: 'Recovery basics for consistent training',
      summary: 'A trusted explainer on sleep, hydration, and recovery.',
      publishedAt: DateTime(2026, 3, 16),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NewsCard(article: article, onTap: () {}),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Trusted read'), findsNothing);
    expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
  });
}
