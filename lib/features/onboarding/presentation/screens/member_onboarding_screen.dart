import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/localization/app_localization_extension.dart';
import '../../../../core/theme/atelier_theme.dart';
import '../../../user/presentation/controllers/onboarding_controller.dart';

class MemberOnboardingScreen extends ConsumerStatefulWidget {
  const MemberOnboardingScreen({super.key});

  @override
  ConsumerState<MemberOnboardingScreen> createState() =>
      _MemberOnboardingScreenState();
}

class _MemberOnboardingScreenState
    extends ConsumerState<MemberOnboardingScreen> {
  static const int _totalSteps = 4;

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  final _budgetController = TextEditingController();
  final _cityController = TextEditingController();

  List<_GoalOption> get _goals => <_GoalOption>[
    _GoalOption(
      value: 'weight_loss',
      title: context.l10n.loseWeight,
      description: context.l10n.loseWeightDesc,
      icon: Icons.monitor_weight_outlined,
      accent: AtelierColors.primary,
    ),
    _GoalOption(
      value: 'build_muscle',
      title: context.l10n.buildMuscle,
      description: context.l10n.buildMuscleDesc,
      icon: Icons.fitness_center,
      accent: Color(0xFF5C8A6E),
    ),
    _GoalOption(
      value: 'body_recomposition',
      title: context.l10n.recompose,
      description: context.l10n.recomposeDesc,
      icon: Icons.bolt,
      accent: Color(0xFF7C6F62),
    ),
    _GoalOption(
      value: 'general_fitness',
      title: context.l10n.generalFitness,
      description: context.l10n.generalFitnessDesc,
      icon: Icons.favorite_outline,
      accent: AtelierColors.primaryContainer,
    ),
  ];

  final List<String> _experienceLevels = const <String>[
    'Beginner',
    'Intermediate',
    'Advanced',
    'Athlete',
  ];
  final List<String> _frequencies = const <String>[
    '1-2 days/week',
    '3-4 days/week',
    '5-6 days/week',
    'Every day',
  ];

  int _currentStep = 0;
  int _selectedGoal = -1;
  int _selectedExperience = -1;
  int _selectedFrequency = -1;
  String? _selectedGender;
  String? _selectedCoachingPreference;
  String? _selectedTrainingPlace;
  String? _selectedLanguage;
  String? _selectedCoachGender;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _budgetController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (!_validateCurrentStep()) {
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep += 1);
      return;
    }

    await _submitOnboarding();
  }

  Future<void> _submitOnboarding() async {
    final age = _parseInt(_ageController);
    final height = _parseDouble(_heightController);
    final weight = _parseDouble(_weightController);
    final budget = _parseInt(_budgetController);

    if (_selectedGoal < 0 ||
        age == null ||
        height == null ||
        weight == null ||
        budget == null ||
        _selectedGender == null ||
        _selectedCoachingPreference == null ||
        _selectedTrainingPlace == null ||
        _selectedLanguage == null ||
        _selectedCoachGender == null ||
        _selectedExperience < 0 ||
        _selectedFrequency < 0) {
      _showMessage(context.l10n.completeOnboarding);
      return;
    }

    final success = await ref
        .read(onboardingControllerProvider.notifier)
        .completeMemberOnboarding(
          goal: _goals[_selectedGoal].value,
          age: age,
          gender: _selectedGender!.toLowerCase(),
          heightCm: height,
          currentWeightKg: weight,
          trainingFrequency: _frequencyValue(_frequencies[_selectedFrequency]),
          experienceLevel: _experienceLevels[_selectedExperience].toLowerCase(),
          budgetEgp: budget,
          city: _cityController.text.trim(),
          coachingPreference: _selectedCoachingPreference,
          trainingPlace: _selectedTrainingPlace,
          preferredLanguage: _selectedLanguage,
          preferredCoachGender: _selectedCoachGender,
        );

    if (!mounted) {
      return;
    }
    if (!success) {
      _showMessage(
        ref.read(onboardingControllerProvider).errorMessage ??
            context.l10n.unableCompleteOnboarding,
      );
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.memberHome,
      (route) => false,
    );
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _validateGoalStep();
      case 1:
        return _validateBaselineStep();
      case 2:
        return _validateMatchStep();
      case 3:
        return _validateTrainingStep();
      default:
        return false;
    }
  }

  bool _validateGoalStep() {
    if (_selectedGoal < 0) {
      _showMessage(context.l10n.chooseGoalToContinue);
      return false;
    }
    return true;
  }

  bool _validateBaselineStep() {
    final height = _parseDouble(_heightController);
    final weight = _parseDouble(_weightController);
    final age = _parseInt(_ageController);
    final city = _cityController.text.trim();

    if (_selectedGender == null) {
      _showMessage(context.l10n.chooseGenderToContinue);
      return false;
    }
    if (height == null || height < 80 || height > 250) {
      _showMessage(context.l10n.enterRealisticHeight);
      return false;
    }
    if (weight == null || weight < 30 || weight > 300) {
      _showMessage(context.l10n.enterRealisticWeight);
      return false;
    }
    if (age == null || age < 13 || age > 100) {
      _showMessage(context.l10n.enterValidAge);
      return false;
    }
    if (city.isEmpty) {
      _showMessage(context.l10n.addCity);
      return false;
    }
    return true;
  }

  bool _validateMatchStep() {
    final budget = _parseInt(_budgetController);

    if (budget == null || budget <= 0) {
      _showMessage(context.l10n.addBudget);
      return false;
    }
    if (_selectedCoachingPreference == null) {
      _showMessage(context.l10n.chooseCoachingMode);
      return false;
    }
    if (_selectedTrainingPlace == null) {
      _showMessage(context.l10n.chooseTrainingPlace);
      return false;
    }
    if (_selectedLanguage == null) {
      _showMessage(context.l10n.choosePreferredCoachingLanguage);
      return false;
    }
    if (_selectedCoachGender == null) {
      _showMessage(context.l10n.choosePreferredCoachGender);
      return false;
    }
    return true;
  }

  bool _validateTrainingStep() {
    if (_selectedExperience < 0) {
      _showMessage(context.l10n.chooseExperience);
      return false;
    }
    if (_selectedFrequency < 0) {
      _showMessage(context.l10n.chooseFrequency);
      return false;
    }
    return true;
  }

  int? _parseInt(TextEditingController controller) {
    return int.tryParse(controller.text.trim());
  }

  double? _parseDouble(TextEditingController controller) {
    return double.tryParse(controller.text.trim());
  }

  void _previousStep() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _currentStep -= 1);
  }

  String _frequencyValue(String raw) {
    switch (raw) {
      case '1-2 days/week':
        return '1_2_days_per_week';
      case '3-4 days/week':
        return '3_4_days_per_week';
      case '5-6 days/week':
        return '5_6_days_per_week';
      case 'Every day':
        return 'daily';
      default:
        return raw.trim().toLowerCase().replaceAll(' ', '_');
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);

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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Row(
                    children: [
                      _IconCircleButton(
                        icon: Directionality.of(context) == TextDirection.rtl
                            ? Icons.arrow_forward_rounded
                            : Icons.arrow_back_rounded,
                        onTap: _previousStep,
                      ),
                      const Spacer(),
                      _ProgressPill(
                        step: _currentStep + 1,
                        totalSteps: _totalSteps,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: Padding(
                      key: ValueKey<int>(_currentStep),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildStep(),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                  decoration: const BoxDecoration(
                    color: AtelierColors.surfaceContainerLowest,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PrimaryButton(
                        label: _currentStep == _totalSteps - 1
                            ? context.l10n.getStarted
                            : context.l10n.continueAction,
                        isLoading: state.isLoading,
                        onTap: _nextStep,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _footerNote(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          height: 1.45,
                          color: AtelierColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return SingleChildScrollView(
          key: const ValueKey<String>('goal-step'),
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepHeader(
                eyebrow: context.l10n.goalSetup,
                title: context.l10n.memberGoalTitle,
                subtitle: context.l10n.memberGoalSubtitle,
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _goals.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, index) => _GoalCard(
                  option: _goals[index],
                  selected: index == _selectedGoal,
                  onTap: () => setState(() => _selectedGoal = index),
                ),
              ),
            ],
          ),
        );
      case 1:
        return SingleChildScrollView(
          key: const ValueKey<String>('baseline-step'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepHeader(
                eyebrow: context.l10n.baseline,
                title: context.l10n.memberBaselineTitle,
                subtitle: context.l10n.memberBaselineSubtitle,
              ),
              const SizedBox(height: 18),
              _SectionLabel(text: context.l10n.gender),
              const SizedBox(height: 10),
              Row(
                children: ['Male', 'Female']
                    .map((gender) {
                      final selected = _selectedGender == gender;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: gender == 'Male' ? AppSizes.sm : 0,
                          ),
                          child: _ChoiceTile(
                            label: _genderLabel(gender),
                            selected: selected,
                            onTap: () =>
                                setState(() => _selectedGender = gender),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricField(
                      label: context.l10n.height,
                      suffix: 'cm',
                      hintText: context.l10n.heightHint,
                      controller: _heightController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricField(
                      label: context.l10n.weight,
                      suffix: 'kg',
                      hintText: context.l10n.weightHint,
                      controller: _weightController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricField(
                      label: context.l10n.age,
                      suffix: 'years',
                      hintText: context.l10n.ageHint,
                      controller: _ageController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricField(
                      label: context.l10n.city,
                      hintText: context.l10n.cityHint,
                      controller: _cityController,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case 2:
        return SingleChildScrollView(
          key: const ValueKey<String>('match-step'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepHeader(
                eyebrow: context.l10n.coachMatch,
                title: context.l10n.memberCoachMatchTitle,
                subtitle: context.l10n.memberCoachMatchSubtitle,
              ),
              const SizedBox(height: 18),
              _MetricField(
                label: context.l10n.monthlyBudget,
                suffix: 'EGP',
                hintText: context.l10n.budgetHint,
                controller: _budgetController,
              ),
              const SizedBox(height: 16),
              _SectionLabel(text: context.l10n.coachingMode),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ChoicePill(
                    label: context.l10n.online,
                    selected: _selectedCoachingPreference == 'online',
                    onTap: () =>
                        setState(() => _selectedCoachingPreference = 'online'),
                  ),
                  _ChoicePill(
                    label: context.l10n.inPerson,
                    selected: _selectedCoachingPreference == 'in_person',
                    onTap: () => setState(
                      () => _selectedCoachingPreference = 'in_person',
                    ),
                  ),
                  _ChoicePill(
                    label: context.l10n.hybrid,
                    selected: _selectedCoachingPreference == 'hybrid',
                    onTap: () =>
                        setState(() => _selectedCoachingPreference = 'hybrid'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionLabel(text: context.l10n.trainingPlace),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ChoicePill(
                    label: context.l10n.home,
                    selected: _selectedTrainingPlace == 'home',
                    onTap: () =>
                        setState(() => _selectedTrainingPlace = 'home'),
                  ),
                  _ChoicePill(
                    label: context.l10n.gym,
                    selected: _selectedTrainingPlace == 'gym',
                    onTap: () => setState(() => _selectedTrainingPlace = 'gym'),
                  ),
                  _ChoicePill(
                    label: context.l10n.both,
                    selected: _selectedTrainingPlace == 'both',
                    onTap: () =>
                        setState(() => _selectedTrainingPlace = 'both'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionLabel(text: context.l10n.preferredLanguage),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceTile(
                      label: context.l10n.arabic,
                      selected: _selectedLanguage == 'arabic',
                      onTap: () => setState(() => _selectedLanguage = 'arabic'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChoiceTile(
                      label: context.l10n.english,
                      selected: _selectedLanguage == 'english',
                      onTap: () =>
                          setState(() => _selectedLanguage = 'english'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionLabel(text: context.l10n.preferredCoachGender),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ChoicePill(
                    label: context.l10n.any,
                    selected: _selectedCoachGender == 'any',
                    onTap: () => setState(() => _selectedCoachGender = 'any'),
                  ),
                  _ChoicePill(
                    label: context.l10n.male,
                    selected: _selectedCoachGender == 'male',
                    onTap: () => setState(() => _selectedCoachGender = 'male'),
                  ),
                  _ChoicePill(
                    label: context.l10n.female,
                    selected: _selectedCoachGender == 'female',
                    onTap: () =>
                        setState(() => _selectedCoachGender = 'female'),
                  ),
                ],
              ),
            ],
          ),
        );
      default:
        return SingleChildScrollView(
          key: const ValueKey<String>('training-step'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepHeader(
                eyebrow: context.l10n.trainingRhythm,
                title: context.l10n.memberTrainingTitle,
                subtitle: context.l10n.memberTrainingSubtitle,
              ),
              const SizedBox(height: 18),
              _SectionLabel(text: context.l10n.experienceLevel),
              const SizedBox(height: 10),
              ...List.generate(_experienceLevels.length, (index) {
                final label = _experienceLevels[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ChoiceTile(
                    label: _experienceLabel(label),
                    helper: _experienceHelper(label),
                    selected: _selectedExperience == index,
                    onTap: () => setState(() => _selectedExperience = index),
                  ),
                );
              }),
              const SizedBox(height: 10),
              _SectionLabel(text: context.l10n.weeklyFrequency),
              const SizedBox(height: 10),
              ...List.generate(_frequencies.length, (index) {
                final label = _frequencies[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ChoiceTile(
                    label: _frequencyLabel(label),
                    helper: _frequencyHelper(label),
                    selected: _selectedFrequency == index,
                    onTap: () => setState(() => _selectedFrequency = index),
                  ),
                );
              }),
            ],
          ),
        );
    }
  }

  String _experienceHelper(String label) {
    switch (label) {
      case 'Beginner':
        return context.l10n.beginnerHelper;
      case 'Intermediate':
        return context.l10n.intermediateHelper;
      case 'Advanced':
        return context.l10n.advancedHelper;
      case 'Athlete':
        return context.l10n.athleteHelper;
      default:
        return '';
    }
  }

  String _experienceLabel(String label) {
    switch (label) {
      case 'Beginner':
        return context.l10n.beginner;
      case 'Intermediate':
        return context.l10n.intermediate;
      case 'Advanced':
        return context.l10n.advanced;
      case 'Athlete':
        return context.l10n.athlete;
      default:
        return label;
    }
  }

  String _frequencyHelper(String label) {
    switch (label) {
      case '1-2 days/week':
        return context.l10n.oneTwoDaysHelper;
      case '3-4 days/week':
        return context.l10n.threeFourDaysHelper;
      case '5-6 days/week':
        return context.l10n.fiveSixDaysHelper;
      case 'Every day':
        return context.l10n.everyDayHelper;
      default:
        return '';
    }
  }

  String _frequencyLabel(String label) {
    switch (label) {
      case '1-2 days/week':
        return context.l10n.oneTwoDays;
      case '3-4 days/week':
        return context.l10n.threeFourDays;
      case '5-6 days/week':
        return context.l10n.fiveSixDays;
      case 'Every day':
        return context.l10n.everyDay;
      default:
        return label;
    }
  }

  String _genderLabel(String value) {
    switch (value) {
      case 'Male':
        return context.l10n.male;
      case 'Female':
        return context.l10n.female;
      default:
        return value;
    }
  }

  String _footerNote() {
    switch (_currentStep) {
      case 0:
        return context.l10n.goalFooter;
      case 1:
        return context.l10n.baselineFooter;
      case 2:
        return context.l10n.matchFooter;
      default:
        return context.l10n.trainingFooter;
    }
  }
}

class _GoalOption {
  const _GoalOption({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
  });

  final String value;
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
            color: AtelierColors.primary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: GoogleFonts.notoSerif(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.08,
            color: AtelierColors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: GoogleFonts.manrope(
            fontSize: 14,
            height: 1.55,
            color: AtelierColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _GoalOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AtelierColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AtelierColors.surfaceContainerLowest
                : AtelierColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? option.accent.withValues(alpha: 0.7)
                  : AtelierColors.ghostBorder,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: AtelierColors.navShadow,
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: option.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(option.icon, color: option.accent, size: 22),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? option.accent : Colors.transparent,
                      border: selected
                          ? null
                          : Border.all(color: AtelierColors.outlineVariant),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: AtelierColors.white,
                            size: 14,
                          )
                        : null,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                option.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.16,
                  color: AtelierColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                option.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  height: 1.45,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricField extends StatelessWidget {
  const _MetricField({
    required this.label,
    required this.controller,
    this.suffix,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final String? suffix;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: suffix == null
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      cursorColor: AtelierColors.primary,
      style: GoogleFonts.manrope(
        color: AtelierColors.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixText: suffix,
        filled: true,
        fillColor: AtelierColors.surfaceContainerLow,
        labelStyle: GoogleFonts.manrope(
          color: AtelierColors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: GoogleFonts.manrope(color: AtelierColors.textMuted),
        suffixStyle: GoogleFonts.manrope(
          color: AtelierColors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AtelierColors.ghostBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AtelierColors.primary),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.helper,
  });

  final String label;
  final String? helper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AtelierColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AtelierColors.primary.withValues(alpha: 0.08)
                : AtelierColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AtelierColors.primary.withValues(alpha: 0.62)
                  : AtelierColors.ghostBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AtelierColors.onSurface,
                ),
              ),
              if (helper != null && helper!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  helper!,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    height: 1.45,
                    color: AtelierColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AtelierColors.primary.withValues(alpha: 0.1),
      backgroundColor: AtelierColors.surfaceContainerLow,
      side: BorderSide(
        color: selected ? AtelierColors.primary : AtelierColors.ghostBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        color: selected
            ? AtelierColors.primary
            : AtelierColors.onSurfaceVariant,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AtelierColors.onSurfaceVariant,
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.step, required this.totalSteps});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AtelierColors.ghostBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            context.l10n.stepOfTotal(step, totalSteps),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: Row(
              children: List.generate(totalSteps, (index) {
                final reached = index < step;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsetsDirectional.only(
                      end: index == totalSteps - 1 ? 0 : 7,
                    ),
                    decoration: BoxDecoration(
                      color: reached
                          ? AtelierColors.primary
                          : AtelierColors.outlineVariant.withValues(
                              alpha: 0.45,
                            ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AtelierColors.surfaceContainerLow,
          border: Border.all(color: AtelierColors.ghostBorder),
        ),
        child: Icon(icon, color: AtelierColors.onSurface, size: 21),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    required this.isLoading,
  });

  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AtelierColors.primary, AtelierColors.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: AtelierColors.navShadow,
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AtelierColors.transparent,
            disabledBackgroundColor: AtelierColors.transparent,
            shadowColor: AtelierColors.transparent,
            surfaceTintColor: AtelierColors.transparent,
            foregroundColor: AtelierColors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AtelierColors.onPrimary,
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: AtelierColors.onPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}
