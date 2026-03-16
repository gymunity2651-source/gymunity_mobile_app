import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/external_link_service.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/news_article.dart';
import '../providers/news_feed_provider.dart';
import '../widgets/news_empty_state.dart';
import '../widgets/news_error_state.dart';

class NewsArticleDetailsScreen extends ConsumerStatefulWidget {
  const NewsArticleDetailsScreen({
    super.key,
    this.initialArticle,
    this.articleId,
  });

  final NewsArticleEntity? initialArticle;
  final String? articleId;

  @override
  ConsumerState<NewsArticleDetailsScreen> createState() =>
      _NewsArticleDetailsScreenState();
}

class _NewsArticleDetailsScreenState
    extends ConsumerState<NewsArticleDetailsScreen> {
  NewsArticleEntity? _overrideArticle;

  String get _articleId => widget.articleId ?? widget.initialArticle?.id ?? '';

  @override
  Widget build(BuildContext context) {
    if (_articleId.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: NewsEmptyState(
            title: 'Article unavailable',
            message: 'A valid article id is required to open this read.',
          ),
        ),
      );
    }

    final detailsAsync = ref.watch(newsArticleDetailsProvider(_articleId));
    final article =
        _overrideArticle ?? detailsAsync.valueOrNull ?? widget.initialArticle;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (article != null)
            IconButton(
              onPressed: () => _toggleSaved(article),
              icon: Icon(
                article.isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: article.isSaved
                    ? AppColors.orange
                    : AppColors.textSecondary,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: detailsAsync.when(
          loading: () => article == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.orange),
                )
              : _DetailsBody(
                  article: article,
                  onOpenOriginal: () => _openOriginal(article),
                ),
          error: (error, _) => article == null
              ? NewsErrorState(
                  message: '$error',
                  onRetry: () =>
                      ref.invalidate(newsArticleDetailsProvider(_articleId)),
                )
              : _DetailsBody(
                  article: article,
                  onOpenOriginal: () => _openOriginal(article),
                ),
          data: (loadedArticle) {
            final effectiveArticle =
                _overrideArticle ?? loadedArticle ?? article;
            if (effectiveArticle == null) {
              return const NewsEmptyState(
                title: 'Article unavailable',
                message:
                    'This recommendation is no longer available in your feed.',
              );
            }
            return _DetailsBody(
              article: effectiveArticle,
              onOpenOriginal: () => _openOriginal(effectiveArticle),
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleSaved(NewsArticleEntity article) async {
    try {
      final saved = await ref
          .read(newsFeedControllerProvider.notifier)
          .toggleSaved(article);
      final updated = article.copyWith(isSaved: saved);
      ref.read(newsFeedControllerProvider.notifier).updateArticle(updated);
      setState(() => _overrideArticle = updated);
      if (!mounted) return;
      showAppFeedback(
        context,
        saved ? 'Saved for later.' : 'Removed from saved articles.',
      );
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(context, '$error');
    }
  }

  Future<void> _openOriginal(NewsArticleEntity article) async {
    await ref
        .read(newsFeedControllerProvider.notifier)
        .trackClick(article.id, origin: 'detail');
    final opened = await ExternalLinkService.openUrl(article.canonicalUrl);
    if (!mounted || opened) {
      return;
    }
    showAppFeedback(context, 'Unable to open the original article link.');
  }
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({required this.article, required this.onOpenOriginal});

  final NewsArticleEntity article;
  final VoidCallback onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        0,
        AppSizes.screenPadding,
        AppSizes.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            child: SizedBox(
              height: 240,
              width: double.infinity,
              child: article.hasImage
                  ? Image.network(
                      article.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallbackHero(),
                    )
                  : _fallbackHero(),
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              _InfoChip(label: article.sourceName),
              _InfoChip(label: _formatDate(article.publishedAt)),
              if ((article.category ?? '').isNotEmpty)
                _InfoChip(label: _labelize(article.category!)),
              if ((article.evidenceLevel ?? '').isNotEmpty)
                _InfoChip(label: _labelize(article.evidenceLevel!)),
              _InfoChip(
                label: 'Trust ${article.trustScore.toStringAsFixed(0)}',
              ),
            ],
          ),
          if (article.isCaution) ...[
            const SizedBox(height: AppSizes.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.lg),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'This piece is kept in the feed with extra caution. Treat it as educational information, not diagnosis or treatment advice.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSizes.xl),
          Text(
            article.title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.02,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          if ((article.relevanceReason ?? '').isNotEmpty)
            Text(
              article.relevanceReason!,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.electricBlue,
              ),
            ),
          if ((article.relevanceReason ?? '').isNotEmpty)
            const SizedBox(height: AppSizes.md),
          Text(
            article.summary,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.7,
              color: AppColors.textSecondary,
            ),
          ),
          if ((article.content ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSizes.xl),
            Text(
              'What It Covers',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              article.content!,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.7,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (article.topicCodes.isNotEmpty) ...[
            const SizedBox(height: AppSizes.xl),
            Text(
              'Related Topics',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: article.topicCodes
                  .map((topic) => _InfoChip(label: _labelize(topic)))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: AppSizes.xxl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenOriginal,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Original Article'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackHero() {
    return Container(
      color: AppColors.surfaceRaised,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.newspaper_outlined,
            size: 42,
            color: AppColors.electricBlue,
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            article.sourceName,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
}

String _labelize(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
