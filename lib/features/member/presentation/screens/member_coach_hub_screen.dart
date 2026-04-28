import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../coach_member_insights/presentation/providers/insight_providers.dart';
import '../../domain/entities/coach_hub_entity.dart';
import '../../domain/entities/coaching_engagement_entity.dart';
import '../providers/member_providers.dart';

class MemberCoachHubScreen extends ConsumerWidget {
  const MemberCoachHubScreen({super.key, this.subscriptionId});

  final String? subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hubAsync = ref.watch(memberCoachHubProvider(subscriptionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Coach'),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(memberCoachHubProvider(subscriptionId));
          await ref.read(memberCoachHubProvider(subscriptionId).future);
        },
        child: hubAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.orange),
          ),
          error: (error, _) => _StatePanel(
            title: 'Coach Hub unavailable',
            body: error.toString(),
            actionLabel: 'Retry',
            onTap: () => ref.invalidate(memberCoachHubProvider(subscriptionId)),
          ),
          data: (hub) {
            final subscription = hub.subscription;
            if (subscription == null) {
              return _StatePanel(
                title: 'No coaching relationship yet',
                body:
                    'Choose a coach package and activate a subscription to unlock your Coach Hub.',
                actionLabel: 'Browse coaches',
                onTap: () => Navigator.pushNamed(context, AppRoutes.coaches),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _CoachCard(hub: hub),
                if (hub.needsKickoff) ...[
                  const SizedBox(height: 12),
                  _ActionPanel(
                    icon: Icons.flag_outlined,
                    title: 'Complete your kickoff',
                    body:
                        'Share your goal, constraints, and privacy choices so your coach can build around your real week.',
                    actionLabel: 'Start kickoff',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.memberCoachKickoff,
                      arguments: subscription.id,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _Section(
                  title: 'Today from your coach',
                  empty: 'No coach-assigned actions for today.',
                  children: hub.todayAgenda
                      .take(5)
                      .map((item) => _AgendaTile(item: item))
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                _WeekFocus(hub: hub),
                const SizedBox(height: 12),
                _ProgressSnapshot(hub: hub),
                const SizedBox(height: 12),
                _LatestFeedback(feedback: hub.latestFeedback),
                const SizedBox(height: 12),
                _Section(
                  title: 'Assigned habits',
                  actionLabel: 'View all',
                  onAction: () => Navigator.pushNamed(
                    context,
                    AppRoutes.memberCoachHabits,
                    arguments: subscription.id,
                  ),
                  empty: 'Your coach has not assigned habits yet.',
                  children: hub.habits
                      .take(3)
                      .map((habit) => _HabitTile(habit: habit))
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Resources',
                  actionLabel: 'Open',
                  onAction: () => Navigator.pushNamed(
                    context,
                    AppRoutes.memberCoachResources,
                    arguments: subscription.id,
                  ),
                  empty: 'No assigned resources yet.',
                  children: hub.resources
                      .take(3)
                      .map((resource) => _ResourceTile(resource: resource))
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                _Section(
                  title: 'Sessions',
                  actionLabel: 'Book',
                  onAction: () => Navigator.pushNamed(
                    context,
                    AppRoutes.memberCoachSessions,
                    arguments: subscription.id,
                  ),
                  empty: 'No upcoming sessions.',
                  children: hub.bookings
                      .take(2)
                      .map(
                        (booking) => _SimpleTile(
                          icon: Icons.event_outlined,
                          title: booking.title,
                          subtitle:
                              '${_dateTime(booking.startsAt)} · ${booking.status.replaceAll('_', ' ')}',
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                _QuickActions(hub: hub),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.hub});

  final MemberCoachHubEntity hub;

  @override
  Widget build(BuildContext context) {
    final subscription = hub.subscription!;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.orange.withValues(alpha: 0.16),
                child: Text(
                  subscription.coachName.isEmpty
                      ? 'C'
                      : subscription.coachName.characters.first.toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.coachName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subscription.packageTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(subscription.status.replaceAll('_', ' ')),
              _Chip(hub.relationshipStage.replaceAll('_', ' ')),
              _Chip(subscription.responseSlaLabel),
            ],
          ),
          if (subscription.packageSummaryForMember.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              subscription.packageSummaryForMember,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekFocus extends StatelessWidget {
  const _WeekFocus({required this.hub});

  final MemberCoachHubEntity hub;

  @override
  Widget build(BuildContext context) {
    final weekItems = hub.weekAgenda.take(5).toList(growable: false);
    return _Section(
      title: 'This week focus',
      empty: 'Your weekly focus will appear when your coach assigns actions.',
      children: weekItems
          .map((item) => _AgendaTile(item: item, compact: true))
          .toList(growable: false),
    );
  }
}

class _ProgressSnapshot extends StatelessWidget {
  const _ProgressSnapshot({required this.hub});

  final MemberCoachHubEntity hub;

  @override
  Widget build(BuildContext context) {
    final progress = hub.progressSnapshot;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(title: 'Progress snapshot'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '${progress.workoutsCompletedThisWeek}',
                  label: 'Workouts',
                ),
              ),
              Expanded(
                child: _Metric(
                  value: '${progress.habitsCompletedThisWeek}',
                  label: 'Habits',
                ),
              ),
              Expanded(
                child: _Metric(
                  value: progress.checkinStatus.replaceAll('_', ' '),
                  label: 'Check-in',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LatestFeedback extends StatelessWidget {
  const _LatestFeedback({required this.feedback});

  final MemberCoachFeedbackEntity? feedback;

  @override
  Widget build(BuildContext context) {
    final current = feedback;
    if (current == null || current.checkinId.isEmpty) {
      return const _ActionPanel(
        icon: Icons.rate_review_outlined,
        title: 'Latest coach feedback',
        body: 'Coach feedback will appear here after your weekly check-in.',
      );
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(title: 'Latest coach feedback'),
          if (current.onePriority.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              current.onePriority,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (current.whatWentWell.trim().isNotEmpty)
            _DetailLine('Went well', current.whatWentWell),
          if (current.whatNeedsAttention.trim().isNotEmpty)
            _DetailLine('Needs attention', current.whatNeedsAttention),
          if (current.adjustmentForNextWeek.trim().isNotEmpty)
            _DetailLine('Adjustment', current.adjustmentForNextWeek),
          if (current.planChangesSummary.trim().isNotEmpty)
            _DetailLine('Plan changes', current.planChangesSummary),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.hub});

  final MemberCoachHubEntity hub;

  @override
  Widget build(BuildContext context) {
    final subscription = hub.subscription!;
    final threadId = subscription.threadId;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(title: 'Quick actions'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                icon: Icons.chat_outlined,
                label: 'Message coach',
                onTap: threadId == null
                    ? null
                    : () => Navigator.pushNamed(
                        context,
                        AppRoutes.memberThread,
                        arguments: CoachingThreadEntity(
                          id: threadId,
                          subscriptionId: subscription.id,
                          memberId: subscription.memberId,
                          coachId: subscription.coachId,
                          coachName: subscription.coachName,
                          packageTitle: subscription.packageTitle,
                          subscriptionStatus: subscription.status,
                        ),
                      ),
              ),
              _ActionButton(
                icon: Icons.fact_check_outlined,
                label: 'Submit check-in',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.memberCheckins),
              ),
              _ActionButton(
                icon: Icons.playlist_add_check,
                label: 'Log habit',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.memberCoachHabits,
                  arguments: subscription.id,
                ),
              ),
              _ActionButton(
                icon: Icons.event_outlined,
                label: 'Book session',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.memberCoachSessions,
                  arguments: subscription.id,
                ),
              ),
              _ActionButton(
                icon: Icons.shield_outlined,
                label: 'Visibility',
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.memberCoachVisibility,
                  arguments: VisibilitySettingsArgs(
                    subscriptionId: subscription.id,
                    coachId: subscription.coachId,
                    coachName: subscription.coachName,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    required this.empty,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final List<Widget> children;
  final String empty;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            title: title,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
          const SizedBox(height: 10),
          if (children.isEmpty)
            Text(
              empty,
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({required this.item, this.compact = false});

  final MemberCoachAgendaItemEntity item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _SimpleTile(
      icon: _iconForType(item.type),
      title: item.title,
      subtitle: compact
          ? item.status.replaceAll('_', ' ')
          : [
              if (item.description.trim().isNotEmpty) item.description,
              item.status.replaceAll('_', ' '),
            ].join(' · '),
      trailing: item.isDone
          ? const Icon(Icons.check_circle, color: AppColors.success)
          : null,
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit});

  final MemberAssignedHabitEntity habit;

  @override
  Widget build(BuildContext context) {
    return _SimpleTile(
      icon: Icons.playlist_add_check,
      title: habit.title,
      subtitle:
          '${habit.frequency} · ${habit.loggedToday ? habit.completionStatus : '${habit.adherencePercent}% this week'}',
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({required this.resource});

  final MemberAssignedResourceEntity resource;

  @override
  Widget build(BuildContext context) {
    return _SimpleTile(
      icon: resource.isExternal
          ? Icons.link_outlined
          : Icons.insert_drive_file_outlined,
      title: resource.title,
      subtitle: resource.isCompleted
          ? 'completed'
          : resource.isViewed
          ? 'viewed'
          : 'not viewed',
    );
  }
}

class _SimpleTile extends StatelessWidget {
  const _SimpleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.orange),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(color: AppColors.textSecondary),
      ),
      trailing: trailing,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.inter(
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.sports_gymnastics, color: AppColors.orange, size: 40),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(fontSize: 26),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

IconData _iconForType(String type) {
  return switch (type) {
    'workout_task' => Icons.fitness_center_outlined,
    'habit' => Icons.playlist_add_check,
    'checkin_due' => Icons.fact_check_outlined,
    'resource' => Icons.folder_open_outlined,
    'booking' => Icons.event_outlined,
    'coach_feedback' => Icons.rate_review_outlined,
    _ => Icons.task_alt_outlined,
  };
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  final date = local.toIso8601String().split('T').first;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$date $hour:$minute';
}
