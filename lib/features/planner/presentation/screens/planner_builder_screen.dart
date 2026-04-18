import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_reveal.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../../domain/entities/planner_builder_entities.dart';
import '../providers/planner_builder_providers.dart';
import '../route_args.dart';
import '../widgets/planner_builder_controls.dart';

class PlannerBuilderScreen extends ConsumerStatefulWidget {
  const PlannerBuilderScreen({
    super.key,
    this.seedPrompt,
    this.existingSessionId,
  });

  final String? seedPrompt;
  final String? existingSessionId;

  @override
  ConsumerState<PlannerBuilderScreen> createState() =>
      _PlannerBuilderScreenState();
}

class _PlannerBuilderScreenState extends ConsumerState<PlannerBuilderScreen> {
  bool _startedFromArgs = false;

  @override
  void initState() {
    super.initState();
    if ((widget.existingSessionId ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _startedFromArgs) {
          return;
        }
        _startedFromArgs = true;
        ref
            .read(plannerBuilderControllerProvider.notifier)
            .start(
              seedPrompt: widget.seedPrompt,
              existingSessionId: widget.existingSessionId,
            );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(plannerBuilderControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'AI Builder',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: AppShellBackground(
          topGlowColor: AppColors.glowOrange,
          bottomGlowColor: AppColors.glowBlue,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _bodyForState(state),
          ),
        ),
      ),
    );
  }

  Widget _bodyForState(PlannerBuilderState state) {
    switch (state.phase) {
      case PlannerBuilderPhase.idle:
        return _StartBuilderView(
          key: const ValueKey<String>('planner-builder-start'),
          seedPrompt: widget.seedPrompt,
          onStart: () => ref
              .read(plannerBuilderControllerProvider.notifier)
              .start(
                seedPrompt: widget.seedPrompt,
                existingSessionId: widget.existingSessionId,
              ),
        );
      case PlannerBuilderPhase.scanning:
        return const _BusyBuilderView(
          key: ValueKey<String>('planner-builder-scanning'),
          title: 'Reading your fitness context',
          description:
              'GymUnity is checking your profile, preferences, progress, workout history, and active plans before asking anything.',
        );
      case PlannerBuilderPhase.generating:
        return const _BusyBuilderView(
          key: ValueKey<String>('planner-builder-generating'),
          title: 'Building your plan',
          description:
              'TAIYO is using your guided answers and saved member context to create a structured draft.',
        );
      case PlannerBuilderPhase.error:
        return _ErrorBuilderView(
          key: const ValueKey<String>('planner-builder-error'),
          message: state.errorMessage ?? 'GymUnity could not open AI Builder.',
          onRetry: () => ref
              .read(plannerBuilderControllerProvider.notifier)
              .start(
                seedPrompt: widget.seedPrompt,
                existingSessionId: widget.existingSessionId,
              ),
        );
      case PlannerBuilderPhase.draftReady:
        return _BusyBuilderView(
          key: const ValueKey<String>('planner-builder-ready'),
          title: 'Plan ready',
          description: 'Opening your review screen now.',
          onVisible: () {
            final sessionId = state.sessionId;
            final draftId = state.draftId;
            if (sessionId == null || draftId == null) {
              return;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              Navigator.pushReplacementNamed(
                context,
                AppRoutes.aiGeneratedPlan,
                arguments: AiGeneratedPlanArgs(
                  sessionId: sessionId,
                  draftId: draftId,
                ),
              );
            });
          },
        );
      case PlannerBuilderPhase.questioning:
        return _QuestioningView(
          key: const ValueKey<String>('planner-builder-questioning'),
          state: state,
          onChanged: ref
              .read(plannerBuilderControllerProvider.notifier)
              .answerCurrent,
          onBack: ref.read(plannerBuilderControllerProvider.notifier).back,
          onNext: ref.read(plannerBuilderControllerProvider.notifier).next,
        );
      case PlannerBuilderPhase.answerReview:
        return _AnswerReviewView(
          key: const ValueKey<String>('planner-builder-review'),
          state: state,
          onBack: ref.read(plannerBuilderControllerProvider.notifier).back,
          onEdit: ref.read(plannerBuilderControllerProvider.notifier).editField,
          onGenerate: _generateDraft,
        );
    }
  }

  Future<void> _generateDraft() async {
    final result = await ref
        .read(plannerBuilderControllerProvider.notifier)
        .generateDraft();
    if (!mounted) {
      return;
    }
    if (result == null) {
      final state = ref.read(plannerBuilderControllerProvider);
      if ((state.noticeMessage ?? '').trim().isNotEmpty) {
        showAppFeedback(context, state.noticeMessage!);
      } else if ((state.errorMessage ?? '').trim().isNotEmpty) {
        showAppFeedback(context, state.errorMessage!);
      }
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.aiGeneratedPlan,
      arguments: AiGeneratedPlanArgs(
        sessionId: result.sessionId,
        draftId: result.draftId,
      ),
    );
  }
}

class _StartBuilderView extends StatelessWidget {
  const _StartBuilderView({
    super.key,
    required this.seedPrompt,
    required this.onStart,
  });

  final String? seedPrompt;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final hasSeed = (seedPrompt ?? '').trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        const SizedBox(height: 28),
        AppReveal(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: const Icon(
                    Icons.route_outlined,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Build a smarter plan',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.02,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'AI Builder reads your existing GymUnity profile first, then asks only the details that improve your workout plan.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (hasSeed) ...[
                  const SizedBox(height: 16),
                  _SeedPromptCard(seedPrompt: seedPrompt!.trim()),
                ],
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  key: const ValueKey<String>('planner-builder-start-button'),
                  onPressed: onStart,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Start builder'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const AppReveal(
          delay: Duration(milliseconds: 80),
          child: PlannerBuilderNoticeCard(
            icon: Icons.manage_search_outlined,
            title: 'No chat needed',
            description:
                'You will answer in guided steps using choices, sliders, and quick selections. Text input is only used when it is really helpful.',
          ),
        ),
      ],
    );
  }
}

class _QuestioningView extends StatelessWidget {
  const _QuestioningView({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onBack,
    required this.onNext,
  });

  final PlannerBuilderState state;
  final ValueChanged<Object?> onChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final question = state.currentQuestion;
    if (question == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        PlannerBuilderProgressHeader(
          stepNumber: state.stepNumber,
          totalSteps: state.totalSteps,
          progress: state.progress,
        ),
        if ((state.noticeMessage ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _InlineNotice(message: state.noticeMessage!),
        ],
        const SizedBox(height: 18),
        AppReveal(
          child: PlannerBuilderQuestionCard(
            question: question,
            answer: state.answers[question.field],
            onChanged: onChanged,
          ),
        ),
        if ((state.errorMessage ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            state.errorMessage!,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
          ),
        ],
        const SizedBox(height: 20),
        _BottomActions(
          primaryLabel: state.stepNumber == state.totalSteps
              ? 'Review answers'
              : 'Next',
          primaryEnabled: state.canGoNext,
          onPrimary: onNext,
          secondaryLabel: state.canGoBack ? 'Back' : null,
          onSecondary: state.canGoBack ? onBack : null,
        ),
      ],
    );
  }
}

class _AnswerReviewView extends StatelessWidget {
  const _AnswerReviewView({
    super.key,
    required this.state,
    required this.onBack,
    required this.onEdit,
    required this.onGenerate,
  });

  final PlannerBuilderState state;
  final VoidCallback onBack;
  final ValueChanged<PlannerBuilderField> onEdit;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final reviewFields = state.questions
        .where((question) {
          return question.inputKind != PlannerBuilderInputKind.notice &&
              state.answers[question.field]?.hasValue == true;
        })
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        Text(
          'Review your builder answers',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Adjust anything before TAIYO generates your draft plan.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: reviewFields
                .map(
                  (question) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PlannerBuilderSummaryTile(
                      label: _fieldLabel(question.field),
                      value: _answerDisplayValue(
                        state.answers[question.field]!,
                        question,
                      ),
                      onTap: () => onEdit(question.field),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        if ((state.errorMessage ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            state.errorMessage!,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.error),
          ),
        ],
        const SizedBox(height: 20),
        _BottomActions(
          primaryLabel: 'Generate plan',
          primaryEnabled: state.hasCriticalAnswers,
          onPrimary: onGenerate,
          secondaryLabel: 'Back',
          onSecondary: onBack,
        ),
      ],
    );
  }
}

class _BusyBuilderView extends StatelessWidget {
  const _BusyBuilderView({
    super.key,
    required this.title,
    required this.description,
    this.onVisible,
  });

  final String title;
  final String description;
  final VoidCallback? onVisible;

  @override
  Widget build(BuildContext context) {
    onVisible?.call();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: PlannerBuilderNoticeCard(
          icon: Icons.auto_awesome,
          title: title,
          description: description,
        ),
      ),
    );
  }
}

class _ErrorBuilderView extends StatelessWidget {
  const _ErrorBuilderView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: PlannerBuilderNoticeCard(
          icon: Icons.cloud_off_outlined,
          title: 'AI Builder needs a retry',
          description: message,
          actionLabel: 'Try again',
          onAction: onRetry,
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String primaryLabel;
  final bool primaryEnabled;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (secondaryLabel != null && onSecondary != null) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel!),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: primaryEnabled ? onPrimary : null,
            child: Text(primaryLabel),
          ),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SeedPromptCard extends StatelessWidget {
  const _SeedPromptCard({required this.seedPrompt});

  final String seedPrompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        seedPrompt,
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.45,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

String _fieldLabel(PlannerBuilderField field) {
  switch (field) {
    case PlannerBuilderField.goal:
      return 'Goal';
    case PlannerBuilderField.experienceLevel:
      return 'Experience';
    case PlannerBuilderField.daysPerWeek:
      return 'Training days';
    case PlannerBuilderField.sessionMinutes:
      return 'Session length';
    case PlannerBuilderField.trainingLocation:
      return 'Location';
    case PlannerBuilderField.equipment:
      return 'Equipment';
    case PlannerBuilderField.limitations:
      return 'Limitations';
    case PlannerBuilderField.cardioPreference:
      return 'Cardio';
    case PlannerBuilderField.workoutStyle:
      return 'Style';
    case PlannerBuilderField.focusAreas:
      return 'Focus areas';
    case PlannerBuilderField.preferredDays:
      return 'Preferred days';
    case PlannerBuilderField.intensity:
      return 'Intensity';
    case PlannerBuilderField.dislikes:
      return 'Dislikes';
    case PlannerBuilderField.activePlanNotice:
      return 'Active plan';
  }
}

String _answerDisplayValue(
  PlannerBuilderAnswer answer,
  PlannerBuilderQuestion question,
) {
  if (answer.label?.trim().isNotEmpty == true) {
    return answer.label!;
  }
  if (answer.value is Iterable && answer.value is! String) {
    return answer.stringListValue
        .map((value) {
          for (final option in question.options) {
            if (option.value == value) {
              return option.label;
            }
          }
          return value.replaceAll('_', ' ');
        })
        .join(', ');
  }
  for (final option in question.options) {
    if (option.value == answer.stringValue) {
      return option.label;
    }
  }
  if (question.inputKind == PlannerBuilderInputKind.slider &&
      answer.intValue != null) {
    return '${answer.intValue}${question.valueSuffix}';
  }
  return answer.stringValue?.replaceAll('_', ' ') ?? 'Not set';
}
