import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/theme/atelier_theme.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../member/presentation/widgets/member_profile_shortcut_button.dart';
import '../../domain/entities/news_article.dart';
import '../controllers/news_controller.dart';
import '../providers/news_feed_provider.dart';
import '../widgets/news_card.dart';

class NewsFeedScreen extends ConsumerStatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  ConsumerState<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends ConsumerState<NewsFeedScreen> {
  static const List<String> _curationLenses = <String>[
    'FOR YOU',
    'GOAL-AWARE',
    'SCANNABLE SUMMARIES',
    'TRUSTED SOURCES',
  ];

  late final ScrollController _scrollController;
  int _selectedLensIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(newsFeedControllerProvider.notifier).loadInitial());
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      unawaited(ref.read(newsFeedControllerProvider.notifier).loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(newsFeedControllerProvider);

    return Theme(
      data: AtelierTheme.light,
      child: Scaffold(
        backgroundColor: AtelierColors.surfaceContainerLowest,
        body: Stack(
          children: [
            const Positioned.fill(child: _NewsBackdrop()),
            SafeArea(
              bottom: false,
              child: feedAsync.when(
                loading: _buildLoadingView,
                error: (error, _) => _buildStateView(
                  title: 'Unable to curate your reads',
                  message:
                      'The editorial desk could not refresh your recommendations right now. Pull to try again.',
                  actionLabel: 'Retry Curation',
                  onAction: () => unawaited(
                    ref
                        .read(newsFeedControllerProvider.notifier)
                        .loadInitial(force: true),
                  ),
                ),
                data: (feedState) {
                  if (feedState.items.isEmpty) {
                    return _buildStateView(
                      title: 'Your reading table is still empty',
                      message:
                          'As you use GymUnity, the editorial feed will tune itself around your goals, habits, and trusted topics.',
                      actionLabel: 'Refresh Feed',
                      onAction: () => unawaited(
                        ref.read(newsFeedControllerProvider.notifier).refresh(),
                      ),
                    );
                  }
                  return _buildFeedView(feedState);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedView(NewsFeedState feedState) {
    return RefreshIndicator.adaptive(
      color: AtelierColors.primary,
      onRefresh: () => ref.read(newsFeedControllerProvider.notifier).refresh(),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          12,
          AppSizes.screenPadding,
          110,
        ),
        children: [
          _NewsMasthead(onSearch: _handleSearchTap),
          const SizedBox(height: 22),
          _IntroCard(lensLabel: _curationLenses[_selectedLensIndex]),
          const SizedBox(height: 18),
          _MetricsGrid(
            availableNow: feedState.items.length.toString().padLeft(2, '0'),
            freshThisWeek: _countFreshArticles(
              feedState.items,
            ).toString().padLeft(2, '0'),
            readingTime: '${_estimateTotalReadingMinutes(feedState.items)}m',
            savedItems: _countSavedArticles(
              feedState.items,
            ).toString().padLeft(2, '0'),
          ),
          const SizedBox(height: 20),
          _LensChips(
            selectedIndex: _selectedLensIndex,
            labels: _curationLenses,
            onSelected: (index) => setState(() => _selectedLensIndex = index),
          ),
          const SizedBox(height: 24),
          ..._buildArticleSections(feedState),
          if (feedState.isLoadingMore)
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 24),
              child: Center(
                child: CircularProgressIndicator(color: AtelierColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildArticleSections(NewsFeedState feedState) {
    final items = feedState.items;
    final sections = <Widget>[];

    void addSection(Widget widget) {
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 28));
      }
      sections.add(widget);
    }

    if (items.isEmpty) {
      return sections;
    }

    addSection(
      NewsCard(
        article: items.first,
        variant: NewsCardVariant.featured,
        onTap: () => _openArticle(items.first),
        onSaveTap: () => _toggleSaved(items.first),
        onDismissTap: () => _dismiss(items.first),
      ),
    );

    if (items.length > 1) {
      addSection(
        NewsCard(
          article: items[1],
          onTap: () => _openArticle(items[1]),
          onSaveTap: () => _toggleSaved(items[1]),
        ),
      );
    }

    if (items.length > 2) {
      addSection(
        NewsCard(
          article: items[2],
          onTap: () => _openArticle(items[2]),
          onSaveTap: () => _toggleSaved(items[2]),
        ),
      );
    }

    if (items.length > 3) {
      addSection(
        NewsCard(
          article: items[3],
          variant: NewsCardVariant.spotlight,
          onTap: () => _openArticle(items[3]),
          onSaveTap: () => _toggleSaved(items[3]),
        ),
      );
    }

    for (var index = 4; index < items.length; index++) {
      addSection(
        NewsCard(
          article: items[index],
          onTap: () => _openArticle(items[index]),
          onSaveTap: () => _toggleSaved(items[index]),
        ),
      );
    }

    return sections;
  }

  Widget _buildLoadingView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        12,
        AppSizes.screenPadding,
        110,
      ),
      children: const [
        _LoadingMasthead(),
        SizedBox(height: 22),
        _LoadingIntroCard(),
        SizedBox(height: 18),
        _LoadingMetricsGrid(),
        SizedBox(height: 20),
        _LoadingChipRow(),
        SizedBox(height: 24),
        _LoadingFeatureCard(),
        SizedBox(height: 28),
        _LoadingStoryCard(),
        SizedBox(height: 28),
        _LoadingStoryCard(),
        SizedBox(height: 28),
        _LoadingSpotlightCard(),
      ],
    );
  }

  Widget _buildStateView({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return RefreshIndicator.adaptive(
      color: AtelierColors.primary,
      onRefresh: () => ref.read(newsFeedControllerProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          12,
          AppSizes.screenPadding,
          110,
        ),
        children: [
          _NewsMasthead(onSearch: _handleSearchTap),
          const SizedBox(height: 22),
          _IntroCard(lensLabel: _curationLenses[_selectedLensIndex]),
          const SizedBox(height: 32),
          _NewsStateCard(
            title: title,
            message: message,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ],
      ),
    );
  }

  int _countFreshArticles(List<NewsArticleEntity> items) {
    return items
        .where(
          (article) =>
              DateTime.now().difference(article.publishedAt).inDays <= 7,
        )
        .length;
  }

  int _countSavedArticles(List<NewsArticleEntity> items) {
    return items.where((article) => article.isSaved).length;
  }

  int _estimateTotalReadingMinutes(List<NewsArticleEntity> items) {
    final total = items
        .take(6)
        .fold<int>(0, (sum, article) => sum + _estimateReadingMinutes(article));
    return math.max(6, total);
  }

  int _estimateReadingMinutes(NewsArticleEntity article) {
    final buffer = StringBuffer()
      ..write(article.title)
      ..write(' ')
      ..write(article.summary)
      ..write(' ')
      ..write(article.content ?? '');
    final words = buffer
        .toString()
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
    return math.max(3, (words / 180).ceil());
  }

  void _handleSearchTap() {
    showAppFeedback(
      context,
      'Editorial search is not available yet. Pull down to refresh the curation.',
    );
  }

  Future<void> _openArticle(NewsArticleEntity article) async {
    await ref.read(newsFeedControllerProvider.notifier).trackOpen(article.id);
    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.newsArticleDetails,
      arguments: article,
    );
  }

  Future<void> _toggleSaved(NewsArticleEntity article) async {
    try {
      final saved = await ref
          .read(newsFeedControllerProvider.notifier)
          .toggleSaved(article);
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

  Future<void> _dismiss(NewsArticleEntity article) async {
    try {
      await ref.read(newsFeedControllerProvider.notifier).dismiss(article);
      if (!mounted) return;
      showAppFeedback(context, 'We will show less content like this.');
    } catch (error) {
      if (!mounted) return;
      showAppFeedback(context, '$error');
    }
  }
}

class _NewsMasthead extends StatelessWidget {
  const _NewsMasthead({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const MemberProfileShortcutButton(
          size: 30,
          backgroundColor: AtelierColors.surfaceContainerLowest,
          iconColor: AtelierColors.onSurface,
          borderColor: AtelierColors.ghostBorder,
          tooltip: 'Profile',
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'AURA EDITORIAL',
            style: GoogleFonts.notoSerif(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.6,
              color: AtelierColors.primary,
            ),
          ),
        ),
        IconButton(
          onPressed: onSearch,
          icon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AtelierColors.primary,
          ),
          style: IconButton.styleFrom(
            backgroundColor: AtelierColors.surfaceContainerLowest,
            foregroundColor: AtelierColors.primary,
          ),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.lensLabel});

  final String lensLabel;
  static const Color _recommendedReadsTint = Color(0xFFDEC0B6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _recommendedReadsTint.withValues(alpha: 0.52),
            _recommendedReadsTint.withValues(alpha: 0.18),
            AtelierColors.surfaceContainerLowest.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURATED FOR YOUR WELLNESS',
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
              color: AtelierColors.primary.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Recommended\nReads',
            style: GoogleFonts.notoSerif(
              fontSize: 28,
              height: 1.04,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Discover hand-picked articles, medical breakthroughs, and mindful practices tailored to your unique health journey.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              height: 1.7,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            lensLabel,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AtelierColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.availableNow,
    required this.freshThisWeek,
    required this.readingTime,
    required this.savedItems,
  });

  final String availableNow;
  final String freshThisWeek;
  final String readingTime;
  final String savedItems;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.36,
      children: [
        _MetricTile(label: 'AVAILABLE NOW', value: availableNow),
        _MetricTile(label: 'FRESH THIS WEEK', value: freshThisWeek),
        _MetricTile(label: 'READING TIME', value: readingTime),
        _MetricTile(label: 'SAVED ITEMS', value: savedItems),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AtelierColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.notoSerif(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: AtelierColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LensChips extends StatelessWidget {
  const _LensChips({
    required this.selectedIndex,
    required this.labels,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(labels.length, (index) {
        final selected = index == selectedIndex;
        return GestureDetector(
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              gradient: selected
                  ? const LinearGradient(
                      colors: [
                        AtelierColors.primary,
                        AtelierColors.primaryContainer,
                      ],
                    )
                  : null,
              color: selected ? null : AtelierColors.surfaceContainerLow,
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: AtelierColors.navShadow,
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              labels[index],
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: selected
                    ? AtelierColors.onPrimary
                    : AtelierColors.onSurfaceVariant,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _NewsStateCard extends StatelessWidget {
  const _NewsStateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: AtelierColors.navShadow,
            blurRadius: 36,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AtelierColors.primaryContainer.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: AtelierColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerif(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.7,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AtelierColors.primary, AtelierColors.primaryContainer],
              ),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: AtelierColors.onPrimary,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              child: Text(
                actionLabel,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingMasthead extends StatelessWidget {
  const _LoadingMasthead();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _LoadingCircle(size: 30),
        SizedBox(width: 10),
        _LoadingBar(width: 124, height: 14),
        Spacer(),
        _LoadingCircle(size: 34),
      ],
    );
  }
}

class _LoadingIntroCard extends StatelessWidget {
  const _LoadingIntroCard();

  @override
  Widget build(BuildContext context) {
    return const _LoadingPanel(height: 190, radius: 28);
  }
}

class _LoadingMetricsGrid extends StatelessWidget {
  const _LoadingMetricsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.36,
      children: const [
        _LoadingPanel(height: 98, radius: 20),
        _LoadingPanel(height: 98, radius: 20),
        _LoadingPanel(height: 98, radius: 20),
        _LoadingPanel(height: 98, radius: 20),
      ],
    );
  }
}

class _LoadingChipRow extends StatelessWidget {
  const _LoadingChipRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _LoadingCapsule(width: 78),
        _LoadingCapsule(width: 94),
        _LoadingCapsule(width: 132),
        _LoadingCapsule(width: 104),
      ],
    );
  }
}

class _LoadingFeatureCard extends StatelessWidget {
  const _LoadingFeatureCard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LoadingPanel(height: 244, radius: 28),
        SizedBox(height: 16),
        _LoadingBar(width: 210, height: 18),
        SizedBox(height: 10),
        _LoadingBar(width: 170, height: 18),
        SizedBox(height: 10),
        _LoadingBar(width: double.infinity, height: 12),
        SizedBox(height: 8),
        _LoadingBar(width: 240, height: 12),
      ],
    );
  }
}

class _LoadingStoryCard extends StatelessWidget {
  const _LoadingStoryCard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LoadingPanel(height: 208, radius: 24),
        SizedBox(height: 12),
        _LoadingBar(width: 78, height: 10),
        SizedBox(height: 8),
        _LoadingBar(width: 192, height: 16),
        SizedBox(height: 8),
        _LoadingBar(width: 156, height: 16),
      ],
    );
  }
}

class _LoadingSpotlightCard extends StatelessWidget {
  const _LoadingSpotlightCard();

  @override
  Widget build(BuildContext context) {
    return const _LoadingPanel(height: 360, radius: 28);
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            AtelierColors.surfaceContainerLow,
            AtelierColors.surfaceContainerLowest.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: SizedBox(height: height),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _LoadingCapsule extends StatelessWidget {
  const _LoadingCapsule({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 34,
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9999),
      ),
    );
  }
}

class _LoadingCircle extends StatelessWidget {
  const _LoadingCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _NewsBackdrop extends StatelessWidget {
  const _NewsBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(color: AtelierColors.surfaceContainerLowest);
  }
}
