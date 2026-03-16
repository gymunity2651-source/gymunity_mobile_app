import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../member/presentation/widgets/member_profile_shortcut_button.dart';
import '../../domain/entities/news_article.dart';
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
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSizes.screenPadding,
        title: Column(
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
            child: Center(
              child: MemberProfileShortcutButton(size: 40),
            ),
          ),
        ],
      ),
      body: SafeArea(
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
                  physics: AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
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
                  if (index == feedState.items.length) {
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

                  final article = feedState.items[index];
                  return NewsCard(
                    article: article,
                    onTap: () => _openArticle(article),
                    onSaveTap: () => _toggleSaved(article),
                    onDismissTap: () => _dismiss(article),
                  );
                },
                separatorBuilder: (_, index) =>
                    const SizedBox(height: AppSizes.lg),
                itemCount: feedState.items.length + 1,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      itemBuilder: (_, index) => Container(
        height: 320,
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          border: Border.all(color: AppColors.borderLight),
        ),
      ),
      separatorBuilder: (_, index) => const SizedBox(height: AppSizes.lg),
      itemCount: 3,
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
