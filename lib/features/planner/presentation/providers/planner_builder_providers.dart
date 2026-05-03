import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../ai_chat/domain/entities/chat_session_entity.dart';
import '../../domain/entities/planner_builder_entities.dart';
import '../../domain/services/planner_builder_question_factory.dart';

class PlannerBuilderGenerationResult {
  const PlannerBuilderGenerationResult({
    required this.sessionId,
    required this.draftId,
  });

  final String sessionId;
  final String draftId;
}

class PlannerBuilderController extends StateNotifier<PlannerBuilderState> {
  PlannerBuilderController(this._ref, this._questionFactory)
    : super(const PlannerBuilderState());

  final Ref _ref;
  final PlannerBuilderQuestionFactory _questionFactory;

  Future<void> start({String? seedPrompt, String? existingSessionId}) async {
    if (state.phase == PlannerBuilderPhase.scanning ||
        state.phase == PlannerBuilderPhase.questioning ||
        state.phase == PlannerBuilderPhase.answerReview) {
      return;
    }

    state = state.copyWith(
      phase: PlannerBuilderPhase.scanning,
      sessionId: existingSessionId,
      clearError: true,
      clearNotice: true,
    );

    try {
      final context = await _loadContext(seedPrompt: seedPrompt);
      final build = _questionFactory.build(context);
      state = state.copyWith(
        phase: PlannerBuilderPhase.questioning,
        context: context,
        questions: build.questions,
        answers: build.answers,
        currentIndex: 0,
        noticeMessage: build.knownFacts.isEmpty
            ? null
            : 'Found ${build.knownFacts.join(', ')} before asking questions.',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        phase: PlannerBuilderPhase.error,
        errorMessage: error.toString(),
      );
    }
  }

  void answerCurrent(Object? value) {
    final question = state.currentQuestion;
    if (question == null) {
      return;
    }
    answer(question.field, value);
  }

  void answer(PlannerBuilderField field, Object? value) {
    final question = _questionForField(field);
    final nextAnswers = Map<PlannerBuilderField, PlannerBuilderAnswer>.from(
      state.answers,
    );
    if (_hasContent(value)) {
      nextAnswers[field] = PlannerBuilderAnswer(
        field: field,
        value: _normalizeValue(value),
        source: PlannerBuilderAnswerSource.user,
        label: _labelForValue(question, value),
        confirmed: true,
      );
    } else {
      nextAnswers.remove(field);
    }
    state = state.copyWith(answers: nextAnswers, clearError: true);
  }

  void next() {
    if (!state.canGoNext) {
      state = state.copyWith(
        errorMessage: 'Choose an answer before continuing.',
      );
      return;
    }
    if (state.currentIndex >= state.questions.length - 1) {
      state = state.copyWith(
        phase: PlannerBuilderPhase.answerReview,
        clearError: true,
      );
      return;
    }
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      clearError: true,
    );
  }

  void back() {
    if (state.phase == PlannerBuilderPhase.answerReview) {
      state = state.copyWith(
        phase: PlannerBuilderPhase.questioning,
        currentIndex: state.questions.isEmpty ? 0 : state.questions.length - 1,
        clearError: true,
      );
      return;
    }
    if (!state.canGoBack) {
      return;
    }
    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      clearError: true,
    );
  }

  void reviewAnswers() {
    state = state.copyWith(
      phase: PlannerBuilderPhase.answerReview,
      clearError: true,
    );
  }

  void editField(PlannerBuilderField field) {
    final index = state.questions.indexWhere((question) {
      return question.field == field;
    });
    if (index < 0) {
      return;
    }
    state = state.copyWith(
      phase: PlannerBuilderPhase.questioning,
      currentIndex: index,
      clearError: true,
    );
  }

  Future<PlannerBuilderGenerationResult?> generateDraft() async {
    if (!state.hasCriticalAnswers) {
      state = state.copyWith(
        phase: PlannerBuilderPhase.questioning,
        errorMessage:
            'Goal, experience, weekly days, session length, and equipment are required.',
      );
      return null;
    }

    state = state.copyWith(
      phase: PlannerBuilderPhase.generating,
      clearError: true,
      clearNotice: true,
    );

    try {
      final chatRepository = _ref.read(chatRepositoryProvider);
      final sessionId = state.sessionId?.trim().isNotEmpty == true
          ? state.sessionId!
          : (await chatRepository.createSession(
              title: 'AI Builder Plan',
              type: ChatSessionType.planner,
            )).id;
      final result = await _ref
          .read(plannerRepositoryProvider)
          .requestTaiyoWorkoutPlanDraft(
            sessionId: sessionId,
            plannerAnswers: _plannerAnswersJson(),
          );

      if (result.isPlanReady && result.draftId != null) {
        state = state.copyWith(
          phase: PlannerBuilderPhase.draftReady,
          sessionId: sessionId,
          draftId: result.draftId,
          clearError: true,
        );
        return PlannerBuilderGenerationResult(
          sessionId: sessionId,
          draftId: result.draftId!,
        );
      }

      if (result.missingFields.isNotEmpty) {
        _mergeMissingFields(result.missingFields, sessionId);
        return null;
      }

      state = state.copyWith(
        phase: PlannerBuilderPhase.error,
        sessionId: sessionId,
        errorMessage: result.assistantMessage.trim().isEmpty
            ? 'GymUnity could not generate a plan from this intake yet.'
            : result.assistantMessage,
      );
      return null;
    } catch (error) {
      state = state.copyWith(
        phase: PlannerBuilderPhase.error,
        errorMessage: error.toString(),
      );
      return null;
    }
  }

  Future<PlannerBuilderKnownContext> _loadContext({String? seedPrompt}) async {
    final memberRepository = _ref.read(memberRepositoryProvider);
    final profile = await memberRepository.getMemberProfile();
    final preferences = await memberRepository.getPreferences();
    final weights = await memberRepository.listWeightEntries();
    final measurements = await memberRepository.listBodyMeasurements();
    final plans = await memberRepository.listWorkoutPlans();
    final sessions = await memberRepository.listWorkoutSessions();
    final memories = await _loadMemories();
    return PlannerBuilderKnownContext(
      profile: profile,
      preferences: preferences,
      latestWeight: weights.isEmpty ? null : weights.last,
      latestMeasurement: measurements.isEmpty ? null : measurements.last,
      workoutPlans: plans,
      workoutSessions: sessions,
      memories: memories,
      seedPrompt: seedPrompt,
    );
  }

  Future<Map<String, dynamic>> _loadMemories() async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return const <String, dynamic>{};
      }
      final rows = await client
          .from('ai_user_memories')
          .select('memory_key,memory_value_json')
          .eq('user_id', userId);
      final memories = <String, dynamic>{};
      for (final row in rows as List<dynamic>) {
        if (row is! Map) {
          continue;
        }
        final key = row['memory_key']?.toString();
        if (key == null || key.trim().isEmpty) {
          continue;
        }
        memories[key] = row['memory_value_json'];
      }
      return memories;
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  void _mergeMissingFields(List<String> missingFields, String sessionId) {
    final ar = state.context?.prefersArabic ?? false;
    final nextQuestions = List<PlannerBuilderQuestion>.from(state.questions);
    for (final missing in missingFields) {
      final question = _questionFactory.questionForMissingField(missing, ar);
      final exists = nextQuestions.any((item) => item.field == question.field);
      if (!exists) {
        nextQuestions.add(question);
      }
    }
    final firstMissingIndex = nextQuestions.indexWhere((question) {
      return missingFields.contains(_wireName(question.field));
    });
    state = state.copyWith(
      phase: PlannerBuilderPhase.questioning,
      sessionId: sessionId,
      questions: nextQuestions,
      currentIndex: firstMissingIndex < 0 ? 0 : firstMissingIndex,
      noticeMessage:
          'TAIYO needs a little more structure before generating the plan.',
      clearError: true,
    );
  }

  PlannerBuilderQuestion? _questionForField(PlannerBuilderField field) {
    for (final question in state.questions) {
      if (question.field == field) {
        return question;
      }
    }
    return null;
  }

  Map<String, dynamic> _plannerAnswersJson() {
    return <String, dynamic>{
      'source': 'gymunity_guided_builder',
      ..._criticalProfileJson(),
      ..._optionalPreferencesJson(),
      'active_plan': state.context?.activeAiPlan == null
          ? null
          : <String, dynamic>{
              'id': state.context!.activeAiPlan!.id,
              'title': state.context!.activeAiPlan!.title,
              'status': state.context!.activeAiPlan!.status,
            },
      'seed_prompt': state.context?.seedPrompt,
    }..removeWhere((key, value) {
      if (value == null) {
        return true;
      }
      if (value is List && value.isEmpty) {
        return true;
      }
      return false;
    });
  }

  Map<String, dynamic> _criticalProfileJson() {
    return <String, dynamic>{
      'goal': state.answers[PlannerBuilderField.goal]?.stringValue,
      'experience_level':
          state.answers[PlannerBuilderField.experienceLevel]?.stringValue,
      'days_per_week': state.answers[PlannerBuilderField.daysPerWeek]?.intValue,
      'session_minutes':
          state.answers[PlannerBuilderField.sessionMinutes]?.intValue,
      'equipment':
          state.answers[PlannerBuilderField.equipment]?.stringListValue ??
          const <String>[],
      'limitations':
          state.answers[PlannerBuilderField.limitations]?.stringListValue ??
          const <String>[],
      'preferred_language': state.context?.prefersArabic == true ? 'ar' : 'en',
      'measurement_unit':
          state.context?.preferences.measurementUnit ?? 'metric',
    };
  }

  Map<String, dynamic> _optionalPreferencesJson() {
    return <String, dynamic>{
      'training_location':
          state.answers[PlannerBuilderField.trainingLocation]?.stringValue,
      'cardio_preference':
          state.answers[PlannerBuilderField.cardioPreference]?.stringValue,
      'workout_style':
          state.answers[PlannerBuilderField.workoutStyle]?.stringValue,
      'focus_areas':
          state.answers[PlannerBuilderField.focusAreas]?.stringListValue ??
          const <String>[],
      'preferred_days':
          state.answers[PlannerBuilderField.preferredDays]?.stringListValue ??
          const <String>[],
      'intensity': state.answers[PlannerBuilderField.intensity]?.stringValue,
      'exercise_dislikes':
          state.answers[PlannerBuilderField.dislikes]?.stringListValue ??
          const <String>[],
    }..removeWhere((key, value) {
      if (value == null) {
        return true;
      }
      if (value is List && value.isEmpty) {
        return true;
      }
      return false;
    });
  }
}

final plannerBuilderControllerProvider =
    StateNotifierProvider.autoDispose<
      PlannerBuilderController,
      PlannerBuilderState
    >((ref) {
      return PlannerBuilderController(
        ref,
        const PlannerBuilderQuestionFactory(),
      );
    });

String? _labelForValue(PlannerBuilderQuestion? question, Object? value) {
  if (question == null) {
    return null;
  }
  if (value is Iterable) {
    final labels = value
        .map((item) => _labelForValue(question, item))
        .whereType<String>()
        .toList();
    return labels.isEmpty ? null : labels.join(', ');
  }
  final stringValue = value?.toString();
  for (final option in question.options) {
    if (option.value == stringValue) {
      return option.label;
    }
  }
  return stringValue;
}

Object? _normalizeValue(Object? value) {
  if (value is Iterable && value is! String) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String) {
    return value.trim();
  }
  return value;
}

bool _hasContent(Object? value) {
  if (value == null) {
    return false;
  }
  if (value is String) {
    return value.trim().isNotEmpty;
  }
  if (value is Iterable) {
    return value.isNotEmpty;
  }
  return true;
}

String _wireName(PlannerBuilderField field) {
  switch (field) {
    case PlannerBuilderField.goal:
      return 'goal';
    case PlannerBuilderField.experienceLevel:
      return 'experience_level';
    case PlannerBuilderField.daysPerWeek:
      return 'days_per_week';
    case PlannerBuilderField.sessionMinutes:
      return 'session_minutes';
    case PlannerBuilderField.equipment:
      return 'equipment';
    case PlannerBuilderField.limitations:
      return 'limitations';
    case PlannerBuilderField.activePlanNotice:
    case PlannerBuilderField.trainingLocation:
    case PlannerBuilderField.cardioPreference:
    case PlannerBuilderField.workoutStyle:
    case PlannerBuilderField.focusAreas:
    case PlannerBuilderField.preferredDays:
    case PlannerBuilderField.intensity:
    case PlannerBuilderField.dislikes:
      return field.name;
  }
}
