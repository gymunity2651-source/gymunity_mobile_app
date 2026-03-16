import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_reveal.dart';
import '../../domain/entities/planner_entities.dart';
import '../providers/planner_providers.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFF130F0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF130F0B),
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Day Details',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
      body: planAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            child: Text(
              'GymUnity could not load this day right now.',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                child: Text(
                  'This plan day is no longer available.',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          Duration revealDelay(int index) =>
              Duration(milliseconds: 40 + (index * 55));

          return ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              AppReveal(
                delay: revealDelay(0),
                child: _DayHeroCard(day: day, planTitle: plan.planTitle),
              ),
              if (actionState.errorMessage != null) ...[
                const SizedBox(height: 12),
                AppReveal(
                  delay: revealDelay(1),
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
              ...day.tasks.asMap().entries.map(
                (entry) => AppReveal(
                  delay: revealDelay(entry.key + 2),
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
          );
        },
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF312015), Color(0xFF18110C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            planTitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w700,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            day.label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatDate(day.scheduledDate)}${(day.focus ?? '').trim().isEmpty ? '' : ' - ${day.focus}'}',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
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
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.instructions,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.textSecondary,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isUpdating ? null : onSkip,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: isUpdating ? null : onPartial,
                  child: const Text('Partial'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: isUpdating ? null : onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text('Complete'),
                ),
              ),
            ],
          ),
        ],
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
        color: const Color(0xFF14100C),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
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
