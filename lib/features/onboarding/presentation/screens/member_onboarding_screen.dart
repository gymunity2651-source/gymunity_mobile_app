import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
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

  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '82');
  final _ageController = TextEditingController(text: '26');
  final _budgetController = TextEditingController(text: '1500');
  final _cityController = TextEditingController(text: 'Cairo');

  final List<_GoalOption> _goals = const <_GoalOption>[
    _GoalOption(
      value: 'weight_loss',
      title: 'Lose Weight',
      description: 'Fat loss, simpler food habits, and weekly accountability.',
      icon: Icons.monitor_weight_outlined,
      accent: AppColors.orange,
    ),
    _GoalOption(
      value: 'build_muscle',
      title: 'Build Muscle',
      description: 'Lean mass, better training structure, and recovery.',
      icon: Icons.fitness_center,
      accent: AppColors.limeGreen,
    ),
    _GoalOption(
      value: 'body_recomposition',
      title: 'Recompose',
      description: 'Lose fat while improving shape and consistency.',
      icon: Icons.bolt,
      accent: AppColors.electricBlue,
    ),
    _GoalOption(
      value: 'general_fitness',
      title: 'General Fitness',
      description: 'Energy, movement, and sustainable habits that stick.',
      icon: Icons.favorite_outline,
      accent: AppColors.orangeLight,
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
  int _selectedGoal = 0;
  int _selectedExperience = -1;
  int _selectedFrequency = -1;
  String _selectedGender = 'Male';
  String _selectedCoachingPreference = 'online';
  String _selectedTrainingPlace = 'home';
  String _selectedLanguage = 'arabic';
  String _selectedCoachGender = 'any';

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
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep += 1);
      return;
    }

    final age = int.tryParse(_ageController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    final budget = int.tryParse(_budgetController.text.trim());
    if (age == null || age < 13) {
      _showMessage('Enter a valid age to continue.');
      return;
    }
    if (height == null || height <= 0) {
      _showMessage('Enter a valid height in centimeters.');
      return;
    }
    if (weight == null || weight <= 0) {
      _showMessage('Enter a valid weight in kilograms.');
      return;
    }
    if (_cityController.text.trim().isEmpty) {
      _showMessage('Add your city so we can match you with the right coaches.');
      return;
    }
    if (budget == null || budget <= 0) {
      _showMessage('Add a realistic monthly budget in EGP.');
      return;
    }
    if (_selectedExperience < 0 || _selectedFrequency < 0) {
      _showMessage('Choose your current level and weekly training frequency.');
      return;
    }

    final success = await ref
        .read(onboardingControllerProvider.notifier)
        .completeMemberOnboarding(
          goal: _goals[_selectedGoal].value,
          age: age,
          gender: _selectedGender.toLowerCase(),
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
            'Unable to complete onboarding right now.',
      );
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.memberHome,
      (route) => false,
    );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final progress = (_currentStep + 1) / _totalSteps;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF05070A), Color(0xFF111722)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.xl,
                  AppSizes.screenPadding,
                  AppSizes.lg,
                ),
                child: Row(
                  children: [
                    _IconCircleButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: _previousStep,
                    ),
                    const Spacer(),
                    _ProgressPill(
                      step: _currentStep + 1,
                      totalSteps: _totalSteps,
                      progress: progress,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.xl),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
                      border: Border.all(
                        color: AppColors.borderSoft.withValues(alpha: 0.5),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.cardDark.withValues(alpha: 0.97),
                          AppColors.surfacePanel.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: _buildStep(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.md,
                  AppSizes.screenPadding,
                  AppSizes.xl,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state.isLoading ? null : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: state.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : Text(
                                _currentStep == _totalSteps - 1
                                    ? 'GET STARTED'
                                    : 'CONTINUE',
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _footerNote(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return Column(
          key: const ValueKey<String>('goal-step'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StepHeader(
              eyebrow: 'Egypt-first setup',
              title: 'What result do you want first?',
              subtitle:
                  'We bias the app toward coaches, offers, and check-ins that actually move this goal.',
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: _goals.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) => _GoalCard(
                  option: _goals[index],
                  selected: index == _selectedGoal,
                  onTap: () => setState(() => _selectedGoal = index),
                ),
              ),
            ),
          ],
        );
      case 1:
        return SingleChildScrollView(
          key: const ValueKey<String>('baseline-step'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _StepHeader(
                eyebrow: 'Baseline',
                title: 'Tell us where you are now',
                subtitle:
                    'This shapes progress tracking, coach recommendations, and your first check-in baseline.',
              ),
              const SizedBox(height: 18),
              const _SectionLabel(text: 'Gender'),
              const SizedBox(height: 10),
              Row(
                children: ['Male', 'Female']
                    .map((gender) {
                      final selected = _selectedGender == gender;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: gender == 'Male' ? AppSizes.sm : 0,
                          ),
                          child: _ChoiceTile(
                            label: gender,
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
                      label: 'Height',
                      suffix: 'cm',
                      controller: _heightController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricField(
                      label: 'Weight',
                      suffix: 'kg',
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
                      label: 'Age',
                      suffix: 'years',
                      controller: _ageController,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricField(
                      label: 'City',
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
              const _StepHeader(
                eyebrow: 'Coach match',
                title: 'What kind of coaching fits your life?',
                subtitle:
                    'These inputs tune pricing, language, and delivery filters in the marketplace.',
              ),
              const SizedBox(height: 18),
              _MetricField(
                label: 'Monthly budget',
                suffix: 'EGP',
                controller: _budgetController,
              ),
              const SizedBox(height: 16),
              const _SectionLabel(text: 'Coaching mode'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ChoicePill(
                    label: 'Online',
                    selected: _selectedCoachingPreference == 'online',
                    onTap: () =>
                        setState(() => _selectedCoachingPreference = 'online'),
                  ),
                  _ChoicePill(
                    label: 'In person',
                    selected: _selectedCoachingPreference == 'in_person',
                    onTap: () => setState(
                      () => _selectedCoachingPreference = 'in_person',
                    ),
                  ),
                  _ChoicePill(
                    label: 'Hybrid',
                    selected: _selectedCoachingPreference == 'hybrid',
                    onTap: () =>
                        setState(() => _selectedCoachingPreference = 'hybrid'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SectionLabel(text: 'Training place'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ChoicePill(
                    label: 'Home',
                    selected: _selectedTrainingPlace == 'home',
                    onTap: () =>
                        setState(() => _selectedTrainingPlace = 'home'),
                  ),
                  _ChoicePill(
                    label: 'Gym',
                    selected: _selectedTrainingPlace == 'gym',
                    onTap: () => setState(() => _selectedTrainingPlace = 'gym'),
                  ),
                  _ChoicePill(
                    label: 'Both',
                    selected: _selectedTrainingPlace == 'both',
                    onTap: () =>
                        setState(() => _selectedTrainingPlace = 'both'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SectionLabel(text: 'Preferred language'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceTile(
                      label: 'Arabic',
                      selected: _selectedLanguage == 'arabic',
                      onTap: () => setState(() => _selectedLanguage = 'arabic'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChoiceTile(
                      label: 'English',
                      selected: _selectedLanguage == 'english',
                      onTap: () =>
                          setState(() => _selectedLanguage = 'english'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _SectionLabel(text: 'Preferred coach gender'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ChoicePill(
                    label: 'Any',
                    selected: _selectedCoachGender == 'any',
                    onTap: () => setState(() => _selectedCoachGender = 'any'),
                  ),
                  _ChoicePill(
                    label: 'Male',
                    selected: _selectedCoachGender == 'male',
                    onTap: () => setState(() => _selectedCoachGender = 'male'),
                  ),
                  _ChoicePill(
                    label: 'Female',
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
              const _StepHeader(
                eyebrow: 'Training rhythm',
                title: 'How ready are you to commit each week?',
                subtitle:
                    'We use this to set realistic accountability and starter plan expectations.',
              ),
              const SizedBox(height: 18),
              const _SectionLabel(text: 'Experience level'),
              const SizedBox(height: 10),
              ...List.generate(_experienceLevels.length, (index) {
                final label = _experienceLevels[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ChoiceTile(
                    label: label,
                    helper: _experienceHelper(label),
                    selected: _selectedExperience == index,
                    onTap: () => setState(() => _selectedExperience = index),
                  ),
                );
              }),
              const SizedBox(height: 10),
              const _SectionLabel(text: 'Weekly frequency'),
              const SizedBox(height: 10),
              ...List.generate(_frequencies.length, (index) {
                final label = _frequencies[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ChoiceTile(
                    label: label,
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
        return 'You need simple instructions and closer follow-up.';
      case 'Intermediate':
        return 'You train already, but want better structure and feedback.';
      case 'Advanced':
        return 'You can handle more load, volume, and tighter planning.';
      case 'Athlete':
        return 'Performance-first training with serious consistency.';
      default:
        return '';
    }
  }

  String _frequencyHelper(String label) {
    switch (label) {
      case '1-2 days/week':
        return 'Low-friction routine focused on momentum.';
      case '3-4 days/week':
        return 'Balanced pace for visible progress and recovery.';
      case '5-6 days/week':
        return 'High-consistency track with structured recovery.';
      case 'Every day':
        return 'Best for very committed routines with coach oversight.';
      default:
        return '';
    }
  }

  String _footerNote() {
    switch (_currentStep) {
      case 0:
        return 'Lose Weight is the default because this version is optimized for first-time members in Egypt.';
      case 1:
        return 'Your baseline drives weight, waist, and progress check-ins later.';
      case 2:
        return 'These preferences directly shape the coach marketplace filters and pricing shown first.';
      default:
        return 'You can update these choices later from your profile and settings.';
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
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: AppColors.orangeLight,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.05,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
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
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F141D),
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            border: Border.all(
              color: selected ? option.accent : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: option.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(option.icon, color: option.accent),
              ),
              const Spacer(),
              Text(
                option.title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                option.description,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary,
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
  });

  final String label;
  final TextEditingController controller;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: suffix == null
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.inter(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: AppColors.fieldFill,
        labelStyle: GoogleFonts.inter(color: AppColors.textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.orange),
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
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.orange.withValues(alpha: 0.12)
                : AppColors.fieldFill,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(
              color: selected ? AppColors.orange : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (helper != null && helper!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  helper!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
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
      selectedColor: AppColors.orange.withValues(alpha: 0.18),
      backgroundColor: AppColors.fieldFill,
      side: BorderSide(color: selected ? AppColors.orange : AppColors.border),
      labelStyle: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: selected ? AppColors.orangeLight : AppColors.textSecondary,
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
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({
    required this.step,
    required this.totalSteps,
    required this.progress,
  });

  final int step;
  final int totalSteps;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'STEP $step OF $totalSteps',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.orange,
                ),
              ),
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
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.white.withValues(alpha: 0.06),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Icon(icon, color: AppColors.textPrimary),
      ),
    );
  }
}
