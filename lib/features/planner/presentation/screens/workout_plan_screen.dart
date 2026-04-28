import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/theme/atelier_theme.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_reveal.dart';
import '../../domain/entities/planner_entities.dart';
import '../providers/planner_providers.dart';
import '../route_args.dart';

class WorkoutPlanScreen extends ConsumerWidget {
  const WorkoutPlanScreen({super.key, this.planId});

  final String? planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(planDetailProvider(planId));
    final actionState = ref.watch(plannerActionControllerProvider);

    return Theme(
      data: AtelierTheme.light,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AtelierColors.surfaceContainerLowest,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: AtelierColors.surfaceContainerLowest,
          appBar: AppBar(
            backgroundColor: AtelierColors.surfaceContainerLowest,
            foregroundColor: AtelierColors.onSurface,
            leadingWidth: 56,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _IconGlassButton(
                tooltip: 'Back to home',
                onPressed: () => _exitWorkoutPlan(context),
                icon: Icons.arrow_back_rounded,
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Workout Plan',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AtelierColors.onSurface,
                  ),
                ),
                Text(
                  'Curated weekly structure',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AtelierColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              _IconGlassButton(
                tooltip: 'Sync reminders',
                onPressed: () async {
                  await ref
                      .read(plannerReminderBootstrapProvider)
                      .sync(requestPermissions: true);
                  if (context.mounted) {
                    showAppFeedback(
                      context,
                      'Planner reminders have been synced.',
                    );
                  }
                },
                icon: Icons.notifications_active_outlined,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                return;
              }
              _exitWorkoutPlan(context);
            },
            child: planAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AtelierColors.primary),
              ),
              error: (error, stackTrace) => _PlanStateCard(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load your plan',
                description:
                    'GymUnity could not fetch the active TAIYO plan details right now.',
                actionLabel: 'Retry',
                onTap: () => ref.invalidate(planDetailProvider(planId)),
              ),
              data: (plan) {
                if (plan == null) {
                  return _PlanStateCard(
                    icon: Icons.event_note_outlined,
                    title: 'No active TAIYO plan',
                    description:
                        'Start AI Builder to scan your profile, answer guided questions, and review a structured workout plan.',
                    actionLabel: 'Open AI Builder',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.aiPlannerBuilder,
                    ),
                  );
                }

                final generatedPlan = plan.generatedPlan;
                final allTasks = plan.days.expand((day) => day.tasks).toList();
                final completedCount = allTasks
                    .where(
                      (task) =>
                          task.completionStatus ==
                          TaskCompletionStatus.completed,
                    )
                    .length;
                final partialCount = allTasks
                    .where(
                      (task) =>
                          task.completionStatus == TaskCompletionStatus.partial,
                    )
                    .length;
                final skippedCount = allTasks
                    .where(
                      (task) =>
                          task.completionStatus == TaskCompletionStatus.skipped,
                    )
                    .length;
                final missedCount = allTasks
                    .where(
                      (task) =>
                          task.completionStatus == TaskCompletionStatus.missed,
                    )
                    .length;
                final now = DateTime.now();
                final todayTasks = allTasks
                    .where((task) => _isSameDay(task.scheduledDate, now))
                    .toList(growable: false);
                final upcomingDays = plan.days
                    .where((day) => !_isBeforeToday(day.scheduledDate, now))
                    .take(10)
                    .toList(growable: false);
                Duration revealDelay(int index) =>
                    Duration(milliseconds: 40 + (index * 55));

                return SafeArea(
                  child: RefreshIndicator.adaptive(
                    color: AtelierColors.primary,
                    onRefresh: () async {
                      ref.invalidate(planDetailProvider(planId));
                      await ref.read(planDetailProvider(planId).future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
                      children: [
                        AppReveal(
                          delay: revealDelay(0),
                          child: _PlanHeroCard(
                            title: plan.planTitle,
                            summary:
                                generatedPlan?.summary.trim().isNotEmpty == true
                                ? generatedPlan!.summary
                                : 'Your active TAIYO plan is ready for daily execution.',
                            tags: [
                              _titleCase(plan.planStatus),
                              if (generatedPlan != null)
                                _titleCase(generatedPlan.level),
                              if (generatedPlan != null)
                                '${generatedPlan.durationWeeks} weeks',
                              if ((plan.defaultReminderTime ?? '').isNotEmpty)
                                'Reminder ${_formatReminderDisplayValue(plan.defaultReminderTime)}',
                            ],
                            totalTasks: allTasks.length,
                            upcomingDays: upcomingDays.length,
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppReveal(
                          delay: revealDelay(1),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Completed',
                                      value: completedCount.toString(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Partial',
                                      value: partialCount.toString(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Skipped',
                                      value: skippedCount.toString(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MetricCard(
                                      label: 'Missed',
                                      value: missedCount.toString(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (generatedPlan != null &&
                            generatedPlan.safetyNotes.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          AppReveal(
                            delay: revealDelay(2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle('Safety Notes'),
                                const SizedBox(height: 14),
                                _SurfaceCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: generatedPlan.safetyNotes
                                        .map(
                                          (note) => _GuidanceLine(note: note),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (actionState.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          AppReveal(
                            delay: revealDelay(3),
                            child: _InlineErrorMessage(
                              message: actionState.errorMessage!,
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        AppReveal(
                          delay: revealDelay(4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle('Today'),
                              const SizedBox(height: 14),
                              if (todayTasks.isEmpty)
                                upcomingDays.isEmpty
                                    ? const _SurfaceCard(
                                        child: Text(
                                          'No TAIYO tasks are scheduled for today. Your plan starts on the next scheduled day.',
                                        ),
                                      )
                                    : _NextWorkoutCard(
                                        day: upcomingDays.first,
                                        onStart: () => Navigator.pushNamed(
                                          context,
                                          AppRoutes.activeWorkoutSession,
                                          arguments: ActiveWorkoutSessionArgs(
                                            planId: plan.planId,
                                            dayId: upcomingDays.first.id,
                                          ),
                                        ),
                                        onReview: () => Navigator.pushNamed(
                                          context,
                                          AppRoutes.workoutDetails,
                                          arguments: WorkoutDayArgs(
                                            planId: plan.planId,
                                            dayId: upcomingDays.first.id,
                                          ),
                                        ),
                                      )
                              else ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _PrimaryGradientButton(
                                      onPressed: () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.activeWorkoutSession,
                                        arguments: ActiveWorkoutSessionArgs(
                                          planId: plan.planId,
                                          dayId: todayTasks.first.dayId,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                      label: 'Start guided workout',
                                    ),
                                  ),
                                ),
                                ...todayTasks.map(
                                  (task) => _TaskTile(
                                    title: task.title,
                                    subtitle:
                                        task.reminderTime ??
                                        task.scheduledTime ??
                                        'Any time today',
                                    trailing: task.completionStatus.label,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.activeWorkoutSession,
                                      arguments: ActiveWorkoutSessionArgs(
                                        planId: plan.planId,
                                        dayId: task.dayId,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        AppReveal(
                          delay: revealDelay(5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle('Upcoming Days'),
                              const SizedBox(height: 14),
                              if (upcomingDays.isEmpty)
                                const _SurfaceCard(
                                  child: Text(
                                    'No upcoming days were generated for this plan.',
                                  ),
                                )
                              else
                                ...upcomingDays.map(
                                  (day) => _TaskTile(
                                    title: day.label,
                                    subtitle:
                                        '${_formatDate(day.scheduledDate)} | ${day.tasks.length} tasks',
                                    trailing:
                                        '${day.tasks.where((task) => task.completionStatus == TaskCompletionStatus.completed).length}/${day.tasks.length}',
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.workoutDetails,
                                      arguments: WorkoutDayArgs(
                                        planId: plan.planId,
                                        dayId: day.id,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        AppReveal(
                          delay: revealDelay(6),
                          child: _PlanReminderCard(
                            reminderTime: plan.defaultReminderTime,
                            isUpdating: actionState.isUpdatingReminder,
                            onPressed: actionState.isUpdatingReminder
                                ? null
                                : () => _editReminderTime(context, ref, plan),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _editReminderTime(
  BuildContext context,
  WidgetRef ref,
  PlanDetailEntity plan,
) async {
  final initialTime = _parseTime(plan.defaultReminderTime);
  final picked = await showTimePicker(
    context: context,
    initialTime: initialTime,
  );
  if (picked == null) {
    return;
  }

  final success = await ref
      .read(plannerActionControllerProvider.notifier)
      .updateReminderTime(
        planId: plan.planId,
        reminderTime: _formatTimeOfDay(picked),
      );
  if (!context.mounted) {
    return;
  }
  if (!success) {
    showAppFeedback(
      context,
      ref.read(plannerActionControllerProvider).errorMessage ??
          'GymUnity could not update the reminder time right now.',
    );
    return;
  }
  showAppFeedback(context, 'Daily reminder time updated.');
}

void _exitWorkoutPlan(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  navigator.pushReplacementNamed(AppRoutes.memberHome);
}

bool _isBeforeToday(DateTime date, DateTime now) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  return day.isBefore(today);
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

TimeOfDay _parseTime(String? value) {
  return _tryParseTimeOfDay(value) ?? const TimeOfDay(hour: 7, minute: 0);
}

String _formatTimeOfDay(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String? _normalizeReminderTime(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

TimeOfDay? _tryParseTimeOfDay(String? value) {
  final normalized = _normalizeReminderTime(value);
  if (normalized == null) {
    return null;
  }

  final parts = normalized.split(':');
  if (parts.length < 2) {
    return null;
  }

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }

  return TimeOfDay(hour: hour, minute: minute);
}

String _formatReminderDisplayValue(String? value) {
  final normalized = _normalizeReminderTime(value);
  if (normalized == null) {
    return 'Not set';
  }

  final parsed = _tryParseTimeOfDay(normalized);
  if (parsed == null) {
    return normalized;
  }

  final hour = parsed.hourOfPeriod == 0 ? 12 : parsed.hourOfPeriod;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final suffix = parsed.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }
  final normalized = value.replaceAll('_', ' ');
  return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
}

class _IconGlassButton extends StatelessWidget {
  const _IconGlassButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: AtelierColors.surfaceContainerLow,
        foregroundColor: AtelierColors.onSurface,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AtelierColors.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanHeroCard extends StatelessWidget {
  const _PlanHeroCard({
    required this.title,
    required this.summary,
    required this.tags,
    required this.totalTasks,
    required this.upcomingDays,
  });

  final String title;
  final String summary;
  final List<String> tags;
  final int totalTasks;
  final int upcomingDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TAIYO TRAINING ATELIER',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          FractionallySizedBox(
            widthFactor: 0.92,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: GoogleFonts.notoSerif(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1.08,
                color: AtelierColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            summary,
            style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.62,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tags.map((tag) => _Tag(label: tag)).toList(),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _HeroMiniMetric(
                  label: 'Tasks',
                  value: totalTasks.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroMiniMetric(
                  label: 'Next days',
                  value: upcomingDays.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMiniMetric extends StatelessWidget {
  const _HeroMiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.notoSerif(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AtelierColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AtelierColors.onSurface,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      surfaceColor: AtelierColors.surfaceContainerLow,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.notoSerif(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1,
              color: AtelierColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.surfaceColor = AtelierColors.surfaceContainerLow,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final Color surfaceColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTextStyle(
        style: GoogleFonts.manrope(
          fontSize: 13,
          height: 1.55,
          fontWeight: FontWeight.w500,
          color: AtelierColors.onSurfaceVariant,
        ),
        child: child,
      ),
    );
  }
}

class _GuidanceLine extends StatelessWidget {
  const _GuidanceLine({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AtelierColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.spa_outlined,
              size: 16,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              note,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: AtelierColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineErrorMessage extends StatelessWidget {
  const _InlineErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      surfaceColor: AtelierColors.surfaceContainer,
      child: Text(
        message,
        style: GoogleFonts.manrope(
          fontSize: 13,
          height: 1.5,
          fontWeight: FontWeight.w600,
          color: AtelierColors.error,
        ),
      ),
    );
  }
}

class _NextWorkoutCard extends StatelessWidget {
  const _NextWorkoutCard({
    required this.day,
    required this.onStart,
    required this.onReview,
  });

  final PlanDayEntity day;
  final VoidCallback onStart;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your plan is active',
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'First session: ${day.label} on ${_formatDate(day.scheduledDate)}. You can start it now or review the day structure first.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AtelierColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AtelierColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: AtelierColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AtelierColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.tasks.length} tasks',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AtelierColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final primary = _PrimaryGradientButton(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: 'Start next workout',
              );
              final secondary = _SecondaryTonalButton(
                onPressed: onReview,
                label: 'Review day',
              );

              if (constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: primary),
                    const SizedBox(height: 10),
                    secondary,
                  ],
                );
              }

              return Row(
                children: [
                  primary,
                  const SizedBox(width: 10),
                  Expanded(child: secondary),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PrimaryGradientButton extends StatelessWidget {
  const _PrimaryGradientButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AtelierColors.primaryGradient),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: AtelierColors.navShadow,
              blurRadius: 40,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme(
                  data: const IconThemeData(
                    color: AtelierColors.onPrimary,
                    size: 20,
                  ),
                  child: icon,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AtelierColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryTonalButton extends StatelessWidget {
  const _SecondaryTonalButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AtelierColors.onSurface,
        backgroundColor: AtelierColors.surfaceContainerLowest,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PlanReminderCard extends StatelessWidget {
  const _PlanReminderCard({
    required this.reminderTime,
    required this.isUpdating,
    required this.onPressed,
  });

  final String? reminderTime;
  final bool isUpdating;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final normalizedReminderTime = _normalizeReminderTime(reminderTime);
    final hasReminder = normalizedReminderTime != null;
    final actionLabel = isUpdating
        ? 'Saving...'
        : hasReminder
        ? 'Edit'
        : 'Set reminder';
    final helperText = hasReminder
        ? 'This time is used for your upcoming TAIYO tasks.'
        : 'Choose a default time for your upcoming TAIYO tasks.';
    final button = OutlinedButton(
      key: const ValueKey<String>('workout-plan-reminder-button'),
      onPressed: isUpdating ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AtelierColors.onSurface,
        backgroundColor: AtelierColors.surfaceContainerLowest,
        disabledForegroundColor: AtelierColors.textMuted,
        disabledBackgroundColor: AtelierColors.surfaceContainer,
        side: const BorderSide(color: AtelierColors.transparent),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Text(
        actionLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 348;
        final content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AtelierColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.alarm_rounded,
                color: AtelierColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AtelierColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'DAILY REMINDER',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AtelierColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: hasReminder
                          ? AtelierColors.surfaceContainerLowest
                          : AtelierColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatReminderDisplayValue(normalizedReminderTime),
                      key: const ValueKey<String>('workout-plan-reminder-time'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSerif(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: hasReminder
                            ? AtelierColors.onSurface
                            : AtelierColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    helperText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      height: 1.45,
                      color: AtelierColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    content,
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: button),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 116,
                        maxWidth: 144,
                      ),
                      child: button,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AtelierColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: AtelierColors.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AtelierColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AtelierColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  trailing,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AtelierColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanStateCard extends StatelessWidget {
  const _PlanStateCard({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _SurfaceCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AtelierColors.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSerif(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AtelierColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  height: 1.5,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _PrimaryGradientButton(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: actionLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
