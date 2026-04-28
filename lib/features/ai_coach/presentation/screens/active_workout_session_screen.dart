import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/atelier_theme.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../planner/domain/entities/planner_entities.dart';
import '../../domain/entities/ai_coach_entities.dart';
import '../providers/ai_coach_providers.dart';

class ActiveWorkoutSessionScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutSessionScreen({
    super.key,
    this.sessionId,
    this.planId,
    this.dayId,
  });

  final String? sessionId;
  final String? planId;
  final String? dayId;

  @override
  ConsumerState<ActiveWorkoutSessionScreen> createState() =>
      _ActiveWorkoutSessionScreenState();
}

class _ActiveWorkoutSessionScreenState
    extends ConsumerState<ActiveWorkoutSessionScreen> {
  int _difficultyScore = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sessionId = await ref
          .read(activeWorkoutCompanionControllerProvider.notifier)
          .ensureSession(
            sessionId: widget.sessionId,
            planId: widget.planId,
            dayId: widget.dayId,
            targetDate: DateTime.now(),
          );
      if (sessionId != null) {
        await ref
            .read(activeWorkoutCompanionControllerProvider.notifier)
            .refreshPrompt(promptKind: 'session_started');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final companionState = ref.watch(activeWorkoutCompanionControllerProvider);
    final sessionId = companionState.sessionId ?? widget.sessionId;

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
          body: SafeArea(
            child: sessionId == null
                ? _SessionStateView(
                    isLoading: companionState.isLoading,
                    message:
                        companionState.errorMessage ??
                        'GymUnity could not open the guided workout session.',
                    onBack: () => Navigator.maybePop(context),
                  )
                : ref
                      .watch(activeWorkoutSessionProvider(sessionId))
                      .when(
                        loading: () => _SessionStateView(
                          isLoading: true,
                          message: 'Preparing your guided ritual.',
                          onBack: () => Navigator.maybePop(context),
                        ),
                        error: (error, stackTrace) => _SessionStateView(
                          message: error.toString(),
                          onBack: () => Navigator.maybePop(context),
                        ),
                        data: (session) {
                          if (session == null) {
                            return _SessionStateView(
                              message:
                                  'This active workout session no longer exists.',
                              onBack: () => Navigator.maybePop(context),
                            );
                          }

                          final prompt = companionState.latestPrompt;
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
                            children: [
                              _TopBar(
                                onBack: () => Navigator.maybePop(context),
                                onPrompt: () => ref
                                    .read(
                                      activeWorkoutCompanionControllerProvider
                                          .notifier,
                                    )
                                    .refreshPrompt(),
                              ),
                              const SizedBox(height: 28),
                              _SessionHero(session: session, prompt: prompt),
                              const SizedBox(height: 32),
                              _SectionHeading(
                                title: 'Session Flow',
                                subtitle:
                                    'Move through the work with calm precision',
                              ),
                              const SizedBox(height: 16),
                              _SessionControlRow(
                                onShorten: () => _shortenWorkout(session),
                                onSwap: session.tasks.isEmpty
                                    ? null
                                    : () => _swapExercise(
                                        session.tasks.first.taskId,
                                      ),
                                onPrompt: () => ref
                                    .read(
                                      activeWorkoutCompanionControllerProvider
                                          .notifier,
                                    )
                                    .refreshPrompt(),
                              ),
                              const SizedBox(height: 28),
                              for (
                                var index = 0;
                                index < session.tasks.length;
                                index++
                              ) ...[
                                _ActiveTaskCard(
                                  task: session.tasks[index],
                                  index: index,
                                  selectedStatus: _taskStatus(
                                    companionState,
                                    session.tasks[index].taskId,
                                  ),
                                  onStatusChanged: (status) => ref
                                      .read(
                                        activeWorkoutCompanionControllerProvider
                                            .notifier,
                                      )
                                      .markTask(
                                        session.tasks[index].taskId,
                                        status,
                                      ),
                                  onSwap: () => _swapExercise(
                                    session.tasks[index].taskId,
                                  ),
                                ),
                                if (index != session.tasks.length - 1)
                                  const SizedBox(height: 18),
                              ],
                              if (session.tasks.isEmpty)
                                const _EmptyFlowPanel(),
                              const SizedBox(height: 36),
                              _CompletionCard(
                                difficultyScore: _difficultyScore,
                                onDifficultyChanged: (value) =>
                                    setState(() => _difficultyScore = value),
                                isCompleting: companionState.isCompleting,
                                onComplete: () => _completeWorkout(sessionId),
                              ),
                              if (companionState.errorMessage != null) ...[
                                const SizedBox(height: 14),
                                _ErrorPanel(
                                  message: companionState.errorMessage!,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
          ),
        ),
      ),
    );
  }

  TaskCompletionStatus _taskStatus(
    ActiveWorkoutCompanionState state,
    String taskId,
  ) {
    if (state.completedTaskIds.contains(taskId)) {
      return TaskCompletionStatus.completed;
    }
    if (state.partialTaskIds.contains(taskId)) {
      return TaskCompletionStatus.partial;
    }
    if (state.skippedTaskIds.contains(taskId)) {
      return TaskCompletionStatus.skipped;
    }
    return TaskCompletionStatus.pending;
  }

  Future<void> _shortenWorkout(ActiveWorkoutSessionEntity session) async {
    await ref
        .read(activeWorkoutCompanionControllerProvider.notifier)
        .shortenWorkout();
    if (!mounted) {
      return;
    }
    showAppFeedback(
      context,
      'TAIYO trimmed the session to the highest-value work.',
    );
    ref.invalidate(activeWorkoutSessionProvider(session.id));
  }

  Future<void> _swapExercise(String taskId) async {
    await ref
        .read(activeWorkoutCompanionControllerProvider.notifier)
        .swapExercise(taskId);
    if (!mounted) {
      return;
    }
    showAppFeedback(context, 'TAIYO swapped the movement to fit today better.');
  }

  Future<void> _completeWorkout(String sessionId) async {
    final completed = await ref
        .read(activeWorkoutCompanionControllerProvider.notifier)
        .completeSession(difficultyScore: _difficultyScore);
    if (!mounted || completed == null) {
      if (mounted) {
        showAppFeedback(context, 'GymUnity could not complete this workout.');
      }
      return;
    }
    final prompt = await ref
        .read(aiCoachRepositoryProvider)
        .getWorkoutPrompt(sessionId: sessionId, promptKind: 'post_workout');
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return _CompletionDialog(
          message:
              prompt['message'] as String? ??
              'Nice work. Hydrate, get protein in, and keep your recovery simple tonight.',
        );
      },
    );
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onPrompt});

  final VoidCallback onBack;
  final VoidCallback onPrompt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundAction(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'TAIYO',
            style: GoogleFonts.notoSerif(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: AtelierColors.onSurface,
            ),
          ),
        ),
        _RoundAction(icon: Icons.auto_awesome_rounded, onTap: onPrompt),
      ],
    );
  }
}

class _SessionHero extends StatelessWidget {
  const _SessionHero({required this.session, required this.prompt});

  final ActiveWorkoutSessionEntity session;
  final Map<String, dynamic> prompt;

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
            'ACTIVE RITUAL',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            session.dayLabel,
            style: GoogleFonts.notoSerif(
              fontSize: 42,
              height: 0.98,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            session.planTitle,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          if (session.dayFocus.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              session.dayFocus,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.6,
                color: AtelierColors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: '${session.plannedMinutes} min'),
              if (session.readinessScore != null)
                _Pill(label: 'Readiness ${session.readinessScore}'),
              if (session.paceDeltaPercent != null)
                _Pill(
                  label:
                      '${session.paceDeltaPercent!.toStringAsFixed(0)}% pace',
                ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              color: AtelierColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              prompt['message'] as String? ??
                  session.whyShort.ifEmpty(
                    'TAIYO is pacing this session around your plan, readiness, and recent workload.',
                  ),
              style: GoogleFonts.manrope(
                fontSize: 14,
                height: 1.75,
                fontWeight: FontWeight.w500,
                color: AtelierColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.notoSerif(
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurface,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.manrope(
                fontSize: 12,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: AtelierColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionControlRow extends StatelessWidget {
  const _SessionControlRow({
    required this.onShorten,
    required this.onSwap,
    required this.onPrompt,
  });

  final VoidCallback onShorten;
  final VoidCallback? onSwap;
  final VoidCallback onPrompt;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SoftActionPill(
          icon: Icons.auto_awesome_rounded,
          label: 'New prompt',
          onTap: onPrompt,
          selected: true,
        ),
        _SoftActionPill(
          icon: Icons.compress_rounded,
          label: 'Shorten',
          onTap: onShorten,
        ),
        _SoftActionPill(
          icon: Icons.swap_horiz_rounded,
          label: 'Swap',
          onTap: onSwap,
        ),
      ],
    );
  }
}

class _ActiveTaskCard extends StatelessWidget {
  const _ActiveTaskCard({
    required this.task,
    required this.index,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onSwap,
  });

  final ActiveWorkoutTaskEntity task;
  final int index;
  final TaskCompletionStatus selectedStatus;
  final ValueChanged<TaskCompletionStatus> onStatusChanged;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final offset = index.isEven
        ? const EdgeInsets.only(right: 22)
        : EdgeInsets.zero;
    return Padding(
      padding: offset,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: index.isEven
              ? AtelierColors.surfaceContainerLow
              : AtelierColors.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
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
                        'STEP ${index + 1}',
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                          color: AtelierColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task.title,
                        style: GoogleFonts.notoSerif(
                          fontSize: 24,
                          height: 1.08,
                          fontWeight: FontWeight.w500,
                          color: AtelierColors.onSurface,
                        ),
                      ),
                      if ((task.blockLabel ?? '').isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          task.blockLabel!,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AtelierColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _RoundAction(
                  icon: Icons.swap_horiz_rounded,
                  onTap: onSwap,
                  surface: AtelierColors.surfaceContainerLowest,
                ),
              ],
            ),
            if (task.instructions.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                task.instructions,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (task.durationMinutes != null)
                  _Pill(label: '${task.durationMinutes} min'),
                if (task.sets != null) _Pill(label: '${task.sets} sets'),
                if (task.reps != null) _Pill(label: '${task.reps} reps'),
                if (task.restSeconds != null)
                  _Pill(label: 'Rest ${task.restSeconds}s'),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in const <TaskCompletionStatus>[
                  TaskCompletionStatus.completed,
                  TaskCompletionStatus.partial,
                  TaskCompletionStatus.skipped,
                ])
                  _StatusChip(
                    label: status.label,
                    selected: selectedStatus == status,
                    onTap: () => onStatusChanged(status),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({
    required this.difficultyScore,
    required this.onDifficultyChanged,
    required this.isCompleting,
    required this.onComplete,
  });

  final int difficultyScore;
  final ValueChanged<int> onDifficultyChanged;
  final bool isCompleting;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finish with context',
            style: GoogleFonts.notoSerif(
              fontSize: 30,
              height: 1.08,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Rate the ritual so TAIYO can adapt future sessions safely.',
            style: GoogleFonts.manrope(
              fontSize: 13,
              height: 1.65,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              10,
              (index) => _StatusChip(
                label: '${index + 1}',
                selected: difficultyScore == index + 1,
                onTap: () => onDifficultyChanged(index + 1),
                compact: true,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _GradientButton(
            icon: isCompleting ? null : Icons.check_circle_outline_rounded,
            isLoading: isCompleting,
            label: 'Complete workout',
            onTap: isCompleting ? null : onComplete,
          ),
        ],
      ),
    );
  }
}

class _SessionStateView extends StatelessWidget {
  const _SessionStateView({
    required this.message,
    required this.onBack,
    this.isLoading = false,
  });

  final String message;
  final VoidCallback onBack;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(onBack: onBack, onPrompt: () {}),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            decoration: BoxDecoration(
              color: AtelierColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AtelierColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  isLoading ? 'Preparing TAIYO' : 'Session paused',
                  style: GoogleFonts.notoSerif(
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: AtelierColors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    height: 1.7,
                    fontWeight: FontWeight.w500,
                    color: AtelierColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _CompletionDialog extends StatelessWidget {
  const _CompletionDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Dialog(
        backgroundColor: AtelierColors.glass,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout complete',
                style: GoogleFonts.notoSerif(
                  fontSize: 32,
                  height: 1.05,
                  fontWeight: FontWeight.w500,
                  color: AtelierColors.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  height: 1.7,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              _GradientButton(
                label: 'Close',
                icon: Icons.done_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFlowPanel extends StatelessWidget {
  const _EmptyFlowPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        'No session steps were attached to this workout yet.',
        style: GoogleFonts.manrope(
          fontSize: 13,
          height: 1.65,
          color: AtelierColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        style: GoogleFonts.manrope(
          fontSize: 12,
          height: 1.55,
          fontWeight: FontWeight.w600,
          color: AtelierColors.error,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: enabled ? null : AtelierColors.surfaceContainer,
            gradient: enabled
                ? LinearGradient(colors: AtelierColors.primaryGradient)
                : null,
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AtelierColors.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: AtelierColors.onPrimary),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: enabled
                              ? AtelierColors.onPrimary
                              : AtelierColors.onSurfaceVariant,
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

class _SoftActionPill extends StatelessWidget {
  const _SoftActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final background = selected
        ? AtelierColors.primary
        : AtelierColors.surfaceContainer;
    final foreground = selected
        ? AtelierColors.onPrimary
        : AtelierColors.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: onTap == null
                ? AtelierColors.surfaceContainerLow
                : background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: onTap == null ? AtelierColors.textMuted : foreground,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: onTap == null ? AtelierColors.textMuted : foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: compact ? 40 : null,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 13,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AtelierColors.primary
                : AtelierColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
              color: selected
                  ? AtelierColors.onPrimary
                  : AtelierColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AtelierColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.surface = AtelierColors.surfaceContainerLow,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AtelierColors.onSurfaceVariant),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
