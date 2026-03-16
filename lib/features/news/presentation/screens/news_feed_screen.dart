import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../../../member/presentation/widgets/member_profile_shortcut_button.dart';
import '../../domain/entities/news_article.dart';
import '../controllers/news_controller.dart';
import '../providers/news_feed_provider.dart';
import '../widgets/news_card.dart';
import '../widgets/news_empty_state.dart';
import '../widgets/news_error_state.dart';

class NewsFeedScreen extends ConsumerStatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  ConsumerState<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends ConsumerState<NewsFeedScreen> {
  late final ScrollController _scrollController;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSizes.screenPadding,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended Reads',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Trusted health and fitness reads ranked for your current goal.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSizes.screenPadding),
            child: MemberProfileShortcutButton(size: 40),
          ),
        ],
      ),
      body: SafeArea(
        child: AppShellBackground(
          topGlowColor: AppColors.glowBlue,
          bottomGlowColor: AppColors.glowOrange,
          child: feedAsync.when(
            loading: _buildLoading,
            error: (error, _) => NewsErrorState(
              message: '$error',
              onRetry: () => unawaited(
                ref
                    .read(newsFeedControllerProvider.notifier)
                    .loadInitial(force: true),
              ),
            ),
            data: (feedState) {
              if (feedState.items.isEmpty) {
                return RefreshIndicator.adaptive(
                  onRefresh: () =>
                      ref.read(newsFeedControllerProvider.notifier).refresh(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSizes.screenPadding),
                    children: const [
                      SizedBox(height: 120),
                      NewsEmptyState(
                        title: 'Nothing to recommend yet',
                        message:
                            'As you use GymUnity, your feed will get sharper around your goals, habits, and trusted topics.',
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator.adaptive(
                onRefresh: () =>
                    ref.read(newsFeedControllerProvider.notifier).refresh(),
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSizes.screenPadding),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _FeedHero(feedState: feedState);
                    }

                    if (index == feedState.items.length + 1) {
                      return feedState.isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSizes.xl,
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.orange,
                                ),
                              ),
                            )
                          : const SizedBox(height: AppSizes.xxl);
                    }

                    final article = feedState.items[index - 1];
                    return NewsCard(
                      article: article,
                      onTap: () => _openArticle(article),
                      onSaveTap: () => _toggleSaved(article),
                      onDismissTap: () => _dismiss(article),
                    );
                  },
                  separatorBuilder: (_, index) =>
                      const SizedBox(height: AppSizes.lg),
                  itemCount: feedState.items.length + 2,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      itemBuilder: (_, index) => Container(
        height: index == 0 ? 148 : 320,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.cardDark,
              AppColors.surfacePanel.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          border: Border.all(color: AppColors.borderLight),
        ),
      ),
      separatorBuilder: (_, index) => const SizedBox(height: AppSizes.lg),
      itemCount: 4,
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

class _FeedHero extends StatelessWidget {
  const _FeedHero({required this.feedState});

  final NewsFeedState feedState;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 720;
    if (compact) {
      return const SizedBox.shrink();
    }
    final freshCount = feedState.items
        .where(
          (article) =>
              DateTime.now().difference(article.publishedAt).inDays <= 7,
        )
        .length;

    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
        border: Border.all(color: AppColors.borderSoft.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardDark.withValues(alpha: 0.96),
            AppColors.surfacePanel.withValues(alpha: 0.96),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: const [
              _FeedPill(label: 'Goal-aware', color: AppColors.orangeLight),
              _FeedPill(label: 'Scannable summaries', color: AppColors.aqua),
              _FeedPill(label: 'Trusted sources', color: AppColors.limeGreen),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Text(
            'Designed to feel calm, quick, and useful.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.05,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            'Short summaries, stronger hierarchy, and less visual noise so the right article stands out immediately.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Row(
            children: [
              Expanded(
                child: _FeedMetric(
                  label: 'Available now',
                  value: '${feedState.items.length}',
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: _FeedMetric(
                  label: 'Fresh this week',
                  value: '$freshCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedPill extends StatelessWidget {
  const _FeedPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _FeedMetric extends StatelessWidget {
  const _FeedMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
