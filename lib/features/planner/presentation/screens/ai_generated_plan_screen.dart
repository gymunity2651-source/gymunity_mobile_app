import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/atelier_theme.dart';
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
          body: draftAsync.when(
            loading: () => const _PlannerLoadingState(),
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

              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
                  children: [
                    AppReveal(
                      delay: revealDelay(0),
                      child: const _ReviewTopBar(),
                    ),
                    const SizedBox(height: 28),
                    AppReveal(
                      delay: revealDelay(1),
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
                        delay: revealDelay(2),
                        child: _MissingInfoCard(fields: draft.missingFields),
                      ),
                    ],
                    const SizedBox(height: 32),
                    AppReveal(
                      delay: revealDelay(3),
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
                    const SizedBox(height: 28),
                    AppReveal(
                      delay: revealDelay(4),
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
                            if ((plan.nutritionGuidance ?? '')
                                .trim()
                                .isNotEmpty)
                              _GuidanceLine(
                                label: 'Nutrition',
                                value: plan.nutritionGuidance!.trim(),
                              ),
                            if ((plan.hydrationGuidance ?? '')
                                .trim()
                                .isNotEmpty)
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
                              const SizedBox(height: 18),
                              Text(
                                'Safety notes',
                                style: GoogleFonts.notoSerif(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AtelierColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...plan.safetyNotes.map(_SafetyNote.new),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppReveal(
                      delay: revealDelay(5),
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
                    const SizedBox(height: 28),
                    if (actionState.errorMessage != null)
                      AppReveal(
                        delay: revealDelay(6),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _InlineErrorMessage(
                            message: actionState.errorMessage!,
                          ),
                        ),
                      ),
                    AppReveal(
                      delay: revealDelay(7),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SecondaryPlanButton(
                              onPressed: chatState.isRegenerating
                                  ? null
                                  : _regenerateDraft,
                              label: chatState.isRegenerating
                                  ? 'Improving...'
                                  : 'Improve plan',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SecondaryPlanButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRoutes.aiPlannerBuilder,
                                arguments: PlannerBuilderArgs(
                                  existingSessionId: widget.sessionId,
                                ),
                              ),
                              label: 'Edit builder answers',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppReveal(
                      delay: revealDelay(8),
                      child: _PrimaryGradientButton(
                        onPressed: actionState.isActivating
                            ? null
                            : _activateDraft,
                        label: actionState.isActivating
                            ? 'Activating plan...'
                            : 'Approve and activate',
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

class _ReviewTopBar extends StatelessWidget {
  const _ReviewTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SoftIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onTap: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Review AI Builder Plan',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSerif(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: AtelierColors.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _SoftIconButton(
          icon: Icons.auto_awesome_outlined,
          tooltip: 'TAIYO plan review',
          onTap: () {},
        ),
      ],
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  const _SoftIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(icon, color: AtelierColors.onSurfaceVariant, size: 21),
        ),
      ),
    );
  }
}

class _PlannerLoadingState extends StatelessWidget {
  const _PlannerLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(
          color: AtelierColors.primary,
          strokeWidth: 3,
        ),
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TAIYO PLAN REVIEW',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.notoSerif(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.12,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            summary,
            style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.65,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(label: status.replaceAll('_', ' '), isPrimary: true),
              _HeroPill(
                label: '$durationWeeks week${durationWeeks == 1 ? '' : 's'}',
              ),
              _HeroPill(label: level),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, this.isPrimary = false});

  final String label;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPrimary
            ? AtelierColors.primary.withValues(alpha: 0.12)
            : AtelierColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: isPrimary
              ? AtelierColors.primary
              : AtelierColors.onSurfaceVariant,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSerif(
              color: AtelierColors.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 16),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standardCurve,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AtelierColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AtelierColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AtelierColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: AtelierColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.manrope(
                      color: AtelierColors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AtelierColors.onSurfaceVariant,
            ),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
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
                letterSpacing: 1.6,
                color: AtelierColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: AtelierColors.onSurfaceVariant,
              ),
            ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.shield_outlined,
              color: AtelierColors.primary,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.5,
                color: AtelierColors.onSurfaceVariant,
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Week ${day.weekNumber} - Day ${day.dayNumber}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AtelierColors.primary,
                  ),
                ),
              ),
              Text(
                reminderTime,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AtelierColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            day.label,
            style: GoogleFonts.notoSerif(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AtelierColors.onSurface,
            ),
          ),
          if (day.focus.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              day.focus,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AtelierColors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...day.tasks
              .take(3)
              .map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 7, right: 9),
                        decoration: const BoxDecoration(
                          color: AtelierColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          task.title,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: AtelierColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AtelierColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remaining inputs',
            style: GoogleFonts.notoSerif(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
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
                      color: AtelierColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      field.replaceAll('_', ' '),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AtelierColors.primary,
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
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AtelierColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 30, color: AtelierColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSerif(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  height: 1.16,
                  color: AtelierColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _PrimaryGradientButton(
                onPressed: onPrimaryTap,
                label: primaryLabel,
              ),
            ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AtelierColors.error.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: GoogleFonts.manrope(
          color: AtelierColors.error,
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SecondaryPlanButton extends StatefulWidget {
  const _SecondaryPlanButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  State<_SecondaryPlanButton> createState() => _SecondaryPlanButtonState();
}

class _SecondaryPlanButtonState extends State<_SecondaryPlanButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return AnimatedScale(
      scale: _pressed && enabled ? AppMotion.pressedScale : 1,
      duration: AppMotion.fast,
      curve: AppMotion.standardCurve,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standardCurve,
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: enabled
                ? AtelierColors.surfaceContainerLow
                : AtelierColors.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: enabled
                  ? AtelierColors.onSurface
                  : AtelierColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryGradientButton extends StatefulWidget {
  const _PrimaryGradientButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  State<_PrimaryGradientButton> createState() => _PrimaryGradientButtonState();
}

class _PrimaryGradientButtonState extends State<_PrimaryGradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return AnimatedScale(
      scale: _pressed && enabled ? AppMotion.pressedScale : 1,
      duration: AppMotion.fast,
      curve: AppMotion.standardCurve,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standardCurve,
          height: 54,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [
                      AtelierColors.primary,
                      AtelierColors.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : AtelierColors.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: AtelierColors.navShadow,
                      blurRadius: 40,
                      spreadRadius: -5,
                      offset: Offset(0, 10),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: enabled
                  ? AtelierColors.onPrimary
                  : AtelierColors.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
