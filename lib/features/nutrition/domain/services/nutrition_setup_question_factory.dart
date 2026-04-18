import '../../../member/domain/entities/member_profile_entity.dart';
import '../../../member/domain/entities/member_progress_entity.dart';
import '../entities/nutrition_entities.dart';

enum NutritionSetupField {
  goal,
  gender,
  age,
  heightCm,
  weightKg,
  trainingFrequency,
  activityLevel,
  dietaryPreference,
  mealCount,
  allergies,
  exclusions,
  preferredCuisines,
  budgetLevel,
  cookingPreference,
  workoutTiming,
}

enum NutritionSetupInputKind { singleChoice, multiChoice, number, slider }

class NutritionSetupQuestion {
  const NutritionSetupQuestion({
    required this.field,
    required this.title,
    required this.description,
    required this.inputKind,
    this.options = const <NutritionSetupOption>[],
    this.required = true,
    this.min,
    this.max,
    this.divisions,
    this.suffix = '',
  });

  final NutritionSetupField field;
  final String title;
  final String description;
  final NutritionSetupInputKind inputKind;
  final List<NutritionSetupOption> options;
  final bool required;
  final double? min;
  final double? max;
  final int? divisions;
  final String suffix;
}

class NutritionSetupOption {
  const NutritionSetupOption(this.value, this.label);

  final String value;
  final String label;
}

class NutritionSetupBuildResult {
  const NutritionSetupBuildResult({
    required this.questions,
    required this.answers,
  });

  final List<NutritionSetupQuestion> questions;
  final Map<NutritionSetupField, Object?> answers;
}

class NutritionSetupQuestionFactory {
  const NutritionSetupQuestionFactory();

  NutritionSetupBuildResult build({
    required MemberProfileEntity? memberProfile,
    required NutritionProfileEntity? nutritionProfile,
    required List<WeightEntryEntity> weightEntries,
    required bool arabic,
  }) {
    final answers = <NutritionSetupField, Object?>{
      NutritionSetupField.goal: memberProfile?.goal,
      NutritionSetupField.gender: memberProfile?.gender,
      NutritionSetupField.age: memberProfile?.age,
      NutritionSetupField.heightCm: memberProfile?.heightCm,
      NutritionSetupField.weightKg: weightEntries.isNotEmpty
          ? weightEntries.last.weightKg
          : memberProfile?.currentWeightKg,
      NutritionSetupField.trainingFrequency: memberProfile?.trainingFrequency,
      NutritionSetupField.activityLevel: nutritionProfile?.activityLevel,
      NutritionSetupField.dietaryPreference:
          nutritionProfile?.dietaryPreference ?? 'balanced',
      NutritionSetupField.mealCount:
          nutritionProfile?.mealCountPreference.clamp(3, 5) ?? 4,
      NutritionSetupField.allergies: nutritionProfile?.allergies ?? const [],
      NutritionSetupField.exclusions:
          nutritionProfile?.foodExclusions ?? const [],
      NutritionSetupField.preferredCuisines:
          nutritionProfile?.preferredCuisines ??
          const <String>['egyptian', 'international'],
      NutritionSetupField.budgetLevel: nutritionProfile?.budgetLevel ?? 'balanced',
      NutritionSetupField.cookingPreference:
          nutritionProfile?.cookingPreference ?? 'simple',
      NutritionSetupField.workoutTiming: nutritionProfile?.workoutTiming,
    }..removeWhere((key, value) => !_hasValue(value));

    final questions = <NutritionSetupQuestion>[];
    void addIfMissing(NutritionSetupQuestion question) {
      if (!_hasValue(answers[question.field])) {
        questions.add(question);
      }
    }

    addIfMissing(_goalQuestion(arabic));
    addIfMissing(_genderQuestion(arabic));
    addIfMissing(_ageQuestion(arabic));
    addIfMissing(_heightQuestion(arabic));
    addIfMissing(_weightQuestion(arabic));
    addIfMissing(_trainingQuestion(arabic));

    questions.addAll(<NutritionSetupQuestion>[
      _activityQuestion(arabic),
      _dietQuestion(arabic),
      _mealCountQuestion(arabic),
      _allergyQuestion(arabic),
      _exclusionsQuestion(arabic),
      _cuisineQuestion(arabic),
      _budgetQuestion(arabic),
      _cookingQuestion(arabic),
      _workoutTimingQuestion(arabic),
    ]);

    return NutritionSetupBuildResult(questions: questions, answers: answers);
  }

  NutritionSetupQuestion _goalQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.goal,
    title: ar ? 'ما هدفك الغذائي؟' : 'What should nutrition support?',
    description: ar
        ? 'سنستخدم الهدف لضبط السعرات والبروتين والكارب.'
        : 'This sets calorie direction, protein, and meal style.',
    inputKind: NutritionSetupInputKind.singleChoice,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('weight_loss', 'Fat loss'),
      NutritionSetupOption('maintenance', 'Maintenance'),
      NutritionSetupOption('build_muscle', 'Muscle gain'),
      NutritionSetupOption('recomposition', 'Recomposition'),
    ],
  );

  NutritionSetupQuestion _genderQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.gender,
    title: ar ? 'ما الجنس المستخدم للحساب؟' : 'Which sex should the formula use?',
    description: ar
        ? 'هذا يؤثر على معادلة السعرات.'
        : 'This affects the BMR formula. You can choose prefer not to say.',
    inputKind: NutritionSetupInputKind.singleChoice,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('male', 'Male'),
      NutritionSetupOption('female', 'Female'),
      NutritionSetupOption('non_binary', 'Non-binary'),
      NutritionSetupOption('prefer_not_to_say', 'Prefer not'),
    ],
  );

  NutritionSetupQuestion _ageQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.age,
    title: ar ? 'كم عمرك؟' : 'How old are you?',
    description: ar ? 'العمر يساعد في حساب معدل الحرق.' : 'Age helps estimate BMR.',
    inputKind: NutritionSetupInputKind.slider,
    min: 13,
    max: 80,
    divisions: 67,
    suffix: ar ? ' سنة' : ' years',
  );

  NutritionSetupQuestion _heightQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.heightCm,
    title: ar ? 'ما طولك؟' : 'What is your height?',
    description: ar ? 'بالسنتيمتر.' : 'Use centimeters for the current app unit.',
    inputKind: NutritionSetupInputKind.slider,
    min: 130,
    max: 220,
    divisions: 90,
    suffix: ' cm',
  );

  NutritionSetupQuestion _weightQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.weightKg,
    title: ar ? 'ما وزنك الحالي؟' : 'What is your current weight?',
    description: ar
        ? 'سيتم استخدامه لحساب السعرات والبروتين.'
        : 'This drives calories, protein, and hydration.',
    inputKind: NutritionSetupInputKind.slider,
    min: 35,
    max: 180,
    divisions: 145,
    suffix: ' kg',
  );

  NutritionSetupQuestion _trainingQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.trainingFrequency,
    title: ar ? 'كم يوم تتمرن أسبوعيا؟' : 'How often do you train?',
    description: ar ? 'التمرين يؤثر على الكارب والسعرات.' : 'Training demand affects calories and carbs.',
    inputKind: NutritionSetupInputKind.singleChoice,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('1_2_days_per_week', '1-2 days'),
      NutritionSetupOption('3_4_days_per_week', '3-4 days'),
      NutritionSetupOption('5_6_days_per_week', '5-6 days'),
      NutritionSetupOption('daily', 'Daily'),
    ],
  );

  NutritionSetupQuestion _activityQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.activityLevel,
    title: ar ? 'كيف تبدو حركتك اليومية؟' : 'How active is your day outside workouts?',
    description: ar ? 'اختر أقرب مستوى لحياتك اليومية.' : 'Choose the closest match for your normal day.',
    inputKind: NutritionSetupInputKind.singleChoice,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('sedentary', 'Mostly seated'),
      NutritionSetupOption('light', 'Light movement'),
      NutritionSetupOption('moderate', 'Moderate'),
      NutritionSetupOption('active', 'Active'),
      NutritionSetupOption('very_active', 'Very active'),
    ],
  );

  NutritionSetupQuestion _dietQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.dietaryPreference,
    title: ar ? 'أي أسلوب أكل تفضله؟' : 'What eating style fits you?',
    description: ar ? 'سنفلتر الوجبات بناء على اختيارك.' : 'Meal suggestions will respect this preference.',
    inputKind: NutritionSetupInputKind.singleChoice,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('balanced', 'Balanced'),
      NutritionSetupOption('high_protein', 'High protein'),
      NutritionSetupOption('vegetarian', 'Vegetarian'),
      NutritionSetupOption('pescatarian', 'Pescatarian'),
      NutritionSetupOption('low_carb', 'Lower carb'),
      NutritionSetupOption('halal', 'Halal'),
    ],
  );

  NutritionSetupQuestion _mealCountQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.mealCount,
    title: ar ? 'كم وجبة تناسب يومك؟' : 'How many meals fit your day?',
    description: ar ? 'سنوزع السعرات على هذا العدد.' : 'Calories will be distributed across this structure.',
    inputKind: NutritionSetupInputKind.singleChoice,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('3', '3 meals'),
      NutritionSetupOption('4', '4 meals'),
      NutritionSetupOption('5', '5 meals'),
    ],
  );

  NutritionSetupQuestion _allergyQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.allergies,
    title: ar ? 'هل لديك حساسية طعام؟' : 'Any allergies to avoid?',
    description: ar ? 'سنستبعد الوجبات التي تحتوي عليها.' : 'These foods will be excluded from meal suggestions.',
    inputKind: NutritionSetupInputKind.multiChoice,
    required: false,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('eggs', 'Eggs'),
      NutritionSetupOption('dairy', 'Dairy'),
      NutritionSetupOption('fish', 'Fish'),
      NutritionSetupOption('nuts', 'Nuts'),
      NutritionSetupOption('gluten', 'Gluten'),
    ],
  );

  NutritionSetupQuestion _exclusionsQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.exclusions,
    title: ar ? 'أطعمة لا تحبها؟' : 'Foods you want to avoid?',
    description: ar ? 'اختيارات سريعة لتخصيص الخطة.' : 'Quick exclusions help the plan feel realistic.',
    inputKind: NutritionSetupInputKind.multiChoice,
    required: false,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('tuna', 'Tuna'),
      NutritionSetupOption('eggs', 'Eggs'),
      NutritionSetupOption('oats', 'Oats'),
      NutritionSetupOption('rice', 'Rice'),
      NutritionSetupOption('chicken', 'Chicken'),
    ],
  );

  NutritionSetupQuestion _cuisineQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.preferredCuisines,
    title: ar ? 'أي مطابخ تفضل؟' : 'Which food style should we bias toward?',
    description: ar ? 'سنبدأ باختيارات مصرية وعالمية.' : 'GymUnity will prioritize matching templates.',
    inputKind: NutritionSetupInputKind.multiChoice,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('egyptian', 'Egyptian'),
      NutritionSetupOption('arabic', 'Arabic'),
      NutritionSetupOption('mediterranean', 'Mediterranean'),
      NutritionSetupOption('international', 'International'),
    ],
  );

  NutritionSetupQuestion _budgetQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.budgetLevel,
    title: ar ? 'ما مستوى الميزانية؟' : 'What budget level should meals target?',
    description: ar ? 'هذا يساعد في جعل الخطة عملية.' : 'This keeps the meal plan realistic.',
    inputKind: NutritionSetupInputKind.singleChoice,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('budget', 'Budget'),
      NutritionSetupOption('balanced', 'Balanced'),
      NutritionSetupOption('premium', 'Premium'),
    ],
  );

  NutritionSetupQuestion _cookingQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.cookingPreference,
    title: ar ? 'كم تحب الطبخ؟' : 'How much cooking fits your routine?',
    description: ar ? 'سنختار وجبات تناسب وقتك.' : 'Meal templates will match your prep style.',
    inputKind: NutritionSetupInputKind.singleChoice,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('minimal', 'Minimal'),
      NutritionSetupOption('simple', 'Simple'),
      NutritionSetupOption('meal_prep', 'Meal prep'),
      NutritionSetupOption('fresh', 'Fresh cooking'),
    ],
  );

  NutritionSetupQuestion _workoutTimingQuestion(bool ar) => NutritionSetupQuestion(
    field: NutritionSetupField.workoutTiming,
    title: ar ? 'متى تتمرن غالبا؟' : 'When do you usually train?',
    description: ar ? 'سنستخدم هذا لتوجيه السناك حول التمرين.' : 'This helps place snacks around workouts.',
    inputKind: NutritionSetupInputKind.singleChoice,
    required: false,
    options: const <NutritionSetupOption>[
      NutritionSetupOption('morning', 'Morning'),
      NutritionSetupOption('midday', 'Midday'),
      NutritionSetupOption('evening', 'Evening'),
      NutritionSetupOption('varies', 'Varies'),
    ],
  );

  bool _hasValue(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is num) return value > 0;
    return true;
  }
}
