import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFF130F0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF130F0B),
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Workout Plan',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await ref
                  .read(plannerReminderBootstrapProvider)
                  .sync(requestPermissions: true);
              if (context.mounted) {
                showAppFeedback(context, 'Planner reminders have been synced.');
              }
            },
            icon: const Icon(Icons.notifications_active_outlined),
          ),
        ],
      ),
      body: planAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (error, stackTrace) => _PlanStateCard(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load your plan',
          description:
              'GymUnity could not fetch the active AI plan details right now.',
          actionLabel: 'Retry',
          onTap: () => ref.invalidate(planDetailProvider(planId)),
        ),
        data: (plan) {
          if (plan == null) {
            return _PlanStateCard(
              icon: Icons.event_note_outlined,
              title: 'No active AI plan',
              description:
                  'Start a planning conversation to generate, review, and activate your first member plan.',
              actionLabel: 'Open AI planner',
              onTap: () => Navigator.pushNamed(context, AppRoutes.aiChatHome),
            );
          }

          final generatedPlan = plan.generatedPlan;
          final allTasks = plan.days.expand((day) => day.tasks).toList();
          final completedCount = allTasks
              .where(
                (task) =>
                    task.completionStatus == TaskCompletionStatus.completed,
              )
              .length;
          final partialCount = allTasks
              .where(
                (task) => task.completionStatus == TaskCompletionStatus.partial,
              )
              .length;
          final skippedCount = allTasks
              .where(
                (task) => task.completionStatus == TaskCompletionStatus.skipped,
              )
              .length;
          final missedCount = allTasks
              .where(
                (task) => task.completionStatus == TaskCompletionStatus.missed,
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
            child: RefreshIndicator(
              color: AppColors.orange,
              onRefresh: () async {
                ref.invalidate(planDetailProvider(planId));
                await ref.read(planDetailProvider(planId).future);
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                children: [
                  AppReveal(
                    delay: revealDelay(0),
                    child: _SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.planTitle,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            generatedPlan?.summary.trim().isNotEmpty == true
                                ? generatedPlan!.summary
                                : 'Your active AI plan is ready for daily execution.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _Tag(label: _titleCase(plan.planStatus)),
                              if (generatedPlan != null)
                                _Tag(label: _titleCase(generatedPlan.level)),
                              if (generatedPlan != null)
                                _Tag(
                                  label: '${generatedPlan.durationWeeks} weeks',
                                ),
                              if ((plan.defaultReminderTime ?? '').isNotEmpty)
                                _Tag(
                                  label:
                                      'Reminder ${plan.defaultReminderTime!}',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricCard(
                                label: 'Partial',
                                value: partialCount.toString(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                label: 'Skipped',
                                value: skippedCount.toString(),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                    const SizedBox(height: 16),
                    AppReveal(
                      delay: revealDelay(2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle('Safety Notes'),
                          const SizedBox(height: 10),
                          _SurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: generatedPlan.safetyNotes
                                  .map(
                                    (note) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        '- $note',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          height: 1.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
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
                      child: Text(
                        actionState.errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppReveal(
                    delay: revealDelay(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Today'),
                        const SizedBox(height: 10),
                        if (todayTasks.isEmpty)
                          const _SurfaceCard(
                            child: Text(
                              'No AI tasks are scheduled for today. Your plan starts on the next scheduled day.',
                            ),
                          )
                        else
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
                                AppRoutes.workoutDetails,
                                arguments: WorkoutDayArgs(
                                  planId: plan.planId,
                                  dayId: task.dayId,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppReveal(
                    delay: revealDelay(5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Upcoming Days'),
                        const SizedBox(height: 10),
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
                  const SizedBox(height: 16),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.orange,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: DefaultTextStyle(
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
        child: child,
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
        ? 'This time is used for your upcoming AI tasks.'
        : 'Choose a default time for your upcoming AI tasks.';
    final button = OutlinedButton(
      key: const ValueKey<String>('workout-plan-reminder-button'),
      onPressed: isUpdating ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface.withValues(alpha: 0.62),
        side: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.9)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
      ),
      child: Text(
        actionLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth =
            constraints.maxWidth + (AppSizes.screenPadding * 2);
        final isCompact = effectiveWidth < 380;
        final content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.28),
                ),
              ),
              child: const Icon(
                Icons.alarm_rounded,
                color: AppColors.orange,
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
                      color: AppColors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Text(
                      'DAILY REMINDER',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppColors.orangeLight,
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
                          ? AppColors.orange.withValues(alpha: 0.12)
                          : AppColors.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      border: Border.all(
                        color: hasReminder
                            ? AppColors.orange.withValues(alpha: 0.22)
                            : AppColors.borderLight.withValues(alpha: 0.75),
                      ),
                    ),
                    child: Text(
                      _formatReminderDisplayValue(normalizedReminderTime),
                      key: const ValueKey<String>('workout-plan-reminder-time'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: hasReminder
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    helperText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        return Container(
          width: double.infinity,
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
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            border: Border.all(
              color: AppColors.borderLight.withValues(alpha: 0.88),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  trailing,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
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
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: _SurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.orange),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
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
        ),
      ),
    );
  }
}
