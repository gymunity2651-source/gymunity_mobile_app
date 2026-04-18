import '../entities/planner_builder_entities.dart';
import '../../../member/domain/entities/member_progress_entity.dart';

class PlannerBuilderQuestionFactory {
  const PlannerBuilderQuestionFactory();

  static const criticalFields = <PlannerBuilderField>{
    PlannerBuilderField.goal,
    PlannerBuilderField.experienceLevel,
    PlannerBuilderField.daysPerWeek,
    PlannerBuilderField.sessionMinutes,
    PlannerBuilderField.equipment,
  };

  PlannerBuilderBuildResult build(PlannerBuilderKnownContext context) {
    final answers = buildInitialAnswers(context);
    final ar = context.prefersArabic;
    final questions = <PlannerBuilderQuestion>[];

    if (context.activeAiPlan != null) {
      questions.add(
        PlannerBuilderQuestion(
          field: PlannerBuilderField.activePlanNotice,
          title: ar
              ? 'لديك خطة نشطة بالفعل'
              : 'You already have an active plan',
          description: ar
              ? 'يمكنك بناء خطة جديدة ومراجعتها قبل التفعيل. عند التفعيل سيتم أرشفة خطة الذكاء الاصطناعي الحالية.'
              : 'You can build and review a new plan before activation. Activating it will archive your current AI plan.',
          inputKind: PlannerBuilderInputKind.notice,
        ),
      );
    }

    questions.addAll([
      _goalQuestion(ar, answers.containsKey(PlannerBuilderField.goal)),
      _experienceQuestion(
        ar,
        answers.containsKey(PlannerBuilderField.experienceLevel),
      ),
      _daysQuestion(ar, answers.containsKey(PlannerBuilderField.daysPerWeek)),
      _durationQuestion(
        ar,
        answers.containsKey(PlannerBuilderField.sessionMinutes),
      ),
      _locationQuestion(
        ar,
        answers.containsKey(PlannerBuilderField.trainingLocation),
      ),
      _equipmentQuestion(
        ar,
        answers.containsKey(PlannerBuilderField.equipment),
        _answerString(answers, PlannerBuilderField.trainingLocation) ??
            context.profile?.trainingPlace,
      ),
    ]);

    final experience = _answerString(
      answers,
      PlannerBuilderField.experienceLevel,
    );
    if (experience == 'beginner' ||
        experience == null ||
        !_hasAnswer(answers, PlannerBuilderField.limitations)) {
      questions.add(
        _limitationsQuestion(
          ar,
          answers.containsKey(PlannerBuilderField.limitations),
        ),
      );
    }

    final goal = _answerString(answers, PlannerBuilderField.goal);
    if (_isFatLossGoal(goal)) {
      questions.add(_cardioQuestion(ar));
    }

    questions.add(_styleQuestion(ar));

    if (_isStrengthOrShapeGoal(goal)) {
      questions.add(_focusAreasQuestion(ar));
    }

    questions.addAll([
      _preferredDaysQuestion(ar),
      _intensityQuestion(ar),
      _dislikesQuestion(ar),
    ]);

    return PlannerBuilderBuildResult(
      questions: questions,
      answers: answers,
      knownFacts: _knownFacts(context, answers),
    );
  }

  Map<PlannerBuilderField, PlannerBuilderAnswer> buildInitialAnswers(
    PlannerBuilderKnownContext context,
  ) {
    final answers = <PlannerBuilderField, PlannerBuilderAnswer>{};
    final profile = context.profile;
    final memories = context.memories;

    void put(
      PlannerBuilderField field,
      Object? value,
      PlannerBuilderAnswerSource source, {
      String? label,
    }) {
      if (!_valueHasContent(value)) {
        return;
      }
      answers[field] = PlannerBuilderAnswer(
        field: field,
        value: value,
        source: source,
        label: label,
        confirmed: source != PlannerBuilderAnswerSource.user,
      );
    }

    put(
      PlannerBuilderField.goal,
      _memoryValue(memories, 'goal') ?? profile?.goal,
      _memoryValue(memories, 'goal') == null
          ? PlannerBuilderAnswerSource.profile
          : PlannerBuilderAnswerSource.memory,
    );
    put(
      PlannerBuilderField.experienceLevel,
      _normalizeExperience(
        _memoryValue(memories, 'experience_level') ?? profile?.experienceLevel,
      ),
      _memoryValue(memories, 'experience_level') == null
          ? PlannerBuilderAnswerSource.profile
          : PlannerBuilderAnswerSource.memory,
    );

    final memoryDays = _memoryInt(memories, 'days_per_week');
    put(
      PlannerBuilderField.daysPerWeek,
      memoryDays ?? parseTrainingFrequency(profile?.trainingFrequency),
      memoryDays == null
          ? PlannerBuilderAnswerSource.profile
          : PlannerBuilderAnswerSource.memory,
    );

    final memoryMinutes = _memoryInt(memories, 'session_minutes');
    put(
      PlannerBuilderField.sessionMinutes,
      memoryMinutes ?? _averageRecentSessionMinutes(context.workoutSessions),
      memoryMinutes == null
          ? PlannerBuilderAnswerSource.history
          : PlannerBuilderAnswerSource.memory,
    );

    put(
      PlannerBuilderField.trainingLocation,
      profile?.trainingPlace,
      PlannerBuilderAnswerSource.profile,
    );

    final memoryEquipment = _memoryList(memories, 'equipment');
    final inferredEquipment = _equipmentFromTrainingPlace(
      profile?.trainingPlace,
    );
    put(
      PlannerBuilderField.equipment,
      memoryEquipment.isNotEmpty ? memoryEquipment : inferredEquipment,
      memoryEquipment.isNotEmpty
          ? PlannerBuilderAnswerSource.memory
          : PlannerBuilderAnswerSource.inferred,
    );

    final memoryLimitations = _memoryList(memories, 'limitations');
    put(
      PlannerBuilderField.limitations,
      memoryLimitations,
      PlannerBuilderAnswerSource.memory,
    );
    put(
      PlannerBuilderField.preferredDays,
      _memoryList(memories, 'preferred_days'),
      PlannerBuilderAnswerSource.memory,
    );
    put(
      PlannerBuilderField.dislikes,
      _memoryList(memories, 'exercise_dislikes'),
      PlannerBuilderAnswerSource.memory,
    );

    final seed = context.seedPrompt?.trim();
    if (seed != null && seed.isNotEmpty) {
      final lower = seed.toLowerCase();
      if (lower.contains('fat loss') || lower.contains('lose weight')) {
        put(
          PlannerBuilderField.goal,
          'weight_loss',
          PlannerBuilderAnswerSource.seed,
        );
      } else if (lower.contains('strength')) {
        put(
          PlannerBuilderField.goal,
          'strength',
          PlannerBuilderAnswerSource.seed,
        );
      }
    }

    return answers;
  }

  static int? parseTrainingFrequency(String? value) {
    switch (value?.trim().toLowerCase()) {
      case '1_2_days_per_week':
      case '1-2 days/week':
        return 2;
      case '3_4_days_per_week':
      case '3-4 days/week':
        return 4;
      case '5_6_days_per_week':
      case '5-6 days/week':
        return 5;
      case 'daily':
      case 'every day':
        return 6;
      default:
        return null;
    }
  }

  PlannerBuilderQuestion questionForMissingField(String fieldName, bool ar) {
    switch (fieldName.trim().toLowerCase()) {
      case 'goal':
        return _goalQuestion(ar, false);
      case 'experience_level':
        return _experienceQuestion(ar, false);
      case 'days_per_week':
        return _daysQuestion(ar, false);
      case 'session_minutes':
        return _durationQuestion(ar, false);
      case 'equipment':
        return _equipmentQuestion(ar, false, null);
      case 'limitations':
        return _limitationsQuestion(ar, false);
      default:
        return _dislikesQuestion(ar);
    }
  }

  PlannerBuilderQuestion _goalQuestion(bool ar, bool confirmation) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.goal,
      title: confirmation
          ? (ar ? 'هل هذا هو هدفك الأساسي؟' : 'Is this still your main goal?')
          : (ar
                ? 'ما هدفك الأساسي الآن؟'
                : 'What is your main goal right now?'),
      description: ar
          ? 'سنستخدم هذا لتحديد نوع التمرين والحجم الأسبوعي وطريقة التقدم.'
          : 'This guides the training split, weekly volume, and progression style.',
      inputKind: PlannerBuilderInputKind.singleChoice,
      required: true,
      confirmation: confirmation,
      options: [
        PlannerBuilderOption(
          value: 'weight_loss',
          label: ar ? 'خسارة دهون' : 'Fat loss',
          description: ar
              ? 'حرق دهون وخطة سهلة الالتزام.'
              : 'Lose fat with a sustainable weekly routine.',
        ),
        PlannerBuilderOption(
          value: 'build_muscle',
          label: ar ? 'زيادة عضلات' : 'Build muscle',
          description: ar
              ? 'زيادة قوة وحجم عضلي تدريجيا.'
              : 'Add size and strength with progressive work.',
        ),
        PlannerBuilderOption(
          value: 'body_recomposition',
          label: ar ? 'تحسين الشكل' : 'Recomposition',
          description: ar
              ? 'دهون أقل وقوة وشكل أفضل.'
              : 'Lose fat while improving shape and strength.',
        ),
        PlannerBuilderOption(
          value: 'general_fitness',
          label: ar ? 'لياقة عامة' : 'General fitness',
          description: ar
              ? 'طاقة وحركة واستمرارية.'
              : 'Improve energy, movement, and consistency.',
        ),
        PlannerBuilderOption(
          value: 'strength',
          label: ar ? 'قوة' : 'Strength',
          description: ar
              ? 'تركيز على الأداء والأوزان.'
              : 'Focus on performance and heavier lifts.',
        ),
      ],
    );
  }

  PlannerBuilderQuestion _experienceQuestion(bool ar, bool confirmation) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.experienceLevel,
      title: confirmation
          ? (ar
                ? 'هل مستوى خبرتك ما زال صحيحا؟'
                : 'Is this training level still accurate?')
          : (ar ? 'ما مستوى خبرتك؟' : 'What is your training experience?'),
      description: ar
          ? 'نضبط صعوبة الخطة والتعليمات حسب خبرتك.'
          : 'The builder adjusts complexity, intensity, and exercise coaching around this.',
      inputKind: PlannerBuilderInputKind.singleChoice,
      required: true,
      confirmation: confirmation,
      options: [
        PlannerBuilderOption(
          value: 'beginner',
          label: ar ? 'مبتدئ' : 'Beginner',
        ),
        PlannerBuilderOption(
          value: 'intermediate',
          label: ar ? 'متوسط' : 'Intermediate',
        ),
        PlannerBuilderOption(
          value: 'advanced',
          label: ar ? 'متقدم' : 'Advanced',
        ),
        PlannerBuilderOption(value: 'athlete', label: ar ? 'رياضي' : 'Athlete'),
      ],
    );
  }

  PlannerBuilderQuestion _daysQuestion(bool ar, bool confirmation) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.daysPerWeek,
      title: confirmation
          ? (ar
                ? 'هل يناسبك هذا العدد أسبوعيا؟'
                : 'Does this weekly rhythm still work?')
          : (ar
                ? 'كم يوم يمكنك التمرين أسبوعيا؟'
                : 'How many days can you train each week?'),
      description: ar
          ? 'اختر عدد أيام واقعي يسهل الحفاظ عليه.'
          : 'Choose the realistic number of days you can repeat consistently.',
      inputKind: PlannerBuilderInputKind.singleChoice,
      required: true,
      confirmation: confirmation,
      options: [
        PlannerBuilderOption(value: '2', label: ar ? 'يومان' : '2 days'),
        PlannerBuilderOption(value: '3', label: ar ? '3 أيام' : '3 days'),
        PlannerBuilderOption(value: '4', label: ar ? '4 أيام' : '4 days'),
        PlannerBuilderOption(value: '5', label: ar ? '5 أيام' : '5 days'),
        PlannerBuilderOption(value: '6', label: ar ? '6 أيام' : '6 days'),
      ],
    );
  }

  PlannerBuilderQuestion _durationQuestion(bool ar, bool confirmation) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.sessionMinutes,
      title: confirmation
          ? (ar ? 'هل مدة الجلسة مناسبة؟' : 'Is this session length realistic?')
          : (ar ? 'كم دقيقة للجلسة؟' : 'How long should each session be?'),
      description: ar
          ? 'الخطة ستكون أفضل عندما تناسب وقتك الحقيقي.'
          : 'Plans work better when the session length matches your real schedule.',
      inputKind: PlannerBuilderInputKind.slider,
      required: true,
      confirmation: confirmation,
      min: 20,
      max: 90,
      divisions: 14,
      valueSuffix: ar ? ' دقيقة' : ' min',
    );
  }

  PlannerBuilderQuestion _locationQuestion(bool ar, bool confirmation) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.trainingLocation,
      title: confirmation
          ? (ar ? 'هل مكان التمرين صحيح؟' : 'Is this where you will train?')
          : (ar ? 'أين ستتمرن غالبا؟' : 'Where will you train most often?'),
      description: ar
          ? 'المكان يحدد الأجهزة والبدائل.'
          : 'Location changes the equipment assumptions and exercise alternatives.',
      inputKind: PlannerBuilderInputKind.singleChoice,
      confirmation: confirmation,
      options: [
        PlannerBuilderOption(value: 'home', label: ar ? 'المنزل' : 'Home'),
        PlannerBuilderOption(value: 'gym', label: ar ? 'الجيم' : 'Gym'),
        PlannerBuilderOption(value: 'both', label: ar ? 'الاثنان' : 'Both'),
        PlannerBuilderOption(
          value: 'outdoors',
          label: ar ? 'خارجي' : 'Outdoors',
        ),
      ],
    );
  }

  PlannerBuilderQuestion _equipmentQuestion(
    bool ar,
    bool confirmation,
    String? location,
  ) {
    final home = location == 'home';
    final gym = location == 'gym';
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.equipment,
      title: confirmation
          ? (ar ? 'راجع الأجهزة المتاحة' : 'Review available equipment')
          : (ar ? 'ما الأجهزة المتاحة لك؟' : 'What equipment can you use?'),
      description: ar
          ? 'اختر كل ما يمكن استخدامه فعلا في الخطة.'
          : 'Select everything the plan can realistically use.',
      inputKind: PlannerBuilderInputKind.multiChoice,
      required: true,
      confirmation: confirmation,
      options: [
        PlannerBuilderOption(
          value: 'bodyweight',
          label: ar ? 'وزن الجسم' : 'Bodyweight',
        ),
        PlannerBuilderOption(
          value: 'resistance_bands',
          label: ar ? 'أحبال مقاومة' : 'Bands',
        ),
        PlannerBuilderOption(
          value: 'dumbbells',
          label: ar ? 'دمبلز' : 'Dumbbells',
        ),
        PlannerBuilderOption(
          value: 'kettlebell',
          label: ar ? 'كيتل بيل' : 'Kettlebell',
        ),
        PlannerBuilderOption(value: 'bench', label: ar ? 'بنش' : 'Bench'),
        PlannerBuilderOption(value: 'barbell', label: ar ? 'بار' : 'Barbell'),
        PlannerBuilderOption(
          value: 'machines',
          label: ar ? 'أجهزة' : 'Machines',
        ),
        PlannerBuilderOption(
          value: 'cardio_machine',
          label: ar ? 'كارديو' : 'Cardio machine',
        ),
        if (gym)
          PlannerBuilderOption(
            value: 'full_gym',
            label: ar ? 'جيم كامل' : 'Full gym',
          ),
        if (home)
          PlannerBuilderOption(value: 'yoga_mat', label: ar ? 'مات' : 'Mat'),
      ],
    );
  }

  PlannerBuilderQuestion _limitationsQuestion(bool ar, bool confirmation) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.limitations,
      title: confirmation
          ? (ar
                ? 'هل توجد حدود أو إصابات جديدة؟'
                : 'Any new limitations or injuries?')
          : (ar
                ? 'هل لديك إصابات أو حركات يجب تجنبها؟'
                : 'Any injuries or movements to avoid?'),
      description: ar
          ? 'هذا يساعدنا على جعل الخطة آمنة وواقعية.'
          : 'This keeps the plan safer and more realistic.',
      inputKind: PlannerBuilderInputKind.multiChoice,
      confirmation: confirmation,
      options: [
        PlannerBuilderOption(value: 'none', label: ar ? 'لا يوجد' : 'None'),
        PlannerBuilderOption(value: 'knee', label: ar ? 'ركبة' : 'Knee'),
        PlannerBuilderOption(
          value: 'lower_back',
          label: ar ? 'أسفل الظهر' : 'Lower back',
        ),
        PlannerBuilderOption(value: 'shoulder', label: ar ? 'كتف' : 'Shoulder'),
        PlannerBuilderOption(value: 'wrist', label: ar ? 'رسغ' : 'Wrist'),
        PlannerBuilderOption(
          value: 'low_impact',
          label: ar ? 'بدون ضغط عالي' : 'Low impact',
        ),
      ],
    );
  }

  PlannerBuilderQuestion _cardioQuestion(bool ar) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.cardioPreference,
      title: ar
          ? 'ما نوع الكارديو المناسب لك؟'
          : 'What cardio style fits you best?',
      description: ar
          ? 'سنستخدمه لدعم هدف خسارة الدهون بدون إزعاج زائد.'
          : 'This supports fat loss without making the week feel punishing.',
      inputKind: PlannerBuilderInputKind.singleChoice,
      options: [
        PlannerBuilderOption(value: 'walking', label: ar ? 'مشي' : 'Walking'),
        PlannerBuilderOption(value: 'bike', label: ar ? 'دراجة' : 'Bike'),
        PlannerBuilderOption(
          value: 'intervals',
          label: ar ? 'فواصل قصيرة' : 'Intervals',
        ),
        PlannerBuilderOption(
          value: 'no_preference',
          label: ar ? 'لا يهم' : 'No preference',
        ),
      ],
    );
  }

  PlannerBuilderQuestion _styleQuestion(bool ar) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.workoutStyle,
      title: ar ? 'أي أسلوب تفضل؟' : 'What workout style do you prefer?',
      description: ar
          ? 'اختيارك يساعد الخطة أن تبدو مناسبة لك.'
          : 'This helps the plan feel like something you would actually do.',
      inputKind: PlannerBuilderInputKind.singleChoice,
      options: [
        PlannerBuilderOption(
          value: 'balanced',
          label: ar ? 'متوازن' : 'Balanced',
        ),
        PlannerBuilderOption(
          value: 'strength_first',
          label: ar ? 'قوة أولا' : 'Strength first',
        ),
        PlannerBuilderOption(
          value: 'conditioning',
          label: ar ? 'لياقة وكارديو' : 'Conditioning',
        ),
        PlannerBuilderOption(
          value: 'mobility',
          label: ar ? 'حركة ومرونة' : 'Mobility',
        ),
      ],
    );
  }

  PlannerBuilderQuestion _focusAreasQuestion(bool ar) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.focusAreas,
      title: ar
          ? 'أي مناطق تريد التركيز عليها؟'
          : 'Which areas should get extra focus?',
      description: ar
          ? 'اختر الأولويات العضلية لو لديك تفضيل واضح.'
          : 'Choose muscle priorities if you have a clear preference.',
      inputKind: PlannerBuilderInputKind.multiChoice,
      options: [
        PlannerBuilderOption(value: 'glutes', label: ar ? 'المؤخرة' : 'Glutes'),
        PlannerBuilderOption(value: 'legs', label: ar ? 'الأرجل' : 'Legs'),
        PlannerBuilderOption(value: 'back', label: ar ? 'الظهر' : 'Back'),
        PlannerBuilderOption(value: 'chest', label: ar ? 'الصدر' : 'Chest'),
        PlannerBuilderOption(
          value: 'shoulders',
          label: ar ? 'الأكتاف' : 'Shoulders',
        ),
        PlannerBuilderOption(value: 'core', label: ar ? 'البطن' : 'Core'),
      ],
    );
  }

  PlannerBuilderQuestion _preferredDaysQuestion(bool ar) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.preferredDays,
      title: ar ? 'ما الأيام الأنسب للتمرين؟' : 'Which days fit training best?',
      description: ar
          ? 'اختياري، لكنه يساعد في تنظيم الجدول.'
          : 'Optional, but it helps shape the weekly schedule.',
      inputKind: PlannerBuilderInputKind.multiChoice,
      options: [
        PlannerBuilderOption(value: 'monday', label: ar ? 'الاثنين' : 'Mon'),
        PlannerBuilderOption(value: 'tuesday', label: ar ? 'الثلاثاء' : 'Tue'),
        PlannerBuilderOption(
          value: 'wednesday',
          label: ar ? 'الأربعاء' : 'Wed',
        ),
        PlannerBuilderOption(value: 'thursday', label: ar ? 'الخميس' : 'Thu'),
        PlannerBuilderOption(value: 'friday', label: ar ? 'الجمعة' : 'Fri'),
        PlannerBuilderOption(value: 'saturday', label: ar ? 'السبت' : 'Sat'),
        PlannerBuilderOption(value: 'sunday', label: ar ? 'الأحد' : 'Sun'),
      ],
    );
  }

  PlannerBuilderQuestion _intensityQuestion(bool ar) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.intensity,
      title: ar ? 'ما مستوى الشدة المناسب؟' : 'What intensity feels right?',
      description: ar
          ? 'يمكنك رفع الشدة لاحقا بعد الالتزام.'
          : 'You can increase this later after the habit is stable.',
      inputKind: PlannerBuilderInputKind.singleChoice,
      options: [
        PlannerBuilderOption(value: 'gentle', label: ar ? 'هادئ' : 'Gentle'),
        PlannerBuilderOption(
          value: 'moderate',
          label: ar ? 'متوسط' : 'Moderate',
        ),
        PlannerBuilderOption(
          value: 'challenging',
          label: ar ? 'صعب' : 'Challenging',
        ),
      ],
    );
  }

  PlannerBuilderQuestion _dislikesQuestion(bool ar) {
    return PlannerBuilderQuestion(
      field: PlannerBuilderField.dislikes,
      title: ar ? 'هل هناك تمارين لا تحبها؟' : 'Any exercises you dislike?',
      description: ar
          ? 'اختياري. سنحاول استبدالها ببدائل مناسبة.'
          : 'Optional. The plan can use alternatives where possible.',
      inputKind: PlannerBuilderInputKind.multiChoice,
      options: [
        PlannerBuilderOption(
          value: 'burpees',
          label: ar ? 'بيربيز' : 'Burpees',
        ),
        PlannerBuilderOption(value: 'running', label: ar ? 'جري' : 'Running'),
        PlannerBuilderOption(value: 'jumping', label: ar ? 'قفز' : 'Jumping'),
        PlannerBuilderOption(value: 'squats', label: ar ? 'سكوات' : 'Squats'),
        PlannerBuilderOption(value: 'pushups', label: ar ? 'ضغط' : 'Push-ups'),
      ],
    );
  }

  List<String> _knownFacts(
    PlannerBuilderKnownContext context,
    Map<PlannerBuilderField, PlannerBuilderAnswer> answers,
  ) {
    final facts = <String>[];
    if (_hasAnswer(answers, PlannerBuilderField.goal)) {
      facts.add('Goal');
    }
    if (_hasAnswer(answers, PlannerBuilderField.experienceLevel)) {
      facts.add('Experience');
    }
    if (context.latestWeight != null) {
      facts.add('Latest weight');
    }
    if (context.latestMeasurement != null) {
      facts.add('Body measurements');
    }
    if (context.workoutSessions.isNotEmpty) {
      facts.add('Recent workouts');
    }
    if (context.activeAiPlan != null) {
      facts.add('Active AI plan');
    }
    return facts;
  }
}

class PlannerBuilderBuildResult {
  const PlannerBuilderBuildResult({
    required this.questions,
    required this.answers,
    required this.knownFacts,
  });

  final List<PlannerBuilderQuestion> questions;
  final Map<PlannerBuilderField, PlannerBuilderAnswer> answers;
  final List<String> knownFacts;
}

bool _isFatLossGoal(String? goal) {
  switch (goal?.trim().toLowerCase()) {
    case 'weight_loss':
    case 'fat_loss':
    case 'lose_weight':
    case 'body_recomposition':
      return true;
    default:
      return false;
  }
}

bool _isStrengthOrShapeGoal(String? goal) {
  switch (goal?.trim().toLowerCase()) {
    case 'build_muscle':
    case 'muscle_gain':
    case 'body_recomposition':
    case 'strength':
      return true;
    default:
      return false;
  }
}

bool _hasAnswer(
  Map<PlannerBuilderField, PlannerBuilderAnswer> answers,
  PlannerBuilderField field,
) {
  return answers[field]?.hasValue == true;
}

String? _answerString(
  Map<PlannerBuilderField, PlannerBuilderAnswer> answers,
  PlannerBuilderField field,
) {
  return answers[field]?.stringValue;
}

String? _normalizeExperience(Object? value) {
  final normalized = value?.toString().trim().toLowerCase();
  switch (normalized) {
    case 'beginner':
    case 'intermediate':
    case 'advanced':
    case 'athlete':
      return normalized;
    default:
      return null;
  }
}

Object? _memoryValue(Map<String, dynamic> memories, String key) {
  final raw = memories[key];
  if (raw is Map) {
    return raw['value'];
  }
  return raw;
}

int? _memoryInt(Map<String, dynamic> memories, String key) {
  final raw = _memoryValue(memories, key);
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.round();
  }
  return int.tryParse(raw?.toString() ?? '');
}

List<String> _memoryList(Map<String, dynamic> memories, String key) {
  final raw = memories[key];
  final value = raw is Map ? raw['values'] ?? raw['value'] : raw;
  if (value is List<String>) {
    return value;
  }
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final single = value?.toString().trim();
  return single == null || single.isEmpty ? const <String>[] : <String>[single];
}

int? _averageRecentSessionMinutes(List<WorkoutSessionEntity> sessions) {
  final recent = sessions
      .where((session) => session.durationMinutes > 0)
      .take(5);
  if (recent.isEmpty) {
    return null;
  }
  final total = recent.fold<int>(
    0,
    (sum, session) => sum + session.durationMinutes,
  );
  final average = total / recent.length;
  return (average / 5).round() * 5;
}

List<String> _equipmentFromTrainingPlace(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'home':
      return const <String>['bodyweight'];
    case 'gym':
      return const <String>['full_gym'];
    case 'both':
      return const <String>['bodyweight', 'full_gym'];
    default:
      return const <String>[];
  }
}

bool _valueHasContent(Object? value) {
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
