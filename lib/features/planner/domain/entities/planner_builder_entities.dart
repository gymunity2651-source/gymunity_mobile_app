import '../../../coach/domain/entities/workout_plan_entity.dart';
import '../../../member/domain/entities/member_profile_entity.dart';
import '../../../member/domain/entities/member_progress_entity.dart';

enum PlannerBuilderPhase {
  idle,
  scanning,
  questioning,
  answerReview,
  generating,
  draftReady,
  error,
}

enum PlannerBuilderField {
  activePlanNotice,
  goal,
  experienceLevel,
  daysPerWeek,
  sessionMinutes,
  trainingLocation,
  equipment,
  limitations,
  cardioPreference,
  workoutStyle,
  focusAreas,
  preferredDays,
  intensity,
  dislikes,
}

enum PlannerBuilderInputKind { notice, singleChoice, multiChoice, slider, text }

enum PlannerBuilderAnswerSource {
  profile,
  memory,
  history,
  inferred,
  user,
  seed,
  defaultValue,
}

class PlannerBuilderKnownContext {
  const PlannerBuilderKnownContext({
    this.profile,
    this.preferences = const UserPreferencesEntity(),
    this.latestWeight,
    this.latestMeasurement,
    this.workoutPlans = const <WorkoutPlanEntity>[],
    this.workoutSessions = const <WorkoutSessionEntity>[],
    this.memories = const <String, dynamic>{},
    this.seedPrompt,
  });

  final MemberProfileEntity? profile;
  final UserPreferencesEntity preferences;
  final WeightEntryEntity? latestWeight;
  final BodyMeasurementEntity? latestMeasurement;
  final List<WorkoutPlanEntity> workoutPlans;
  final List<WorkoutSessionEntity> workoutSessions;
  final Map<String, dynamic> memories;
  final String? seedPrompt;

  WorkoutPlanEntity? get activeAiPlan {
    for (final plan in workoutPlans) {
      if (plan.source == 'ai' && plan.status == 'active') {
        return plan;
      }
    }
    return null;
  }

  bool get prefersArabic {
    final profileLanguage = profile?.preferredLanguage?.trim().toLowerCase();
    final preferenceLanguage = preferences.language.trim().toLowerCase();
    return profileLanguage == 'arabic' ||
        profileLanguage == 'ar' ||
        preferenceLanguage == 'arabic' ||
        preferenceLanguage == 'ar';
  }
}

class PlannerBuilderAnswer {
  const PlannerBuilderAnswer({
    required this.field,
    required this.value,
    required this.source,
    this.label,
    this.confirmed = false,
  });

  final PlannerBuilderField field;
  final Object? value;
  final PlannerBuilderAnswerSource source;
  final String? label;
  final bool confirmed;

  PlannerBuilderAnswer copyWith({
    Object? value,
    PlannerBuilderAnswerSource? source,
    String? label,
    bool? confirmed,
  }) {
    return PlannerBuilderAnswer(
      field: field,
      value: value ?? this.value,
      source: source ?? this.source,
      label: label ?? this.label,
      confirmed: confirmed ?? this.confirmed,
    );
  }

  bool get hasValue {
    final raw = value;
    if (raw == null) {
      return false;
    }
    if (raw is String) {
      return raw.trim().isNotEmpty;
    }
    if (raw is Iterable) {
      return raw.isNotEmpty;
    }
    return true;
  }

  String? get stringValue {
    final raw = value;
    if (raw == null) {
      return null;
    }
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return raw.toString();
  }

  int? get intValue {
    final raw = value;
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse(raw?.toString() ?? '');
  }

  List<String> get stringListValue {
    final raw = value;
    if (raw is List<String>) {
      return raw.where((item) => item.trim().isNotEmpty).toList();
    }
    if (raw is Iterable) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final single = stringValue;
    return single == null ? const <String>[] : <String>[single];
  }
}

class PlannerBuilderOption {
  const PlannerBuilderOption({
    required this.value,
    required this.label,
    this.description,
  });

  final String value;
  final String label;
  final String? description;
}

class PlannerBuilderQuestion {
  const PlannerBuilderQuestion({
    required this.field,
    required this.title,
    required this.description,
    required this.inputKind,
    this.options = const <PlannerBuilderOption>[],
    this.required = false,
    this.confirmation = false,
    this.min,
    this.max,
    this.divisions,
    this.valueSuffix = '',
    this.placeholder,
  });

  final PlannerBuilderField field;
  final String title;
  final String description;
  final PlannerBuilderInputKind inputKind;
  final List<PlannerBuilderOption> options;
  final bool required;
  final bool confirmation;
  final double? min;
  final double? max;
  final int? divisions;
  final String valueSuffix;
  final String? placeholder;

  bool get allowsMultiple => inputKind == PlannerBuilderInputKind.multiChoice;
}

class PlannerBuilderState {
  const PlannerBuilderState({
    this.phase = PlannerBuilderPhase.idle,
    this.context,
    this.questions = const <PlannerBuilderQuestion>[],
    this.answers = const <PlannerBuilderField, PlannerBuilderAnswer>{},
    this.currentIndex = 0,
    this.errorMessage,
    this.sessionId,
    this.draftId,
    this.noticeMessage,
  });

  final PlannerBuilderPhase phase;
  final PlannerBuilderKnownContext? context;
  final List<PlannerBuilderQuestion> questions;
  final Map<PlannerBuilderField, PlannerBuilderAnswer> answers;
  final int currentIndex;
  final String? errorMessage;
  final String? sessionId;
  final String? draftId;
  final String? noticeMessage;

  PlannerBuilderQuestion? get currentQuestion {
    if (questions.isEmpty ||
        currentIndex < 0 ||
        currentIndex >= questions.length) {
      return null;
    }
    return questions[currentIndex];
  }

  int get totalSteps => questions.length;

  int get stepNumber => questions.isEmpty ? 0 : currentIndex + 1;

  double get progress {
    if (questions.isEmpty) {
      return 0;
    }
    return stepNumber / questions.length;
  }

  bool get canGoBack => currentIndex > 0;

  bool get canGoNext {
    final question = currentQuestion;
    if (question == null) {
      return false;
    }
    if (!question.required) {
      return true;
    }
    return answers[question.field]?.hasValue == true;
  }

  bool get hasCriticalAnswers {
    return _hasAnswer(PlannerBuilderField.goal) &&
        _hasAnswer(PlannerBuilderField.experienceLevel) &&
        _hasAnswer(PlannerBuilderField.daysPerWeek) &&
        _hasAnswer(PlannerBuilderField.sessionMinutes) &&
        _hasAnswer(PlannerBuilderField.equipment);
  }

  bool _hasAnswer(PlannerBuilderField field) {
    return answers[field]?.hasValue == true;
  }

  PlannerBuilderState copyWith({
    PlannerBuilderPhase? phase,
    PlannerBuilderKnownContext? context,
    List<PlannerBuilderQuestion>? questions,
    Map<PlannerBuilderField, PlannerBuilderAnswer>? answers,
    int? currentIndex,
    String? errorMessage,
    String? sessionId,
    String? draftId,
    String? noticeMessage,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return PlannerBuilderState(
      phase: phase ?? this.phase,
      context: context ?? this.context,
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      currentIndex: currentIndex ?? this.currentIndex,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      sessionId: sessionId ?? this.sessionId,
      draftId: draftId ?? this.draftId,
      noticeMessage: clearNotice ? null : noticeMessage ?? this.noticeMessage,
    );
  }
}
