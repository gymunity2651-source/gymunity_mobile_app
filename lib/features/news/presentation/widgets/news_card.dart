import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/news_article.dart';

class NewsCard extends StatelessWidget {
  const NewsCard({
    super.key,
    required this.article,
    required this.onTap,
    this.onSaveTap,
    this.onDismissTap,
    this.compact = false,
    this.showDismiss = true,
  });

  final NewsArticleEntity article;
  final VoidCallback onTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onDismissTap;
  final bool compact;
  final bool showDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(AppSizes.radiusXl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            border: Border.all(color: AppColors.borderLight),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cardDark,
                AppColors.surfaceRaised.withValues(alpha: 0.92),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? AppSizes.lg : AppSizes.xl),
            child: compact
                ? _CompactLayout(article: article, onSaveTap: onSaveTap)
                : _FullLayout(
                    article: article,
                    onSaveTap: onSaveTap,
                    onDismissTap: onDismissTap,
                    showDismiss: showDismiss,
                  ),
          ),
        ),
      ),
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({required this.article, this.onSaveTap});

  final NewsArticleEntity article;
  final VoidCallback? onSaveTap;

  @override
  Widget build(BuildContext context) {
    final supportingLabel = article.relevanceReason?.trim().isNotEmpty == true
        ? article.relevanceReason!
        : ((article.category ?? '').isNotEmpty
              ? _labelize(article.category!)
              : article.sourceName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NewsCardImage(article: article, compact: true),
        const SizedBox(width: AppSizes.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaLine(article: article),
              const SizedBox(height: AppSizes.sm),
              Text(
                article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                article.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      supportingLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.electricBlue,
                      ),
                    ),
                  ),
                  if (onSaveTap != null)
                    IconButton(
                      onPressed: onSaveTap,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        article.isSaved
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: article.isSaved
                            ? AppColors.orange
                            : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullLayout extends StatelessWidget {
  const _FullLayout({
    required this.article,
    this.onSaveTap,
    this.onDismissTap,
    required this.showDismiss,
  });

  final NewsArticleEntity article;
  final VoidCallback? onSaveTap;
  final VoidCallback? onDismissTap;
  final bool showDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _MetaLine(article: article)),
            if (article.isCaution) const _ToneChip(label: 'Use caution'),
            if (onSaveTap != null)
              IconButton(
                onPressed: onSaveTap,
                icon: Icon(
                  article.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: article.isSaved
                      ? AppColors.orange
                      : AppColors.textMuted,
                ),
              ),
            if (showDismiss && onDismissTap != null)
              IconButton(
                onPressed: onDismissTap,
                icon: const Icon(
                  Icons.visibility_off_outlined,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        _NewsCardImage(article: article),
        const SizedBox(height: AppSizes.lg),
        Text(
          article.title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Text(
          article.summary,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.55,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            if ((article.relevanceReason ?? '').isNotEmpty)
              _ToneChip(label: article.relevanceReason!),
            if ((article.category ?? '').isNotEmpty)
              _ToneChip(label: _labelize(article.category!)),
            if ((article.evidenceLevel ?? '').isNotEmpty)
              _ToneChip(label: _labelize(article.evidenceLevel!)),
          ],
        ),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.article});

  final NewsArticleEntity article;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${article.sourceName}  -  ${_formatDate(article.publishedAt)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _NewsCardImage extends StatelessWidget {
  const _NewsCardImage({required this.article, this.compact = false});

  final NewsArticleEntity article;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 92.0 : 190.0;
    final width = compact ? 104.0 : double.infinity;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: SizedBox(
        height: height,
        width: width,
        child: article.hasImage
            ? Image.network(
                article.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.surfaceRaised,
      alignment: Alignment.center,
      child: const Icon(
        Icons.health_and_safety_outlined,
        color: AppColors.electricBlue,
        size: AppSizes.iconLg,
      ),
    );
  }
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({required this.label});

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
