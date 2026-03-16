import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/news_article.dart';

class NewsFeedState {
  const NewsFeedState({
    this.items = const <NewsArticleEntity>[],
    this.nextCursor,
    this.isLoadingMore = false,
    this.isRefreshing = false,
  });

  final List<NewsArticleEntity> items;
  final String? nextCursor;
  final bool isLoadingMore;
  final bool isRefreshing;

  bool get hasMore => nextCursor != null;

  NewsFeedState copyWith({
    List<NewsArticleEntity>? items,
    String? nextCursor,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool clearNextCursor = false,
  }) {
    return NewsFeedState(
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class NewsController extends StateNotifier<AsyncValue<NewsFeedState>> {
  NewsController(this._ref) : super(const AsyncValue<NewsFeedState>.loading());

  final Ref _ref;
  final Set<String> _trackedImpressions = <String>{};

  Future<void> loadInitial({bool force = false}) async {
    if (!force && state.valueOrNull != null) {
      return;
    }

    state = const AsyncValue<NewsFeedState>.loading();
    state = await AsyncValue.guard(() async {
      final page = await _ref
          .read(newsRepositoryProvider)
          .listPersonalizedNews(limit: 20);
      unawaited(_trackImpressions(page.items, surface: 'feed'));
      return NewsFeedState(items: page.items, nextCursor: page.nextCursor);
    });
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue<NewsFeedState>.data(
        current.copyWith(isRefreshing: true),
      );
    }

    state = await AsyncValue.guard(() async {
      final page = await _ref
          .read(newsRepositoryProvider)
          .listPersonalizedNews(limit: 20);
      _trackedImpressions.clear();
      unawaited(_trackImpressions(page.items, surface: 'feed'));
      return NewsFeedState(items: page.items, nextCursor: page.nextCursor);
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    state = AsyncValue<NewsFeedState>.data(
      current.copyWith(isLoadingMore: true),
    );
    try {
      final page = await _ref
          .read(newsRepositoryProvider)
          .listPersonalizedNews(limit: 20, cursor: current.nextCursor);
      final merged = <NewsArticleEntity>[
        ...current.items,
        ...page.items.where(
          (candidate) =>
              current.items.every((existing) => existing.id != candidate.id),
        ),
      ];
      state = AsyncValue<NewsFeedState>.data(
        current.copyWith(
          items: merged,
          nextCursor: page.nextCursor,
          isLoadingMore: false,
        ),
      );
      unawaited(_trackImpressions(page.items, surface: 'feed'));
    } catch (error, stackTrace) {
      state = AsyncValue<NewsFeedState>.error(error, stackTrace);
      state = AsyncValue<NewsFeedState>.data(
        current.copyWith(isLoadingMore: false),
      );
    }
  }

  Future<bool> toggleSaved(NewsArticleEntity article) async {
    final current = state.valueOrNull;
    final nextSaved = !article.isSaved;
    _replaceArticle(article.copyWith(isSaved: nextSaved));
    try {
      if (nextSaved) {
        await _ref.read(newsRepositoryProvider).saveArticle(article.id);
      } else {
        await _ref.read(newsRepositoryProvider).removeSavedArticle(article.id);
      }
      return nextSaved;
    } catch (_) {
      if (current != null) {
        state = AsyncValue<NewsFeedState>.data(current);
      }
      rethrow;
    }
  }

  Future<void> dismiss(NewsArticleEntity article) async {
    final current = state.valueOrNull;
    if (current == null) {
      await _ref.read(newsRepositoryProvider).dismissArticle(article.id);
      return;
    }

    state = AsyncValue<NewsFeedState>.data(
      current.copyWith(
        items: current.items.where((item) => item.id != article.id).toList(),
      ),
    );
    try {
      await _ref.read(newsRepositoryProvider).dismissArticle(article.id);
    } catch (_) {
      state = AsyncValue<NewsFeedState>.data(current);
      rethrow;
    }
  }

  Future<void> trackOpen(String articleId, {String origin = 'feed'}) {
    return _ref
        .read(newsRepositoryProvider)
        .trackInteraction(
          articleId,
          NewsInteractionType.open,
          metadata: <String, dynamic>{'origin': origin},
        );
  }

  Future<void> trackClick(String articleId, {String origin = 'detail'}) {
    return _ref
        .read(newsRepositoryProvider)
        .trackInteraction(
          articleId,
          NewsInteractionType.click,
          metadata: <String, dynamic>{'origin': origin},
        );
  }

  void updateArticle(NewsArticleEntity article) {
    _replaceArticle(article);
  }

  void _replaceArticle(NewsArticleEntity article) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    final items = current.items
        .map((item) => item.id == article.id ? article : item)
        .toList(growable: false);
    state = AsyncValue<NewsFeedState>.data(current.copyWith(items: items));
  }

  Future<void> _trackImpressions(
    List<NewsArticleEntity> items, {
    required String surface,
  }) async {
    for (final article in items.take(6)) {
      if (_trackedImpressions.contains(article.id)) {
        continue;
      }
      _trackedImpressions.add(article.id);
      try {
        await _ref
            .read(newsRepositoryProvider)
            .trackInteraction(
              article.id,
              NewsInteractionType.impression,
              metadata: <String, dynamic>{'surface': surface},
            );
      } catch (_) {
        // Impression tracking should not block feed UX.
      }
    }
  }
}
