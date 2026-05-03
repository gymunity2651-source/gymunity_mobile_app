import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/features/news/domain/entities/news_article.dart';
import 'package:my_app/features/news/presentation/screens/news_feed_screen.dart';

import 'test_doubles.dart';

void main() {
  testWidgets('news feed loads articles, saves them, and opens details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final newsRepository = FakeNewsRepository()
      ..articles = <NewsArticleEntity>[
        NewsArticleEntity(
          id: 'article-1',
          sourceId: 'source-1',
          sourceName: 'NIH News in Health',
          sourceBaseUrl: 'https://newsinhealth.nih.gov',
          canonicalUrl: 'https://newsinhealth.nih.gov/article-1',
          title: 'Recovery basics for consistent training',
          summary: 'A trusted explainer on sleep, hydration, and recovery.',
          publishedAt: DateTime(2026, 3, 15),
          topicCodes: const <String>['recovery', 'sleep'],
          relevanceReason: 'Matches your goal',
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          newsRepositoryProvider.overrideWithValue(newsRepository),
        ],
        child: MaterialApp(
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: const NewsFeedScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Recommended'), findsOneWidget);
    final articleTitle = find.text('Recovery basics for consistent training');
    expect(articleTitle, findsWidgets);

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded).first);
    await tester.pumpAndSettle();

    expect(newsRepository.savedArticleIds, contains('article-1'));
    expect(find.text('Saved for later.'), findsOneWidget);

    await tester.tap(articleTitle.first);
    await tester.pumpAndSettle();

    expect(find.text('Open Original Article'), findsOneWidget);
    expect(
      newsRepository.trackedInteractions.any(
        (row) =>
            row['articleId'] == 'article-1' && row['interactionType'] == 'open',
      ),
      isTrue,
    );
  });
}
