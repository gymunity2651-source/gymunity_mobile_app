import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../ai_chat/domain/entities/chat_session_entity.dart';
import '../../../ai_chat/presentation/providers/chat_controller.dart';
import '../../../ai_chat/presentation/providers/chat_providers.dart';
import '../../domain/entities/ai_coach_entities.dart';
import '../../../planner/presentation/route_args.dart';
import '../providers/ai_coach_providers.dart';

class AiCoachHomeScreen extends ConsumerStatefulWidget {
  const AiCoachHomeScreen({super.key});

  @override
  ConsumerState<AiCoachHomeScreen> createState() => _AiCoachHomeScreenState();
}

class _AiCoachHomeScreenState extends ConsumerState<AiCoachHomeScreen> {
  int _energyLevel = 3;
  int _sorenessLevel = 3;
  int _stressLevel = 3;
  int _availableMinutes = 45;
  String _locationMode = 'gym';

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final briefAsync = ref.watch(aiCoachDailyBriefProvider(today));
    final nudgesAsync = ref.watch(aiCoachNudgesProvider);
    final summaryAsync = ref.watch(
      aiWeeklySummaryProvider(_startOfWeek(today)),
    );
    final readinessState = ref.watch(aiCoachReadinessControllerProvider);
    final actionState = ref.watch(aiCoachActionControllerProvider);

    return Scaffold(
      backgroundColor: AtelierColors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: AtelierColors.surfaceContainerLowest,
        foregroundColor: AtelierColors.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TAIYO Coach',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
            ),
            Text(
              'Daily guidance in one screen',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AtelierColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open builder',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.aiPlannerBuilder),
            icon: const Icon(Icons.architecture_outlined),
          ),
          IconButton(
            tooltip: 'Open chat',
            onPressed: () => _openChat(
              prompt:
                  'Give me a quick coaching view of today and any adjustments I should make.',
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        color: AtelierColors.primary,
        onRefresh: () async {
          await ref.read(aiCoachBootProvider).refresh();
        },
        child: briefAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AtelierColors.primary),
          ),
          error: (error, stackTrace) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _CoachSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TAIYO couldn\'t load today\'s coach brief.',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AtelierColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        height: 1.5,
                        color: AtelierColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(aiCoachDailyBriefProvider(today)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          data: (brief) {
            if (brief == null) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _CoachSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No daily coach brief yet',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AtelierColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Open the builder or refresh TAIYO so today\'s recommendation can be prepared from your active training and nutrition data.',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            height: 1.5,
                            color: AtelierColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            final showRecap =
                DateTime.now().hour >= 18 ||
                brief.recapCompleted.isNotEmpty ||
                brief.recapMissed.isNotEmpty;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                _CoachHeroCard(
                  brief: brief,
                  isBusy:
                      actionState.isApplying || actionState.isStartingWorkout,
                  onStartWorkout: !_canUseRecommendedDay(brief)
                      ? null
                      : () => _startWorkout(brief),
                  onShortenWorkout: !_canUseRecommendedDay(brief)
                      ? null
                      : () => _applyAdjustment(
                          brief: brief,
                          type: 'shorten_workout',
                        ),
                  onSwapWorkout:
                      !_canUseRecommendedDay(brief) ||
                          !_hasUsableId(brief.primaryTaskId)
                      ? null
                      : () => _applyAdjustment(
                          brief: brief,
                          type: 'swap_exercise',
                          taskId: brief.primaryTaskId,
                        ),
                  onMoveToTomorrow: !_canUseRecommendedDay(brief)
                      ? null
                      : () => _applyAdjustment(
                          brief: brief,
                          type: 'move_to_tomorrow',
                        ),
                  onLogMeal: _openMealPlanQuickAdd,
                  onLogHydration: _openHydrationQuickLog,
                  onAskWhy: () => _openWhySheet(brief),
                ),
                const SizedBox(height: 16),
                _TaiyoCoachEntryCard(
                  onOpenBuilder: () =>
                      Navigator.pushNamed(context, AppRoutes.aiPlannerBuilder),
                  onOpenChat: () => _openChat(
                    prompt:
                        'Give me a quick coaching view of today and any adjustments I should make.',
                  ),
                ),
                const SizedBox(height: 16),
                _CoachSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s readiness',
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AtelierColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Energy, soreness, stress, time, and setup re-score today immediately.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          height: 1.5,
                          color: AtelierColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LevelSelector(
                        label: 'Energy',
                        value: _energyLevel,
                        onChanged: (value) =>
                            setState(() => _energyLevel = value),
                      ),
                      const SizedBox(height: 12),
                      _LevelSelector(
                        label: 'Soreness',
                        value: _sorenessLevel,
                        onChanged: (value) =>
                            setState(() => _sorenessLevel = value),
                      ),
                      const SizedBox(height: 12),
                      _LevelSelector(
                        label: 'Stress',
                        value: _stressLevel,
                        onChanged: (value) =>
                            setState(() => _stressLevel = value),
                      ),
                      const SizedBox(height: 12),
                      _MinuteSelector(
                        value: _availableMinutes,
                        onChanged: (value) =>
                            setState(() => _availableMinutes = value),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in const <String>[
                            'gym',
                            'home',
                            'outdoor',
                            'travel',
                          ])
                            ChoiceChip(
                              label: Text(option.toUpperCase()),
                              selected: option == _locationMode,
                              onSelected: (_) =>
                                  setState(() => _locationMode = option),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: readinessState.isSubmitting
                              ? null
                              : _submitReadiness,
                          icon: readinessState.isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.tune_rounded),
                          label: Text(
                            readinessState.isSubmitting
                                ? 'Updating TAIYO'
                                : 'Update today',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SignalCard(
                        title: 'Habit focus',
                        bodyTitle: brief.habitTitle,
                        body: brief.habitBody,
                        icon: Icons.flag_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SignalCard(
                        title: 'Nutrition priority',
                        bodyTitle: brief.nutritionTitle,
                        body: brief.nutritionBody,
                        icon: Icons.restaurant_outlined,
                      ),
                    ),
                  ],
                ),
                if (showRecap) ...[
                  const SizedBox(height: 16),
                  _RecapCard(brief: brief),
                ],
                const SizedBox(height: 16),
                _CoachSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proactive nudges',
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AtelierColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      nudgesAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: LinearProgressIndicator(
                            color: AtelierColors.primary,
                          ),
                        ),
                        error: (error, stackTrace) => Text(
                          error.toString(),
                          style: GoogleFonts.manrope(
                            color: AtelierColors.onSurfaceVariant,
                          ),
                        ),
                        data: (nudges) {
                          if (nudges.isEmpty) {
                            return Text(
                              'No active interventions right now. TAIYO will nudge only when it can reduce friction or protect recovery.',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                height: 1.5,
                                color: AtelierColors.onSurfaceVariant,
                              ),
                            );
                          }
                          return Column(
                            children: nudges
                                .take(3)
                                .map(
                                  (nudge) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _NudgeCard(
                                      nudge: nudge,
                                      onTap: () => _performNudgeAction(nudge),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                summaryAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (summary) {
                    if (summary == null) {
                      return const SizedBox.shrink();
                    }
                    return _WeeklySummaryCard(
                      summary: summary,
                      isSharing: actionState.isSharingWeeklySummary,
                      onShare: () => _shareWeeklySummary(summary.weekStart),
                    );
                  },
                ),
                if ((readinessState.errorMessage ?? actionState.errorMessage) !=
                    null) ...[
                  const SizedBox(height: 16),
                  Text(
                    readinessState.errorMessage ?? actionState.errorMessage!,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Colors.red.shade700,
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

  Future<void> _submitReadiness() async {
    final log = await ref
        .read(aiCoachReadinessControllerProvider.notifier)
        .submit(
          logDate: DateTime.now(),
          energyLevel: _energyLevel,
          sorenessLevel: _sorenessLevel,
          stressLevel: _stressLevel,
          availableMinutes: _availableMinutes,
          locationMode: _locationMode,
        );
    if (!mounted) {
      return;
    }
    if (log == null) {
      showAppFeedback(context, 'TAIYO could not update readiness right now.');
      return;
    }
    showAppFeedback(
      context,
      'Updated: ${log.intensityBand.toUpperCase()} readiness at ${log.readinessScore}.',
    );
  }

  Future<void> _applyAdjustment({
    required AiDailyBriefEntity brief,
    required String type,
    String? taskId,
  }) async {
    if (!_canUseRecommendedDay(brief)) {
      showAppFeedback(
        context,
        'TAIYO needs a linked training day before changing today\'s session.',
      );
      return;
    }

    final adaptation = await ref
        .read(aiCoachActionControllerProvider.notifier)
        .applyAdjustment(
          adjustmentType: type,
          briefDate: brief.briefDate,
          taskId: taskId,
        );
    if (!mounted) {
      return;
    }
    if (adaptation == null) {
      showAppFeedback(context, 'TAIYO could not apply that adjustment.');
      return;
    }
    showAppFeedback(context, adaptation.whyShort);
  }

  Future<void> _startWorkout(AiDailyBriefEntity brief) async {
    if (!_canUseRecommendedDay(brief)) {
      showAppFeedback(
        context,
        'TAIYO needs a linked training day before starting today\'s session.',
      );
      return;
    }

    final sessionId = await ref
        .read(aiCoachActionControllerProvider.notifier)
        .startWorkout(
          planId: brief.planId!,
          dayId: brief.dayId,
          targetDate: brief.briefDate,
        );
    if (!mounted || sessionId == null) {
      if (mounted) {
        showAppFeedback(context, 'TAIYO could not start the workout.');
      }
      return;
    }
    Navigator.pushNamed(
      context,
      AppRoutes.activeWorkoutSession,
      arguments: ActiveWorkoutSessionArgs(sessionId: sessionId),
    );
  }

  Future<void> _openChat({required String prompt}) async {
    try {
      final sessionId = await ref
          .read(chatControllerProvider.notifier)
          .createSessionIfNeeded(null, type: ChatSessionType.general);
      ref.read(activeChatSessionIdProvider.notifier).state = sessionId;
      ref.read(pendingChatPromptProvider.notifier).state = prompt;
      if (!mounted) {
        return;
      }
      Navigator.pushNamed(
        context,
        AppRoutes.aiConversation,
        arguments: sessionId,
      );
    } catch (_) {
      if (mounted) {
        showAppFeedback(context, 'GymUnity could not open TAIYO chat.');
      }
    }
  }

  Future<void> _openWhySheet(AiDailyBriefEntity brief) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AtelierColors.surfaceContainerLowest,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why TAIYO chose this',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AtelierColors.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                brief.whyShort,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  height: 1.6,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ),
              if (brief.signalsUsed.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: brief.signalsUsed
                      .take(3)
                      .map((signal) => Chip(label: Text(signal)))
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openChat(
                      prompt:
                          'Explain in more detail why you recommended "${brief.workoutTitle}" today, including the signals you used: ${brief.signalsUsed.join(', ')}.',
                    );
                  },
                  child: const Text('Ask TAIYO in chat'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMealPlanQuickAdd() {
    Navigator.pushNamed(
      context,
      AppRoutes.nutritionMealPlan,
      arguments: const MealPlanRouteArgs(openQuickAddOnLaunch: true),
    );
  }

  void _openHydrationQuickLog() {
    Navigator.pushNamed(
      context,
      AppRoutes.nutrition,
      arguments: const NutritionRouteArgs(initialHydrationAmountMl: 350),
    );
  }

  Future<void> _performNudgeAction(AiNudgeEntity nudge) async {
    switch (nudge.actionType) {
      case 'start_workout':
        final planId = nudge.actionPayload['plan_id'] as String?;
        final dayId = nudge.actionPayload['day_id'] as String?;
        if (_hasUsableId(planId) && _hasUsableId(dayId)) {
          final sessionId = await ref
              .read(aiCoachActionControllerProvider.notifier)
              .startWorkout(planId: planId!, dayId: dayId);
          if (!mounted || sessionId == null) {
            return;
          }
          Navigator.pushNamed(
            context,
            AppRoutes.activeWorkoutSession,
            arguments: ActiveWorkoutSessionArgs(sessionId: sessionId),
          );
        } else if (mounted) {
          showAppFeedback(
            context,
            'TAIYO needs a linked training day before starting this session.',
          );
        }
        break;
      case 'shorten_workout':
        final brief = await _loadTodayBriefForAction();
        if (brief != null) {
          await _applyAdjustment(brief: brief, type: 'shorten_workout');
        }
        break;
      case 'swap_workout':
        final brief = await _loadTodayBriefForAction();
        if (brief != null) {
          await _applyAdjustment(
            brief: brief,
            type: 'swap_exercise',
            taskId: brief.primaryTaskId,
          );
        }
        break;
      case 'move_to_tomorrow':
        final brief = await _loadTodayBriefForAction();
        if (brief != null) {
          await _applyAdjustment(brief: brief, type: 'move_to_tomorrow');
        }
        break;
      case 'log_meal':
      case 'open_meal_plan':
        _openMealPlanQuickAdd();
        break;
      case 'log_hydration':
        _openHydrationQuickLog();
        break;
      case 'share_weekly_summary':
        await _shareWeeklySummary(_startOfWeek(DateTime.now()));
        break;
      case 'open_ai':
      default:
        await _openChat(prompt: nudge.body);
        break;
    }
  }

  Future<AiDailyBriefEntity?> _loadTodayBriefForAction() async {
    try {
      final brief = await ref.read(
        aiCoachDailyBriefProvider(_dateOnly(DateTime.now())).future,
      );
      if (brief == null && mounted) {
        showAppFeedback(context, 'TAIYO could not load today\'s brief.');
      }
      return brief;
    } catch (_) {
      if (mounted) {
        showAppFeedback(context, 'TAIYO could not load today\'s brief.');
      }
      return null;
    }
  }

  Future<void> _shareWeeklySummary(DateTime weekStart) async {
    final shared = await ref
        .read(aiCoachActionControllerProvider.notifier)
        .shareWeeklySummary(weekStart);
    if (!mounted) {
      return;
    }
    showAppFeedback(
      context,
      shared
          ? 'Weekly summary sent to your coach.'
          : 'GymUnity could not share the weekly summary.',
    );
  }
}

class _CoachHeroCard extends StatelessWidget {
  const _CoachHeroCard({
    required this.brief,
    required this.isBusy,
    required this.onStartWorkout,
    required this.onShortenWorkout,
    required this.onSwapWorkout,
    required this.onMoveToTomorrow,
    required this.onLogMeal,
    required this.onLogHydration,
    required this.onAskWhy,
  });

  final AiDailyBriefEntity brief;
  final bool isBusy;
  final VoidCallback? onStartWorkout;
  final VoidCallback? onShortenWorkout;
  final VoidCallback? onSwapWorkout;
  final VoidCallback? onMoveToTomorrow;
  final VoidCallback onLogMeal;
  final VoidCallback onLogHydration;
  final VoidCallback onAskWhy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173628), Color(0xFF244B3E), Color(0xFFF5F2EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(label: 'READINESS ${brief.readinessScore}'),
              _HeroChip(label: brief.intensityBand.toUpperCase()),
              if (brief.coachMode) const _HeroChip(label: 'COACH-AWARE'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Today\'s recommendation',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            brief.workoutTitle,
            style: GoogleFonts.manrope(
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          if (brief.workoutSubtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              brief.workoutSubtitle,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            brief.whyShort,
            style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.55,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: 'Intensity',
                  value: brief.intensityBand.toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricPill(
                  label: 'Duration',
                  value: brief.workoutDurationMinutes == null
                      ? 'Flexible'
                      : '${brief.workoutDurationMinutes} min',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: isBusy ? null : onStartWorkout,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AtelierColors.primary,
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start workout'),
              ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : onShortenWorkout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: const Icon(Icons.compress_rounded),
                label: const Text('Shorten'),
              ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : onSwapWorkout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Swap'),
              ),
              OutlinedButton.icon(
                onPressed: isBusy ? null : onMoveToTomorrow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: const Icon(Icons.event_repeat_rounded),
                label: const Text('Move to tomorrow'),
              ),
              OutlinedButton.icon(
                onPressed: onLogMeal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: const Icon(Icons.lunch_dining_outlined),
                label: const Text('Log meal'),
              ),
              OutlinedButton.icon(
                onPressed: onLogHydration,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                icon: const Icon(Icons.water_drop_outlined),
                label: const Text('Log hydration'),
              ),
              TextButton.icon(
                onPressed: onAskWhy,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.psychology_alt_outlined),
                label: const Text('Ask AI why'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoachSurface extends StatelessWidget {
  const _CoachSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class _TaiyoCoachEntryCard extends StatelessWidget {
  const _TaiyoCoachEntryCard({
    required this.onOpenBuilder,
    required this.onOpenChat,
  });

  final VoidCallback onOpenBuilder;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return _CoachSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Open TAIYO tools',
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Jump directly into the guided builder or open chat without relying on the small header icons.',
            style: GoogleFonts.manrope(
              fontSize: 12,
              height: 1.5,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final buildButton = FilledButton.icon(
                key: const Key('taiyo-coach-open-builder-button'),
                onPressed: onOpenBuilder,
                icon: const Icon(Icons.architecture_outlined),
                label: const Text('Build'),
              );
              final chatButton = OutlinedButton.icon(
                key: const Key('taiyo-coach-open-chat-button'),
                onPressed: onOpenChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Chat'),
              );

              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildButton,
                    const SizedBox(height: 10),
                    chatButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: buildButton),
                  const SizedBox(width: 10),
                  Expanded(child: chatButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.title,
    required this.bodyTitle,
    required this.body,
    required this.icon,
  });

  final String title;
  final String bodyTitle;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _CoachSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AtelierColors.primary),
          const SizedBox(height: 14),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bodyTitle,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.manrope(
              fontSize: 12,
              height: 1.5,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.brief});

  final AiDailyBriefEntity brief;

  @override
  Widget build(BuildContext context) {
    return _CoachSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'End-of-day recap',
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (brief.recapCompleted.isNotEmpty)
            _RecapList(title: 'Completed', items: brief.recapCompleted),
          if (brief.recapMissed.isNotEmpty) ...[
            if (brief.recapCompleted.isNotEmpty) const SizedBox(height: 12),
            _RecapList(title: 'Missed', items: brief.recapMissed),
          ],
          if (brief.recapTomorrowFocus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Tomorrow',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AtelierColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              brief.recapTomorrowFocus,
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.5,
                color: AtelierColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecapList extends StatelessWidget {
  const _RecapList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AtelierColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $item',
              style: GoogleFonts.manrope(
                fontSize: 13,
                height: 1.5,
                color: AtelierColors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({required this.nudge, required this.onTap});

  final AiNudgeEntity nudge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AtelierColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nudge.title,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AtelierColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nudge.body,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.45,
                    color: AtelierColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nudge.whyShort,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: AtelierColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(onPressed: onTap, child: const Text('Act')),
        ],
      ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({
    required this.summary,
    required this.isSharing,
    required this.onShare,
  });

  final AiWeeklySummaryEntity summary;
  final bool isSharing;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return _CoachSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly summary',
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${summary.adherenceScore}% adherence',
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary.summaryText,
            style: GoogleFonts.manrope(
              fontSize: 13,
              height: 1.5,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          if (summary.wins.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Wins: ${summary.wins.join(' • ')}',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AtelierColors.onSurface,
              ),
            ),
          ],
          if (summary.blockers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Blockers: ${summary.blockers.join(' • ')}',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AtelierColors.onSurface,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Next focus: ${summary.nextFocus}',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: isSharing ? null : onShare,
            icon: isSharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share_outlined),
            label: Text(
              summary.shareStatus == 'shared'
                  ? 'Share again with coach'
                  : 'Share with coach',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelSelector extends StatelessWidget {
  const _LevelSelector({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: $value/5',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AtelierColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(
            5,
            (index) => ChoiceChip(
              label: Text('${index + 1}'),
              selected: value == index + 1,
              onSelected: (_) => onChanged(index + 1),
            ),
          ),
        ),
      ],
    );
  }
}

class _MinuteSelector extends StatelessWidget {
  const _MinuteSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const minuteOptions = <int>[20, 25, 35, 45, 60];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available time',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AtelierColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final minutes in minuteOptions)
              ChoiceChip(
                label: Text('$minutes min'),
                selected: value == minutes,
                onSelected: (_) => onChanged(minutes),
              ),
          ],
        ),
      ],
    );
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _startOfWeek(DateTime value) {
  final normalized = _dateOnly(value);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

bool _canUseRecommendedDay(AiDailyBriefEntity brief) {
  return _hasUsableId(brief.planId) && _hasUsableId(brief.dayId);
}

bool _hasUsableId(String? value) {
  return value != null && value.trim().isNotEmpty;
}
