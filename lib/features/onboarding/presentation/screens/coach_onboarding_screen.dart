import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes.dart';
import '../../../user/presentation/controllers/onboarding_controller.dart';
import '../widgets/onboarding_dna.dart';

class CoachOnboardingScreen extends ConsumerStatefulWidget {
  const CoachOnboardingScreen({super.key});

  @override
  ConsumerState<CoachOnboardingScreen> createState() =>
      _CoachOnboardingScreenState();
}

class _CoachOnboardingScreenState extends ConsumerState<CoachOnboardingScreen> {
  int _currentStep = 0;
  final int _totalSteps = 3;

  int _selectedSpecialty = 0;
  final List<_CoachSpecialty> _specialties = const <_CoachSpecialty>[
    _CoachSpecialty(
      icon: Icons.fitness_center,
      title: 'Strength',
      description: 'Progressive overload and performance strength blocks.',
    ),
    _CoachSpecialty(
      icon: Icons.self_improvement,
      title: 'Yoga',
      description: 'Mobility, breathwork, control, and recovery-led sessions.',
    ),
    _CoachSpecialty(
      icon: Icons.directions_run,
      title: 'Cardio',
      description: 'Conditioning, endurance, pacing, and energy systems.',
    ),
    _CoachSpecialty(
      icon: Icons.sports_martial_arts,
      title: 'CrossFit',
      description: 'Mixed-modality coaching for power, grit, and capacity.',
    ),
    _CoachSpecialty(
      icon: Icons.pool,
      title: 'Swimming',
      description: 'Technique refinement and aquatic performance planning.',
    ),
    _CoachSpecialty(
      icon: Icons.restaurant,
      title: 'Nutrition',
      description: 'Food strategy, habit coaching, and client accountability.',
    ),
  ];

  final _yearsController = TextEditingController(text: '5');
  final _bioController = TextEditingController();

  int _selectedPricing = 0;
  final List<String> _pricingModels = const <String>[
    'Per Session',
    'Monthly Subscription',
    'Package Deal',
    'Free (Build Audience)',
  ];

  @override
  void dispose() {
    _yearsController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      return;
    }

    final years = int.tryParse(_yearsController.text.trim()) ?? 0;
    final bio = _bioController.text.trim();
    final selectedSpecialty = _specialties[_selectedSpecialty].title;
    final success = await ref
        .read(onboardingControllerProvider.notifier)
        .completeCoachOnboarding(
          bio: bio,
          specialties: <String>[selectedSpecialty],
          yearsExperience: years,
          hourlyRate: 50,
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
      AppRoutes.coachDashboard,
      (route) => false,
    );
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
    final onboardingState = ref.watch(onboardingControllerProvider);

    return OnboardingScreenFrame(
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      onBack: _prevStep,
      primaryLabel: _currentStep < _totalSteps - 1
          ? 'CONTINUE'
          : 'START COACHING',
      onPrimaryAction: _nextStep,
      footerText: _currentStep == 0
          ? 'You can expand your specialties, pricing, and profile depth later from the coach dashboard.'
          : 'These details shape how members discover and understand your coaching offer.',
      isLoading: onboardingState.isLoading,
      content: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _buildSpecialtyStep();
      case 1:
        return _buildBioStep();
      case 2:
        return _buildPricingStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSpecialtyStep() {
    return SingleChildScrollView(
      key: const ValueKey('coach-specialty-step'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            title: 'What do you',
            accent: 'coach best?',
            subtitle:
                'Choose the lane that best represents your expertise so GymUnity can place you in the right category.',
          ),
          const SizedBox(height: 28),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _specialties.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.84,
            ),
            itemBuilder: (context, index) {
              final specialty = _specialties[index];
              return OnboardingOptionCard(
                icon: specialty.icon,
                title: specialty.title,
                description: specialty.description,
                selected: _selectedSpecialty == index,
                onTap: () => setState(() => _selectedSpecialty = index),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBioStep() {
    return SingleChildScrollView(
      key: const ValueKey('coach-bio-step'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            title: 'Position your',
            accent: 'coaching brand.',
            subtitle:
                'Members should understand your background and the value you bring in a few seconds.',
          ),
          const SizedBox(height: 28),
          OnboardingTextField(
            label: 'Years of Experience',
            hint: '5',
            suffix: 'years',
            controller: _yearsController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),
          OnboardingTextField(
            label: 'Coach Bio',
            hint:
                'Tell members about your experience, style, and results you help clients achieve.',
            controller: _bioController,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingStep() {
    return SingleChildScrollView(
      key: const ValueKey('coach-pricing-step'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            title: 'How will clients',
            accent: 'pay you?',
            subtitle:
                'Choose the commercial model that fits your offer so your dashboard starts with the right framing.',
          ),
          const SizedBox(height: 28),
          ...List.generate(_pricingModels.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: OnboardingSelectablePanel(
                label: _pricingModels[index],
                helper: _pricingHelper(index),
                selected: _selectedPricing == index,
                onTap: () => setState(() => _selectedPricing = index),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _pricingHelper(int index) {
    switch (index) {
      case 0:
        return 'Ideal for 1:1 coaching, consultations, and flexible scheduling.';
      case 1:
        return 'Great for recurring support, retention, and structured monthly programs.';
      case 2:
        return 'Bundle sessions or outcomes into a high-clarity transformation offer.';
      case 3:
        return 'Useful when building trust, testimonials, and early audience traction.';
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

class _CoachSpecialty {
  const _CoachSpecialty({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
