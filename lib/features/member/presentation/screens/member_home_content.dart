import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../news/domain/entities/news_article.dart';
import '../../../news/presentation/providers/news_feed_provider.dart';
import '../../../news/presentation/widgets/news_card.dart';
import '../../../planner/domain/entities/planner_entities.dart';
import '../../../planner/presentation/providers/planner_providers.dart';
import '../../../planner/presentation/route_args.dart';
import '../../../user/domain/entities/profile_entity.dart';
import '../providers/member_providers.dart';
import '../widgets/member_profile_shortcut_button.dart';

class MemberHomeContent extends ConsumerWidget {
  const MemberHomeContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final aiPremiumEnabled = AppConfig.current.enableAiPremium;

    return SafeArea(
      child: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(currentUserProfileProvider);
          ref.invalidate(memberHomeSummaryProvider);
          ref.invalidate(todayAgendaProvider);
          ref.invalidate(newsPreviewProvider);
          await ref.read(plannerReminderBootstrapProvider).sync();
        },
        child: profileAsync.when(
          loading: () => const _HomeStateScaffold(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.orange),
            ),
          ),
          error: (error, stackTrace) => _HomeStateScaffold(
            child: _StatusCard(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load your account',
              description:
                  'GymUnity could not refresh your account details right now.',
              actionLabel: 'Retry',
              onTap: () => ref.refresh(currentUserProfileProvider),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return _HomeStateScaffold(
                child: _StatusCard(
                  icon: Icons.person_search_outlined,
                  title: 'Finish setting up your account',
                  description:
                      'Your GymUnity member profile is signed in, but the in-app profile is not complete yet.',
                  actionLabel: 'Choose role',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.roleSelection),
                ),
              );
            }

            return _MemberHomeLoaded(
              profile: profile,
              aiPremiumEnabled: aiPremiumEnabled,
            );
          },
        ),
      ),
    );
  }
}

class _MemberHomeLoaded extends ConsumerWidget {
  const _MemberHomeLoaded({
    required this.profile,
    required this.aiPremiumEnabled,
  });

  final ProfileEntity profile;
  final bool aiPremiumEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullName = profile.fullName?.trim().isNotEmpty == true
        ? profile.fullName!.trim()
        : 'GymUnity Member';
    final firstName = fullName.split(' ').first;
    final email = profile.email?.trim().isNotEmpty == true
        ? profile.email!.trim()
        : 'No email available';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        const Align(
          alignment: Alignment.topRight,
          child: MemberProfileShortcutButton(),
        ),
        const SizedBox(height: 12),
        Text(
          'Welcome back, $firstName',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your member dashboard now surfaces the active AI plan flow, today’s tasks, and the live GymUnity entry points already backed by the app.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                email,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Pill(
                    label: profile.onboardingCompleted
                        ? 'Member profile ready'
                        : 'Onboarding pending',
                    accent: profile.onboardingCompleted
                        ? AppColors.limeGreen
                        : AppColors.orange,
                  ),
                  const _Pill(
                    label: 'Planner-aware dashboard',
                    accent: AppColors.electricBlue,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(title: 'Today'),
        const SizedBox(height: 12),
        const _TodayTaskCard(),
        const SizedBox(height: 20),
        _SectionTitle(title: 'Recommended Reads'),
        const SizedBox(height: 12),
        const _RecommendedReadsSection(),
        const SizedBox(height: 20),
        _SectionTitle(title: 'Quick Actions'),
        const SizedBox(height: 12),
        _QuickActionCard(
          icon: Icons.auto_awesome_outlined,
          title: aiPremiumEnabled ? 'Open AI Premium' : 'Open AI Assistant',
          description: aiPremiumEnabled
              ? 'Start a guided AI plan or continue a verified AI conversation.'
              : 'Start a guided AI plan or continue a general AI conversation.',
          onTap: () => Navigator.pushNamed(context, AppRoutes.aiChatHome),
        ),
        const SizedBox(height: 12),
        _QuickActionCard(
          icon: Icons.event_note_outlined,
          title: 'Open active plan',
          description:
              'Review your activated AI plan, upcoming days, and reminder settings.',
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.workoutPlan,
            arguments: const WorkoutPlanArgs(),
          ),
        ),
        const SizedBox(height: 12),
        _QuickActionCard(
          icon: Icons.storefront_outlined,
          title: 'Browse Store',
          description:
              'Review the current product catalog without fake checkout or preview purchases.',
          onTap: () => Navigator.pushNamed(context, AppRoutes.storeHome),
        ),
        const SizedBox(height: 12),
        _QuickActionCard(
          icon: Icons.groups_outlined,
          title: 'Browse Coaches',
          description:
              'Compare listed coaches without demo package requests or fake checkout.',
          onTap: () => Navigator.pushNamed(context, AppRoutes.coaches),
        ),
        const SizedBox(height: 12),
        _QuickActionCard(
          icon: Icons.settings_outlined,
          title: 'Account Settings',
          description:
              'Manage legal links, notifications, support channels, logout, and account deletion.',
          onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
        ),
      ],
    );
  }
}

class _TodayTaskCard extends ConsumerWidget {
  const _TodayTaskCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(memberHomeSummaryProvider);
    final todayAsync = ref.watch(todayAgendaProvider);
    final actionState = ref.watch(plannerActionControllerProvider);
    assert(() {
      debugPrint(
        '[planner-ui] TodayTaskCard summary=$summaryAsync today=$todayAsync',
      );
      return true;
    }());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardDark,
            AppColors.surfaceRaised.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: summaryAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (error, stackTrace) => _InlineState(
          title: 'Unable to load today’s agenda',
          description: 'GymUnity could not read your member summary right now.',
        ),
        data: (homeSummary) => todayAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.orange),
          ),
          error: (error, stackTrace) => _InlineState(
            title: 'Unable to load today’s tasks',
            description:
                'Pull to refresh or reopen the member dashboard to retry.',
          ),
          data: (tasks) {
            final activePlan = homeSummary.activePlan;
            final pendingCount = tasks
                .where(
                  (task) =>
                      task.completionStatus == TaskCompletionStatus.pending,
                )
                .length;
            final completedCount = tasks
                .where(
                  (task) =>
                      task.completionStatus == TaskCompletionStatus.completed ||
                      task.completionStatus == TaskCompletionStatus.partial,
                )
                .length;
            final missedCount = tasks
                .where(
                  (task) =>
                      task.completionStatus == TaskCompletionStatus.missed,
                )
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _TodayCardLabel(label: 'LIVE AGENDA'),
                          const SizedBox(height: 10),
                          Text(
                            'Today’s AI tasks',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tasks.isEmpty
                                ? 'No AI tasks are scheduled today yet.'
                                : 'Stay on the current plan with clear actions and one-tap status updates.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (activePlan != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.workoutPlan,
                        arguments: WorkoutPlanArgs(planId: activePlan.id),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Open active plan'),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricPill(label: 'Pending', value: pendingCount),
                    _MetricPill(label: 'Done', value: completedCount),
                    _MetricPill(label: 'Missed', value: missedCount),
                  ],
                ),
                const SizedBox(height: 16),
                if (tasks.isEmpty)
                  _EmptyTasksState(activePlan: activePlan != null)
                else
                  ...tasks
                      .take(3)
                      .map(
                        (task) => _TaskActionRow(
                          task: task,
                          isUpdating: actionState.isUpdatingTask,
                          onOpen: () => Navigator.pushNamed(
                            context,
                            AppRoutes.workoutDetails,
                            arguments: WorkoutDayArgs(
                              planId: task.planId,
                              dayId: task.dayId,
                            ),
                          ),
                          onComplete: () => _updateTask(
                            context,
                            ref,
                            task,
                            TaskCompletionStatus.completed,
                            100,
                          ),
                          onPartial: () => _updateTask(
                            context,
                            ref,
                            task,
                            TaskCompletionStatus.partial,
                            50,
                          ),
                          onSkip: () => _updateTask(
                            context,
                            ref,
                            task,
                            TaskCompletionStatus.skipped,
                            0,
                          ),
                        ),
                      ),
                if (tasks.length > 3) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.workoutPlan,
                        arguments: activePlan == null
                            ? const WorkoutPlanArgs()
                            : WorkoutPlanArgs(planId: activePlan.id),
                      ),
                      child: Text('View all ${tasks.length} tasks'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _updateTask(
    BuildContext context,
    WidgetRef ref,
    PlanTaskEntity task,
    TaskCompletionStatus status,
    int completionPercent,
  ) async {
    final updated = await ref
        .read(plannerActionControllerProvider.notifier)
        .updateTaskStatus(
          taskId: task.taskId,
          status: status,
          completionPercent: completionPercent,
        );
    if (!context.mounted) {
      return;
    }
    if (updated == null) {
      showAppFeedback(
        context,
        ref.read(plannerActionControllerProvider).errorMessage ??
            'GymUnity could not update this task right now.',
      );
      return;
    }
    showAppFeedback(context, 'Task marked ${status.label.toLowerCase()}.');
  }
}

class _HomeStateScaffold extends StatelessWidget {
  const _HomeStateScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        const Align(
          alignment: Alignment.topRight,
          child: MemberProfileShortcutButton(),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _InlineState extends StatelessWidget {
  const _InlineState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState({required this.activePlan});

  final bool activePlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14100C),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Text(
        activePlan
            ? 'Your plan is active. Today may be a rest or recovery day.'
            : 'Start a planning chat to generate an AI plan and get daily tasks here.',
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _TaskActionRow extends StatelessWidget {
  const _TaskActionRow({
    required this.task,
    required this.isUpdating,
    required this.onOpen,
    required this.onComplete,
    required this.onPartial,
    required this.onSkip,
  });

  final PlanTaskEntity task;
  final bool isUpdating;
  final VoidCallback onOpen;
  final VoidCallback onComplete;
  final VoidCallback onPartial;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14100C),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onOpen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.reminderTime ?? task.scheduledTime ?? 'Any time',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _TaskStatusPill(status: task.completionStatus),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isUpdating ? null : onSkip,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: isUpdating ? null : onPartial,
                  child: const Text('Partial'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: isUpdating ? null : onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCardLabel extends StatelessWidget {
  const _TodayCardLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.orangeLight,
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.orange, size: 36),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.white,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.orange.withValues(alpha: 0.16),
              child: Icon(icon, color: AppColors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _RecommendedReadsSection extends ConsumerWidget {
  const _RecommendedReadsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(newsPreviewProvider);

    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: previewAsync.when(
        loading: () => const SizedBox(
          height: 140,
          child: Center(
            child: CircularProgressIndicator(color: AppColors.orange),
          ),
        ),
        error: (error, stackTrace) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trusted health reads are temporarily unavailable.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              '$error',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            OutlinedButton(
              onPressed: () => ref.invalidate(newsPreviewProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
        data: (articles) {
          if (articles.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your news feed is still warming up.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Text(
                  'GymUnity will rank trusted reads around your goal, activity, and topics you engage with.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.newsFeed),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Open Feed'),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'For your current goal',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          'Calm, trustworthy reads that fit where you are right now.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.newsFeed),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              for (final article in articles.take(2)) ...[
                NewsCard(
                  article: article,
                  compact: true,
                  showDismiss: false,
                  onTap: () => _openArticle(context, ref, article),
                ),
                const SizedBox(height: AppSizes.md),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openArticle(
    BuildContext context,
    WidgetRef ref,
    NewsArticleEntity article,
  ) async {
    await ref
        .read(newsFeedControllerProvider.notifier)
        .trackOpen(article.id, origin: 'member_home');
    if (!context.mounted) {
      return;
    }
    await Navigator.pushNamed(
      context,
      AppRoutes.newsArticleDetails,
      arguments: article,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

class _TaskStatusPill extends StatelessWidget {
  const _TaskStatusPill({required this.status});

  final TaskCompletionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TaskCompletionStatus.completed => AppColors.limeGreen,
      TaskCompletionStatus.partial => AppColors.electricBlue,
      TaskCompletionStatus.skipped => AppColors.orange,
      TaskCompletionStatus.missed => AppColors.error,
      TaskCompletionStatus.pending => AppColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
