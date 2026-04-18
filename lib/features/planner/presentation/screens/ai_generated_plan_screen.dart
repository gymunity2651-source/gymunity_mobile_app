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
import '../../../ai_chat/presentation/providers/chat_controller.dart';

class AiGeneratedPlanScreen extends ConsumerStatefulWidget {
  const AiGeneratedPlanScreen({
    super.key,
    required this.sessionId,
    required this.draftId,
  });

  final String sessionId;
  final String draftId;

  @override
  ConsumerState<AiGeneratedPlanScreen> createState() =>
      _AiGeneratedPlanScreenState();
}

class _AiGeneratedPlanScreenState extends ConsumerState<AiGeneratedPlanScreen> {
  late DateTime _selectedStartDate;
  late TimeOfDay _selectedReminderTime;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(plannerDraftProvider(widget.draftId));
    final actionState = ref.watch(plannerActionControllerProvider);
    final chatState = ref.watch(chatControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF130F0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF130F0B),
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Review AI Builder Plan',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
      body: draftAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (error, stackTrace) => _PlannerStateCard(
          icon: Icons.cloud_off_outlined,
          title: 'Unable to load this draft',
          description:
              'GymUnity could not refresh the TAIYO plan review data right now.',
          primaryLabel: 'Retry',
          onPrimaryTap: () =>
              ref.invalidate(plannerDraftProvider(widget.draftId)),
        ),
        data: (draft) {
          if (draft == null) {
            return _PlannerStateCard(
              icon: Icons.auto_awesome_outlined,
              title: 'Draft not found',
              description:
                  'This AI Builder draft is no longer available. Open the guided builder to generate a new plan.',
              primaryLabel: 'Open AI Builder',
              onPrimaryTap: () => Navigator.pushNamed(
                context,
                AppRoutes.aiPlannerBuilder,
                arguments: PlannerBuilderArgs(
                  existingSessionId: widget.sessionId,
                ),
              ),
            );
          }

          final plan = draft.plan;
          if (!_initialized) {
            _initialized = true;
            _selectedStartDate =
                plan?.startDateSuggestion ??
                DateTime.now().add(const Duration(days: 1));
            _selectedReminderTime = _timeFromString(
              _initialReminderTime(plan) ?? '07:00',
            );
          }

          if (plan == null) {
            return _PlannerStateCard(
              icon: Icons.chat_bubble_outline,
              title: 'Plan still needs more detail',
              description: draft.assistantMessage.isEmpty
                  ? 'Continue the guided builder so GymUnity can gather the remaining details.'
                  : draft.assistantMessage,
              primaryLabel: 'Continue builder',
              onPrimaryTap: () => Navigator.pushNamed(
                context,
                AppRoutes.aiPlannerBuilder,
                arguments: PlannerBuilderArgs(
                  existingSessionId: widget.sessionId,
                ),
              ),
            );
          }

          final previewDays = plan.weeklyStructure
              .expand((week) => week.days)
              .take(6)
              .toList(growable: false);
          Duration revealDelay(int index) =>
              Duration(milliseconds: 40 + (index * 55));

          return ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              AppReveal(
                delay: revealDelay(0),
                child: _PlannerHeroCard(
                  title: plan.title,
                  summary: plan.summary,
                  status: draft.status,
                  durationWeeks: plan.durationWeeks,
                  level: plan.level,
                ),
              ),
              if (draft.missingFields.isNotEmpty) ...[
                const SizedBox(height: 16),
                AppReveal(
                  delay: revealDelay(1),
                  child: _MissingInfoCard(fields: draft.missingFields),
                ),
              ],
              const SizedBox(height: 16),
              AppReveal(
                delay: revealDelay(2),
                child: _SelectionCard(
                  title: 'Activation settings',
                  child: Column(
                    children: [
                      _SelectionTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'Start date',
                        value: _formatDate(_selectedStartDate),
                        onTap: _pickStartDate,
                      ),
                      const SizedBox(height: 12),
                      _SelectionTile(
                        icon: Icons.alarm_outlined,
                        label: 'Default reminder',
                        value: _formatTimeOfDay(_selectedReminderTime),
                        onTap: _pickReminderTime,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppReveal(
                delay: revealDelay(3),
                child: _SelectionCard(
                  title: 'Plan highlights',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((plan.restGuidance ?? '').trim().isNotEmpty)
                        _GuidanceLine(
                          label: 'Recovery',
                          value: plan.restGuidance!.trim(),
                        ),
                      if ((plan.nutritionGuidance ?? '').trim().isNotEmpty)
                        _GuidanceLine(
                          label: 'Nutrition',
                          value: plan.nutritionGuidance!.trim(),
                        ),
                      if ((plan.hydrationGuidance ?? '').trim().isNotEmpty)
                        _GuidanceLine(
                          label: 'Hydration',
                          value: plan.hydrationGuidance!.trim(),
                        ),
                      if ((plan.sleepGuidance ?? '').trim().isNotEmpty)
                        _GuidanceLine(
                          label: 'Sleep',
                          value: plan.sleepGuidance!.trim(),
                        ),
                      if ((plan.stepTarget ?? '').trim().isNotEmpty)
                        _GuidanceLine(
                          label: 'Steps',
                          value: plan.stepTarget!.trim(),
                        ),
                      if (plan.safetyNotes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Safety notes',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...plan.safetyNotes.map(_SafetyNote.new),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppReveal(
                delay: revealDelay(4),
                child: _SelectionCard(
                  title: 'Weekly structure preview',
                  child: Column(
                    children: previewDays
                        .map(
                          (day) => _PlanPreviewDayCard(
                            day: day,
                            reminderTime: _formatTimeForTasks(day.tasks),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (actionState.errorMessage != null)
                AppReveal(
                  delay: revealDelay(5),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      actionState.errorMessage!,
                      style: GoogleFonts.inter(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              AppReveal(
                delay: revealDelay(6),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: chatState.isRegenerating
                            ? null
                            : _regenerateDraft,
                        child: Text(
                          chatState.isRegenerating
                              ? 'Improving...'
                              : 'Improve plan',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.aiPlannerBuilder,
                          arguments: PlannerBuilderArgs(
                            existingSessionId: widget.sessionId,
                          ),
                        ),
                        child: const Text('Edit builder answers'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppReveal(
                delay: revealDelay(7),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: actionState.isActivating ? null : _activateDraft,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.white,
                    ),
                    child: Text(
                      actionState.isActivating
                          ? 'Activating plan...'
                          : 'Approve and activate',
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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _selectedStartDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedStartDate = picked);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedReminderTime,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedReminderTime = picked);
  }

  Future<void> _regenerateDraft() async {
    final result = await ref
        .read(chatControllerProvider.notifier)
        .regeneratePlan(sessionId: widget.sessionId, draftId: widget.draftId);
    ref.invalidate(plannerDraftProvider(widget.draftId));
    ref.invalidate(latestPlannerDraftProvider(widget.sessionId));
    if (!mounted) {
      return;
    }
    if (result == null) {
      showAppFeedback(
        context,
        ref.read(chatControllerProvider).errorMessage ??
            'GymUnity could not regenerate the plan right now.',
      );
      return;
    }
    final nextDraftId = result.draftId ?? widget.draftId;
    if (nextDraftId != widget.draftId) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.aiGeneratedPlan,
        arguments: AiGeneratedPlanArgs(
          sessionId: widget.sessionId,
          draftId: nextDraftId,
        ),
      );
      return;
    }
    showAppFeedback(context, 'The AI Builder plan draft has been refreshed.');
  }

  Future<void> _activateDraft() async {
    final activation = await ref
        .read(plannerActionControllerProvider.notifier)
        .activateDraft(
          draftId: widget.draftId,
          startDate: _selectedStartDate,
          reminderTime: _formatTimeOfDay(_selectedReminderTime),
        );
    if (!mounted) {
      return;
    }
    if (activation == null) {
      showAppFeedback(
        context,
        ref.read(plannerActionControllerProvider).errorMessage ??
            'GymUnity could not activate this plan right now.',
      );
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.workoutPlan,
      (route) => route.settings.name == AppRoutes.memberHome,
      arguments: WorkoutPlanArgs(planId: activation.planId),
    );
  }

  TimeOfDay _timeFromString(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return TimeOfDay(hour: hour ?? 7, minute: minute ?? 0);
  }

  String _formatDate(DateTime value) {
    final month = _monthLabel(value.month);
    return '$month ${value.day}, ${value.year}';
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeForTasks(List<GeneratedPlanTaskEntity> tasks) {
    for (final task in tasks) {
      final reminder = task.reminderTime?.trim();
      if (reminder != null && reminder.isNotEmpty) {
        return reminder;
      }
    }
    return 'No reminder';
  }

  String? _initialReminderTime(GeneratedPlanEntity? plan) {
    if (plan == null) {
      return null;
    }
    for (final week in plan.weeklyStructure) {
      for (final day in week.days) {
        for (final task in day.tasks) {
          final reminder = task.reminderTime?.trim();
          if (reminder != null && reminder.isNotEmpty) {
            return reminder;
          }
        }
      }
    }
    return null;
  }

  String _monthLabel(int month) {
    const labels = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return labels[month - 1];
  }
}

class _PlannerHeroCard extends StatelessWidget {
  const _PlannerHeroCard({
    required this.title,
    required this.summary,
    required this.status,
    required this.durationWeeks,
    required this.level,
  });

  final String title;
  final String summary;
  final String status;
  final int durationWeeks;
  final String level;

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                label: status.replaceAll('_', ' '),
                color: AppColors.orange,
              ),
              _HeroPill(
                label: '$durationWeeks week${durationWeeks == 1 ? '' : 's'}',
              ),
              _HeroPill(label: level),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, this.color = AppColors.electricBlue});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF14100C),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
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

class _GuidanceLine extends StatelessWidget {
  const _GuidanceLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.shield_outlined,
              color: AppColors.orange,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPreviewDayCard extends StatelessWidget {
  const _PlanPreviewDayCard({required this.day, required this.reminderTime});

  final GeneratedPlanDayEntity day;
  final String reminderTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14100C),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Week ${day.weekNumber} - Day ${day.dayNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                  ),
                ),
              ),
              Text(
                reminderTime,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            day.label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (day.focus.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              day.focus,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...day.tasks
              .take(3)
              .map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '- ${task.title}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _MissingInfoCard extends StatelessWidget {
  const _MissingInfoCard({required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remaining inputs',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fields
                .map(
                  (field) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Text(
                      field.replaceAll('_', ' '),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _PlannerStateCard extends StatelessWidget {
  const _PlannerStateCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPrimaryTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
            border: Border.all(color: AppColors.border),
          ),
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
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onPrimaryTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.white,
                ),
                child: Text(primaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
