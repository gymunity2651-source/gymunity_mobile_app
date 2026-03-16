import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/news_article.dart';
import '../controllers/news_controller.dart';

final newsFeedControllerProvider =
    StateNotifierProvider<NewsController, AsyncValue<NewsFeedState>>((ref) {
      return NewsController(ref);
    });

final newsPreviewProvider = FutureProvider<List<NewsArticleEntity>>((
  ref,
) async {
  final page = await ref
      .watch(newsRepositoryProvider)
      .listPersonalizedNews(limit: 3);
  return page.items;
});

final newsArticleDetailsProvider =
    FutureProvider.family<NewsArticleEntity?, String>((ref, articleId) async {
      return ref.watch(newsRepositoryProvider).getArticleById(articleId);
    });
