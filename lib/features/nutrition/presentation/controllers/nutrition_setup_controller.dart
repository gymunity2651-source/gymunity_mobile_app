import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../member/domain/entities/member_profile_entity.dart';
import '../../domain/entities/nutrition_entities.dart';
import '../../domain/services/calorie_engine.dart';
import '../../domain/services/nutrition_setup_question_factory.dart';
import '../providers/nutrition_providers.dart';

class NutritionSetupState {
  const NutritionSetupState({
    this.loading = false,
    this.generating = false,
    this.questions = const <NutritionSetupQuestion>[],
    this.answers = const <NutritionSetupField, Object?>{},
    this.currentIndex = 0,
    this.errorMessage,
    this.completed = false,
  });

  final bool loading;
  final bool generating;
  final List<NutritionSetupQuestion> questions;
  final Map<NutritionSetupField, Object?> answers;
  final int currentIndex;
  final String? errorMessage;
  final bool completed;

  NutritionSetupQuestion? get currentQuestion {
    if (questions.isEmpty || currentIndex < 0 || currentIndex >= questions.length) {
      return null;
    }
    return questions[currentIndex];
  }

  int get stepNumber => questions.isEmpty ? 0 : currentIndex + 1;
  int get totalSteps => questions.length;
  double get progress => questions.isEmpty ? 0 : stepNumber / questions.length;
  bool get canGoBack => currentIndex > 0;
  bool get isLastStep => currentIndex >= questions.length - 1;

  bool get canGoNext {
    final question = currentQuestion;
    if (question == null) return false;
    if (!question.required) return true;
    return _hasValue(answers[question.field]);
  }

  NutritionSetupState copyWith({
    bool? loading,
    bool? generating,
    List<NutritionSetupQuestion>? questions,
    Map<NutritionSetupField, Object?>? answers,
    int? currentIndex,
    String? errorMessage,
    bool? completed,
    bool clearError = false,
  }) {
    return NutritionSetupState(
      loading: loading ?? this.loading,
      generating: generating ?? this.generating,
      questions: questions ?? this.questions,
      answers: answers ?? this.answers,
      currentIndex: currentIndex ?? this.currentIndex,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      completed: completed ?? this.completed,
    );
  }
}

class NutritionSetupController extends StateNotifier<NutritionSetupState> {
  NutritionSetupController(this._ref) : super(const NutritionSetupState());

  final Ref _ref;

  Future<void> start() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final memberRepository = _ref.read(memberRepositoryProvider);
      final nutritionRepository = _ref.read(nutritionRepositoryProvider);
      final memberProfile = await memberRepository.getMemberProfile();
      final preferences = await memberRepository.getPreferences();
      final weightEntries = await memberRepository.listWeightEntries();
      final nutritionProfile = await nutritionRepository.getProfile();
      final build = _ref.read(nutritionSetupQuestionFactoryProvider).build(
        memberProfile: memberProfile,
        nutritionProfile: nutritionProfile,
        weightEntries: weightEntries,
        arabic: preferences.language == 'arabic',
      );
      state = state.copyWith(
        loading: false,
        questions: build.questions,
        answers: build.answers,
        currentIndex: 0,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        errorMessage: error.toString(),
      );
    }
  }

  void answerCurrent(Object? value) {
    final question = state.currentQuestion;
    if (question == null) return;
    final answers = Map<NutritionSetupField, Object?>.from(state.answers);
    if (_hasValue(value)) {
      answers[question.field] = _normalize(value);
    } else {
      answers.remove(question.field);
    }
    state = state.copyWith(answers: answers, clearError: true);
  }

  void next() {
    if (!state.canGoNext) {
      state = state.copyWith(errorMessage: 'Answer this step to continue.');
      return;
    }
    if (state.isLastStep) {
      return;
    }
    state = state.copyWith(currentIndex: state.currentIndex + 1, clearError: true);
  }

  void back() {
    if (!state.canGoBack) return;
    state = state.copyWith(currentIndex: state.currentIndex - 1, clearError: true);
  }

  Future<void> finish() async {
    state = state.copyWith(generating: true, clearError: true);
    try {
      final memberRepository = _ref.read(memberRepositoryProvider);
      final nutritionRepository = _ref.read(nutritionRepositoryProvider);
      final existingProfile = await memberRepository.getMemberProfile();
      final goal = _string(NutritionSetupField.goal) ?? existingProfile?.goal ?? 'maintenance';
      final gender = _string(NutritionSetupField.gender) ?? existingProfile?.gender ?? 'prefer_not_to_say';
      final age = _int(NutritionSetupField.age) ?? existingProfile?.age ?? 30;
      final height = _double(NutritionSetupField.heightCm) ?? existingProfile?.heightCm ?? 170;
      final weight = _double(NutritionSetupField.weightKg) ?? existingProfile?.currentWeightKg ?? 75;
      final frequency = _string(NutritionSetupField.trainingFrequency) ??
          existingProfile?.trainingFrequency ??
          '3_4_days_per_week';

      await memberRepository.upsertMemberProfile(
        goal: goal,
        age: age,
        gender: gender,
        heightCm: height,
        currentWeightKg: weight,
        trainingFrequency: frequency,
        experienceLevel: existingProfile?.experienceLevel ?? 'beginner',
        budgetEgp: existingProfile?.budgetEgp,
        city: existingProfile?.city,
        coachingPreference: existingProfile?.coachingPreference,
        trainingPlace: existingProfile?.trainingPlace,
        preferredLanguage: existingProfile?.preferredLanguage,
        preferredCoachGender: existingProfile?.preferredCoachGender,
      );

      final updatedProfile =
          await memberRepository.getMemberProfile() ??
          MemberProfileEntity(
            userId: existingProfile?.userId ?? 'member',
            goal: goal,
            age: age,
            gender: gender,
            heightCm: height,
            currentWeightKg: weight,
            trainingFrequency: frequency,
            experienceLevel: existingProfile?.experienceLevel ?? 'beginner',
          );
      final nutritionProfile = await nutritionRepository.upsertProfile(
        NutritionProfileEntity(
          memberId: updatedProfile.userId,
          activityLevel: _string(NutritionSetupField.activityLevel),
          dietaryPreference:
              _string(NutritionSetupField.dietaryPreference) ?? 'balanced',
          mealCountPreference: _int(NutritionSetupField.mealCount) ?? 4,
          allergies: _stringList(NutritionSetupField.allergies),
          foodExclusions: _stringList(NutritionSetupField.exclusions),
          preferredCuisines: _stringList(NutritionSetupField.preferredCuisines)
                  .isEmpty
              ? const <String>['egyptian', 'international']
              : _stringList(NutritionSetupField.preferredCuisines),
          budgetLevel: _string(NutritionSetupField.budgetLevel) ?? 'balanced',
          cookingPreference:
              _string(NutritionSetupField.cookingPreference) ?? 'simple',
          workoutTiming: _string(NutritionSetupField.workoutTiming),
        ),
      );
      final plans = await memberRepository.listWorkoutPlans();
      final sessions = await memberRepository.listWorkoutSessions();
      final activePlan = plans.where((plan) => plan.status == 'active').firstOrNull;
      final calculation = _ref.read(calorieEngineProvider).calculate(
        NutritionCalculationContext(
          memberProfile: updatedProfile,
          nutritionProfile: nutritionProfile,
          latestWeightKg: weight,
          activePlan: activePlan,
          recentSessions: sessions,
        ),
      );
      final targetDraft = calculation.target;
      if (targetDraft == null) {
        throw StateError('Missing nutrition inputs: ${calculation.missingFields.join(', ')}');
      }
      final target = await nutritionRepository.saveTarget(targetDraft);
      final templates = await nutritionRepository.listMealTemplates();
      final generated = _ref.read(mealPlanGeneratorProvider).generate(
        target: target,
        profile: nutritionProfile,
        templates: templates,
        startDate: DateTime.now(),
        arabic: updatedProfile.preferredLanguage == 'arabic',
      );
      await nutritionRepository.saveGeneratedMealPlan(
        target: target,
        startDate: generated.startDate,
        mealCount: generated.mealCount,
        days: generated.days,
        generationContext: <String, dynamic>{
          'source': 'nutrition_setup',
          'dietary_preference': nutritionProfile.dietaryPreference,
          'preferred_cuisines': nutritionProfile.preferredCuisines,
        },
      );

      _invalidateNutrition();
      state = state.copyWith(generating: false, completed: true, clearError: true);
    } catch (error) {
      state = state.copyWith(
        generating: false,
        errorMessage: error.toString(),
      );
    }
  }

  void _invalidateNutrition() {
    _ref.invalidate(nutritionProfileProvider);
    _ref.invalidate(activeNutritionTargetProvider);
    _ref.invalidate(activeMealPlanProvider);
    _ref.invalidate(nutritionDashboardProvider);
  }

  String? _string(NutritionSetupField field) {
    final value = state.answers[field];
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    return value.toString();
  }

  int? _int(NutritionSetupField field) {
    final value = state.answers[field];
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _double(NutritionSetupField field) {
    final value = state.answers[field];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  List<String> _stringList(NutritionSetupField field) {
    final value = state.answers[field];
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    final single = _string(field);
    return single == null ? const <String>[] : <String>[single];
  }
}

final nutritionSetupControllerProvider =
    StateNotifierProvider.autoDispose<
      NutritionSetupController,
      NutritionSetupState
    >((ref) {
      return NutritionSetupController(ref);
    });

Object? _normalize(Object? value) {
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

bool _hasValue(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  if (value is num) return value > 0;
  return true;
}
