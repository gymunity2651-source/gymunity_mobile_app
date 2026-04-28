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

class WorkoutDayDetailsScreen extends ConsumerWidget {
  const WorkoutDayDetailsScreen({
    super.key,
    required this.planId,
    required this.dayId,
  });

  final String planId;
  final String dayId;

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
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(
                  backgroundColor: AtelierColors.surfaceContainerLow,
                  foregroundColor: AtelierColors.onSurface,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Day Details',
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AtelierColors.onSurface,
                  ),
                ),
                Text(
                  'Training structure',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AtelierColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          body: planAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AtelierColors.primary),
            ),
            error: (error, stackTrace) => const _DayStateMessage(
              message: 'GymUnity could not load this day right now.',
            ),
            data: (plan) {
              PlanDayEntity? day;
              if (plan != null) {
                for (final entry in plan.days) {
                  if (entry.id == dayId) {
                    day = entry;
                    break;
                  }
                }
              }

              if (plan == null || day == null) {
                return const _DayStateMessage(
                  message: 'This plan day is no longer available.',
                );
              }
              final resolvedDay = day;
              Duration revealDelay(int index) =>
                  Duration(milliseconds: 40 + (index * 55));

              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
                  children: [
                    AppReveal(
                      delay: revealDelay(0),
                      child: _DayHeroCard(
                        day: resolvedDay,
                        planTitle: plan.planTitle,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppReveal(
                      delay: revealDelay(1),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _PrimaryGradientButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.activeWorkoutSession,
                            arguments: ActiveWorkoutSessionArgs(
                              planId: plan.planId,
                              dayId: resolvedDay.id,
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: 'Start guided workout',
                        ),
                      ),
                    ),
                    if (actionState.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      AppReveal(
                        delay: revealDelay(2),
                        child: _InlineErrorMessage(
                          message: actionState.errorMessage!,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ...resolvedDay.tasks.asMap().entries.map(
                      (entry) => AppReveal(
                        delay: revealDelay(entry.key + 3),
                        child: _TaskDetailCard(
                          task: entry.value,
                          isUpdating: actionState.isUpdatingTask,
                          onComplete: () => _updateTask(
                            context,
                            ref,
                            entry.value,
                            TaskCompletionStatus.completed,
                            completionPercent: 100,
                          ),
                          onPartial: () => _updateTask(
                            context,
                            ref,
                            entry.value,
                            TaskCompletionStatus.partial,
                            completionPercent: 50,
                          ),
                          onSkip: () => _updateTask(
                            context,
                            ref,
                            entry.value,
                            TaskCompletionStatus.skipped,
                            completionPercent: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _updateTask(
    BuildContext context,
    WidgetRef ref,
    PlanTaskEntity task,
    TaskCompletionStatus status, {
    required int completionPercent,
  }) async {
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
    showAppFeedback(
      context,
      'Task status saved as ${status.label.toLowerCase()}.',
    );
  }
}

class _DayHeroCard extends StatelessWidget {
  const _DayHeroCard({required this.day, required this.planTitle});

  final PlanDayEntity day;
  final String planTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRAINING DAY',
            style: GoogleFonts.manrope(
              fontSize: 10,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w800,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            planTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            day.label,
            style: GoogleFonts.notoSerif(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.08,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatDate(day.scheduledDate)}${(day.focus ?? '').trim().isEmpty ? '' : ' - ${day.focus}'}',
            style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TaskMetaPill(label: '${day.tasks.length} tasks'),
              _TaskMetaPill(label: 'Week ${day.weekNumber}'),
              _TaskMetaPill(label: 'Day ${day.dayNumber}'),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _TaskDetailCard extends StatelessWidget {
  const _TaskDetailCard({
    required this.task,
    required this.isUpdating,
    required this.onComplete,
    required this.onPartial,
    required this.onSkip,
  });

  final PlanTaskEntity task;
  final bool isUpdating;
  final VoidCallback onComplete;
  final VoidCallback onPartial;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AtelierColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.instructions,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        height: 1.58,
                        fontWeight: FontWeight.w500,
                        color: AtelierColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _TaskStatusBadge(status: task.completionStatus),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (task.scheduledTime != null && task.scheduledTime!.isNotEmpty)
                _TaskMetaPill(label: 'Scheduled ${task.scheduledTime}'),
              if (task.reminderTime != null && task.reminderTime!.isNotEmpty)
                _TaskMetaPill(label: 'Reminder ${task.reminderTime}'),
              if (task.durationMinutes != null)
                _TaskMetaPill(label: '${task.durationMinutes} min'),
              if (task.sets != null) _TaskMetaPill(label: '${task.sets} sets'),
              if (task.reps != null) _TaskMetaPill(label: '${task.reps} reps'),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final skipButton = _TaskActionButton(
                label: 'Skip',
                onPressed: isUpdating ? null : onSkip,
              );
              final partialButton = _TaskActionButton(
                label: 'Partial',
                onPressed: isUpdating ? null : onPartial,
              );
              final completeButton = _TaskActionButton(
                label: 'Complete',
                onPressed: isUpdating ? null : onComplete,
                primary: true,
              );

              if (constraints.maxWidth < 320) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    skipButton,
                    const SizedBox(height: 10),
                    partialButton,
                    const SizedBox(height: 10),
                    completeButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: skipButton),
                  const SizedBox(width: 10),
                  Expanded(child: partialButton),
                  const SizedBox(width: 10),
                  Expanded(child: completeButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TaskActionButton extends StatelessWidget {
  const _TaskActionButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = primary
        ? AtelierColors.primary
        : AtelierColors.surfaceContainerLowest;
    final foregroundColor = primary
        ? AtelierColors.onPrimary
        : AtelierColors.onSurface;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledForegroundColor: AtelierColors.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

class _TaskMetaPill extends StatelessWidget {
  const _TaskMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AtelierColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TaskStatusBadge extends StatelessWidget {
  const _TaskStatusBadge({required this.status});

  final TaskCompletionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TaskCompletionStatus.completed => AtelierColors.success,
      TaskCompletionStatus.partial => AtelierColors.primary,
      TaskCompletionStatus.skipped => AtelierColors.primaryContainer,
      TaskCompletionStatus.missed => AtelierColors.error,
      TaskCompletionStatus.pending => AtelierColors.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
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

class _InlineErrorMessage extends StatelessWidget {
  const _InlineErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
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

class _DayStateMessage extends StatelessWidget {
  const _DayStateMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
