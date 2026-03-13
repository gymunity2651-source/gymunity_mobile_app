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
  int _currentStep = 0;
  final int _totalSteps = 4;

  int _selectedGoal = 0;
  final List<_GoalOption> _goals = const <_GoalOption>[
    _GoalOption(
      icon: Icons.fitness_center,
      title: 'Build Muscle',
      description: 'Hypertrophy and strength focus.',
    ),
    _GoalOption(
      icon: Icons.monitor_weight_outlined,
      title: 'Lose Weight',
      description: 'Fat loss and lean physique.',
    ),
    _GoalOption(
      icon: Icons.bolt,
      title: 'Endurance',
      description: 'High-intensity aerobic capacity.',
    ),
    _GoalOption(
      icon: Icons.self_improvement,
      title: 'Mobility',
      description: 'Flexibility and joint health.',
    ),
    _GoalOption(
      icon: Icons.accessibility_new,
      title: 'Functional',
      description: 'Real-world movement strength.',
    ),
    _GoalOption(
      icon: Icons.outlined_flag,
      title: 'Sports',
      description: 'Agility for specific sports.',
    ),
  ];

  final _heightController = TextEditingController(text: '175');
  final _weightController = TextEditingController(text: '75');
  final _ageController = TextEditingController(text: '25');
  String _selectedGender = 'Male';

  int _selectedExperience = -1;
  final List<String> _experiences = const <String>[
    'Beginner',
    'Intermediate',
    'Advanced',
    'Athlete',
  ];

  int _selectedFrequency = -1;
  final List<String> _frequencies = const <String>[
    '1-2 days/week',
    '3-4 days/week',
    '5-6 days/week',
    'Every day',
  ];

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      return;
    }

    final age = int.tryParse(_ageController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
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
    if (_selectedExperience < 0 || _selectedFrequency < 0) {
      _showMessage('Complete all onboarding steps before continuing.');
      return;
    }

    final success = await ref
        .read(onboardingControllerProvider.notifier)
        .completeMemberOnboarding(
          goal: _goalValue(_goals[_selectedGoal].title),
          age: age,
          gender: _genderValue(_selectedGender),
          heightCm: height,
          currentWeightKg: weight,
          trainingFrequency: _frequencyValue(_frequencies[_selectedFrequency]),
          experienceLevel: _experienceValue(_experiences[_selectedExperience]),
        );
    if (!mounted) return;
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

  String _goalValue(String raw) {
    return raw.trim().toLowerCase().replaceAll(' ', '_');
  }

  String _genderValue(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'other') {
      return 'prefer_not_to_say';
    }
    return value;
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

  String _experienceValue(String raw) {
    return raw.trim().toLowerCase();
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / _totalSteps;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _OnboardingBackdrop(),
          SafeArea(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BackChip(onTap: _prevStep),
                      const Spacer(),
                      _StepProgress(
                        step: _currentStep + 1,
                        totalSteps: _totalSteps,
                        progress: progress,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _buildStepContent(),
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
                      _PrimaryActionButton(
                        label: _currentStep < _totalSteps - 1
                            ? 'CONTINUE'
                            : 'GET STARTED',
                        onTap: _nextStep,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _currentStep == 0
                            ? 'You can change your goal anytime in settings.'
                            : 'Your plan will adapt as you progress through the app.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildGoalStep();
      case 1:
        return _buildBodyInfoStep();
      case 2:
        return _buildExperienceStep();
      case 3:
        return _buildFrequencyStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGoalStep() {
    return SingleChildScrollView(
      key: const ValueKey('member-goals-step'),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'What is your\n',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    letterSpacing: -0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: 'primary goal?',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    letterSpacing: -0.8,
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Personalize your experience. We\'ll tailor your workouts and nutrition plans based on your choice.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.65,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _goals.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final goal = _goals[index];
              return _GoalCard(
                option: goal,
                selected: _selectedGoal == index,
                onTap: () => setState(() => _selectedGoal = index),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBodyInfoStep() {
    return SingleChildScrollView(
      key: const ValueKey('member-body-step'),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeading(
            title: 'Build your',
            accent: 'baseline.',
            subtitle:
                'A few details help us shape smarter training suggestions.',
          ),
          const SizedBox(height: 28),
          Text(
            'Gender',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: ['Male', 'Female'].map((gender) {
              final selected = _selectedGender == gender;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: gender == 'Male' ? AppSizes.md : 0,
                  ),
                  child: _SelectablePanel(
                    label: gender,
                    selected: selected,
                    compact: true,
                    onTap: () => setState(() => _selectedGender = gender),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MetricField(
                  label: 'Height',
                  suffix: 'cm',
                  controller: _heightController,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _MetricField(
                  label: 'Weight',
                  suffix: 'kg',
                  controller: _weightController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _MetricField(
            label: 'Age',
            suffix: 'years',
            controller: _ageController,
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceStep() {
    return SingleChildScrollView(
      key: const ValueKey('member-experience-step'),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeading(
            title: 'What is your',
            accent: 'fitness level?',
            subtitle:
                'We will shape the intensity and ramp-up to match your experience.',
          ),
          const SizedBox(height: 28),
          ...List.generate(_experiences.length, (index) {
            final selected = _selectedExperience == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SelectablePanel(
                label: _experiences[index],
                selected: selected,
                helper: _experienceHelper(index),
                onTap: () => setState(() => _selectedExperience = index),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFrequencyStep() {
    return SingleChildScrollView(
      key: const ValueKey('member-frequency-step'),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeading(
            title: 'How often will',
            accent: 'you train?',
            subtitle:
                'Your weekly rhythm helps us calibrate recovery, volume, and progression.',
          ),
          const SizedBox(height: 28),
          ...List.generate(_frequencies.length, (index) {
            final selected = _selectedFrequency == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SelectablePanel(
                label: _frequencies[index],
                selected: selected,
                helper: _frequencyHelper(index),
                onTap: () => setState(() => _selectedFrequency = index),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _experienceHelper(int index) {
    switch (index) {
      case 0:
        return 'New to structured training and building consistency.';
      case 1:
        return 'Comfortable with gym basics and steady progression.';
      case 2:
        return 'Can handle higher volume, intensity, and focused blocks.';
      case 3:
        return 'Competitive mindset with performance-led programming.';
      default:
        return '';
    }
  }

  String _frequencyHelper(int index) {
    switch (index) {
      case 0:
        return 'Light weekly commitment with room to build momentum.';
      case 1:
        return 'Balanced routine for visible progress and recovery.';
      case 2:
        return 'High-consistency plan with progressive overload.';
      case 3:
        return 'Daily schedule with recovery management built in.';
      default:
        return '';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GoalOption {
  const _GoalOption({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _BackChip extends StatelessWidget {
  const _BackChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Icon(Icons.arrow_back, color: AppColors.white, size: 26),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({
    required this.step,
    required this.totalSteps,
    required this.progress,
  });

  final int step;
  final int totalSteps;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'STEP $step OF $totalSteps',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 124,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.white.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({
    required this.title,
    required this.accent,
    required this.subtitle,
  });

  final String title;
  final String accent;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$title\n',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.08,
                  letterSpacing: -0.7,
                  color: AppColors.textPrimary,
                ),
              ),
              TextSpan(
                text: accent,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.08,
                  letterSpacing: -0.7,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.65,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1016),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          border: Border.all(
            color: selected ? AppColors.limeGreen : AppColors.border,
            width: selected ? 2.2 : 1.1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.limeGreen.withValues(alpha: 0.22),
                    blurRadius: 26,
                    spreadRadius: 2,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F3210),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    option.icon,
                    color: AppColors.limeGreen,
                    size: 30,
                  ),
                ),
                const Spacer(),
                Text(
                  option.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  option.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.55,
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.limeGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppColors.black,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectablePanel extends StatelessWidget {
  const _SelectablePanel({
    required this.label,
    required this.selected,
    required this.onTap,
    this.helper,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? helper;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: compact ? 16 : 18,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceRaised : const Color(0xFF0B1016),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: compact ? 15 : 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if ((helper?.isNotEmpty ?? false) && !compact) ...[
                    const SizedBox(height: 8),
                    Text(
                      helper!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? AppColors.orange : AppColors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.orange : AppColors.borderLight,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: AppColors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricField extends StatelessWidget {
  const _MetricField({
    required this.label,
    required this.suffix,
    required this.controller,
  });

  final String label;
  final String suffix;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.fieldFill,
            suffixText: suffix,
            suffixStyle: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 74,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFF97A18), Color(0xFFF13A1C)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.34),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.transparent,
            shadowColor: AppColors.transparent,
            surfaceTintColor: AppColors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF040608),
                  Color(0xFF06090D),
                  Color(0xFF040608),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -90,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.orange.withValues(alpha: 0.12),
                  AppColors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -160,
          right: -60,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.limeGreen.withValues(alpha: 0.09),
                  AppColors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
