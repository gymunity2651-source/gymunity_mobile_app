import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/atelier_colors.dart';
import '../../domain/entities/news_article.dart';

enum NewsCardVariant { featured, standard, spotlight }

class NewsCard extends StatelessWidget {
  const NewsCard({
    super.key,
    required this.article,
    required this.onTap,
    this.onSaveTap,
    this.onDismissTap,
    this.compact = false,
    this.showDismiss = true,
    this.variant = NewsCardVariant.standard,
  });

  final NewsArticleEntity article;
  final VoidCallback onTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onDismissTap;
  final bool compact;
  final bool showDismiss;
  final NewsCardVariant variant;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case NewsCardVariant.featured:
        return _FeaturedNewsCard(
          article: article,
          onTap: onTap,
          onSaveTap: onSaveTap,
          onDismissTap: showDismiss ? onDismissTap : null,
        );
      case NewsCardVariant.spotlight:
        return _SpotlightNewsCard(
          article: article,
          onTap: onTap,
          onSaveTap: onSaveTap,
        );
      case NewsCardVariant.standard:
        return _StandardNewsCard(
          article: article,
          onTap: onTap,
          onSaveTap: onSaveTap,
          compact: compact,
        );
    }
  }
}

class _FeaturedNewsCard extends StatelessWidget {
  const _FeaturedNewsCard({
    required this.article,
    required this.onTap,
    this.onSaveTap,
    this.onDismissTap,
  });

  final NewsArticleEntity article;
  final VoidCallback onTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onDismissTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _EditorialImageFrame(article: article, height: 246, radius: 28),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Row(
                    children: [
                      _OverlayPill(
                        label: _badgeSource(article.sourceName),
                        backgroundColor: AtelierColors.primary.withValues(
                          alpha: 0.92,
                        ),
                        textColor: AtelierColors.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      _OverlayPill(
                        label: _formatOverlayDate(article.publishedAt),
                        backgroundColor: AtelierColors.onSurface.withValues(
                          alpha: 0.84,
                        ),
                        textColor: AtelierColors.onPrimary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    article.title,
                    style: GoogleFonts.notoSerif(
                      fontSize: 23,
                      height: 1.08,
                      fontWeight: FontWeight.w500,
                      color: AtelierColors.onSurface,
                    ),
                  ),
                ),
                if (onSaveTap != null || onDismissTap != null) ...[
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      if (onSaveTap != null)
                        _ActionOrb(
                          icon: article.isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          onTap: onSaveTap!,
                        ),
                      if (onSaveTap != null && onDismissTap != null)
                        const SizedBox(height: 10),
                      if (onDismissTap != null)
                        _ActionOrb(
                          icon: Icons.visibility_off_outlined,
                          onTap: onDismissTap!,
                        ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              article.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.7,
                fontWeight: FontWeight.w500,
                color: AtelierColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandardNewsCard extends StatelessWidget {
  const _StandardNewsCard({
    required this.article,
    required this.onTap,
    this.onSaveTap,
    required this.compact,
  });

  final NewsArticleEntity article;
  final VoidCallback onTap;
  final VoidCallback? onSaveTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _EditorialImageFrame(
                  article: article,
                  height: compact ? 176 : 212,
                  radius: 24,
                ),
                if (onSaveTap != null)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _ActionOrb(
                      icon: article.isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      onTap: onSaveTap!,
                      subtle: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _eyebrowLabel(article),
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: AtelierColors.primaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              article.title,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSerif(
                fontSize: compact ? 19 : 21,
                height: 1.12,
                fontWeight: FontWeight.w500,
                color: AtelierColors.onSurface,
              ),
            ),
            if (article.summary.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                article.summary,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpotlightNewsCard extends StatelessWidget {
  const _SpotlightNewsCard({
    required this.article,
    required this.onTap,
    this.onSaveTap,
  });

  final NewsArticleEntity article;
  final VoidCallback onTap;
  final VoidCallback? onSaveTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EditorialImageFrame(article: article, height: 196, radius: 22),
              const SizedBox(height: 16),
              Row(
                children: [
                  _OverlayPill(
                    label: 'PREMIUM INSIGHT',
                    backgroundColor: AtelierColors.primaryContainer.withValues(
                      alpha: 0.16,
                    ),
                    textColor: AtelierColors.primary,
                  ),
                  const Spacer(),
                  if (onSaveTap != null)
                    _ActionOrb(
                      icon: article.isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      onTap: onSaveTap!,
                      subtle: true,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                article.title,
                style: GoogleFonts.notoSerif(
                  fontSize: 20,
                  height: 1.12,
                  fontWeight: FontWeight.w500,
                  color: AtelierColors.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                article.summary,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AtelierColors.primary,
                      AtelierColors.primaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: const [
                    BoxShadow(
                      color: AtelierColors.navShadow,
                      blurRadius: 28,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    foregroundColor: AtelierColors.onPrimary,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  child: Text(
                    'READ FULL FEATURE',
                    style: GoogleFonts.manrope(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorialImageFrame extends StatelessWidget {
  const _EditorialImageFrame({
    required this.article,
    required this.height,
    required this.radius,
  });

  final NewsArticleEntity article;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            article.hasImage
                ? Image.network(
                    article.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _FallbackImage(),
                  )
                : const _FallbackImage(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AtelierColors.primaryContainer.withValues(alpha: 0.08),
                    AtelierColors.transparent,
                    const Color(0x22F0D2C0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackImage extends StatelessWidget {
  const _FallbackImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AtelierColors.surfaceContainer,
      alignment: Alignment.center,
      child: const Icon(
        Icons.auto_stories_rounded,
        color: AtelierColors.primary,
        size: 32,
      ),
    );
  }
}

class _ActionOrb extends StatelessWidget {
  const _ActionOrb({
    required this.icon,
    required this.onTap,
    this.subtle = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: subtle
          ? AtelierColors.surfaceContainerLowest.withValues(alpha: 0.88)
          : AtelierColors.surfaceContainerLowest,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: subtle ? 34 : 36,
          height: subtle ? 34 : 36,
          child: Icon(
            icon,
            size: subtle ? 18 : 19,
            color: AtelierColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  const _OverlayPill({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: textColor,
        ),
      ),
    );
  }
}

String _badgeSource(String sourceName) {
  final words = sourceName
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (words.isEmpty) {
    return 'EDITORIAL';
  }
  final label = words.join(' ').toUpperCase();
  return label.length > 12 ? '${label.substring(0, 12)}…' : label;
}

String _formatOverlayDate(DateTime dateTime) {
  const months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${months[dateTime.month - 1]} ${dateTime.day}';
}

String _eyebrowLabel(NewsArticleEntity article) {
  if ((article.category ?? '').trim().isNotEmpty) {
    return _labelize(article.category!);
  }
  if ((article.relevanceReason ?? '').trim().isNotEmpty) {
    return article.relevanceReason!.toUpperCase();
  }
  return article.sourceName.toUpperCase();
}

String _labelize(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
