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
  final int _totalSteps = 4;

  int _selectedSpecialty = 0;
  final List<_CoachSpecialty> _specialties = const <_CoachSpecialty>[
    _CoachSpecialty(
      icon: Icons.fitness_center,
      title: 'Strength',
      description:
          'Progressive overload, technique, and structured gym blocks.',
    ),
    _CoachSpecialty(
      icon: Icons.self_improvement,
      title: 'Yoga',
      description: 'Mobility, breathwork, recovery, and mind-body sessions.',
    ),
    _CoachSpecialty(
      icon: Icons.directions_run,
      title: 'Cardio',
      description: 'Conditioning, endurance, and sport-specific stamina work.',
    ),
    _CoachSpecialty(
      icon: Icons.restaurant,
      title: 'Nutrition',
      description: 'Habit coaching, accountability, and nutrition structure.',
    ),
  ];

  final _yearsController = TextEditingController(text: '5');
  final _hourlyRateController = TextEditingController(text: '50');
  final _bioController = TextEditingController();
  final _serviceSummaryController = TextEditingController();
  final _packageTitleController = TextEditingController(
    text: 'Starter Coaching',
  );
  final _packageDescriptionController = TextEditingController();
  final _packagePriceController = TextEditingController(text: '199');
  final _availabilityStartController = TextEditingController(text: '09:00');
  final _availabilityEndController = TextEditingController(text: '17:00');

  int _selectedDeliveryMode = 0;
  int _selectedBillingCycle = 1;
  int _selectedWeekday = 1;

  final List<String> _deliveryModes = const <String>[
    'Remote',
    'In Person',
    'Hybrid',
  ];
  final List<String> _billingCycles = const <String>[
    'weekly',
    'monthly',
    'quarterly',
    'one_time',
  ];
  final List<String> _weekdayLabels = const <String>[
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void dispose() {
    _yearsController.dispose();
    _hourlyRateController.dispose();
    _bioController.dispose();
    _serviceSummaryController.dispose();
    _packageTitleController.dispose();
    _packageDescriptionController.dispose();
    _packagePriceController.dispose();
    _availabilityStartController.dispose();
    _availabilityEndController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      return;
    }

    final years = int.tryParse(_yearsController.text.trim());
    final hourlyRate = double.tryParse(_hourlyRateController.text.trim());
    final packagePrice = double.tryParse(_packagePriceController.text.trim());
    final bio = _bioController.text.trim();
    final serviceSummary = _serviceSummaryController.text.trim();
    final packageTitle = _packageTitleController.text.trim();
    final packageDescription = _packageDescriptionController.text.trim();
    final availabilityStart = _availabilityStartController.text.trim();
    final availabilityEnd = _availabilityEndController.text.trim();

    if (years == null || years < 0) {
      _showMessage('Enter a valid years-of-experience value.');
      return;
    }
    if (hourlyRate == null || hourlyRate <= 0) {
      _showMessage('Enter a valid hourly rate.');
      return;
    }
    if (bio.isEmpty || serviceSummary.isEmpty) {
      _showMessage('Complete your coach bio and service summary.');
      return;
    }
    if (packageTitle.isEmpty || packageDescription.isEmpty) {
      _showMessage('Add a real starter package for members to request.');
      return;
    }
    if (packagePrice == null || packagePrice <= 0) {
      _showMessage('Enter a valid package price.');
      return;
    }
    if (!_isTimeValue(availabilityStart) || !_isTimeValue(availabilityEnd)) {
      _showMessage('Use HH:MM format for availability.');
      return;
    }

    final success = await ref
        .read(onboardingControllerProvider.notifier)
        .completeCoachOnboarding(
          bio: bio,
          specialties: <String>[_specialties[_selectedSpecialty].title],
          yearsExperience: years,
          hourlyRate: hourlyRate,
          deliveryMode: _deliveryModes[_selectedDeliveryMode]
              .toLowerCase()
              .replaceAll(' ', '_'),
          serviceSummary: serviceSummary,
          packageTitle: packageTitle,
          packageDescription: packageDescription,
          billingCycle: _billingCycles[_selectedBillingCycle],
          packagePrice: packagePrice,
          availabilityWeekday: _selectedWeekday,
          availabilityStartTime: availabilityStart,
          availabilityEndTime: availabilityEnd,
          availabilityTimezone: 'UTC',
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
          ? 'Set the coaching lane members should discover first.'
          : 'Everything here is saved and becomes part of your real public coach profile.',
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
        return _buildProfileStep();
      case 2:
        return _buildServiceStep();
      case 3:
        return _buildAvailabilityStep();
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
                'Choose the main category that should anchor your public discovery card.',
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
              childAspectRatio: 0.9,
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

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      key: const ValueKey('coach-profile-step'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            title: 'Describe your',
            accent: 'coaching offer.',
            subtitle:
                'These fields drive your real coach profile, pricing, and member expectations.',
          ),
          const SizedBox(height: 24),
          OnboardingTextField(
            label: 'Years of Experience',
            hint: '5',
            suffix: 'years',
            controller: _yearsController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),
          OnboardingTextField(
            label: 'Hourly Rate',
            hint: '50',
            suffix: 'USD',
            controller: _hourlyRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 18),
          OnboardingTextField(
            label: 'Coach Bio',
            hint:
                'Explain your background, style, and the results you help members achieve.',
            controller: _bioController,
            maxLines: 4,
          ),
          const SizedBox(height: 18),
          OnboardingTextField(
            label: 'Service Summary',
            hint: 'Summarize what members get when they train with you.',
            controller: _serviceSummaryController,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceStep() {
    return SingleChildScrollView(
      key: const ValueKey('coach-service-step'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            title: 'Configure your',
            accent: 'starter package.',
            subtitle:
                'Members need one real package and one real service mode before your account goes live.',
          ),
          const SizedBox(height: 24),
          ...List.generate(_deliveryModes.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingSelectablePanel(
                label: _deliveryModes[index],
                helper: index == 0
                    ? 'Deliver coaching remotely through calls, async check-ins, and plan updates.'
                    : index == 1
                    ? 'Deliver sessions primarily in person.'
                    : 'Offer both remote and in-person delivery.',
                selected: _selectedDeliveryMode == index,
                onTap: () => setState(() => _selectedDeliveryMode = index),
              ),
            );
          }),
          const SizedBox(height: 18),
          OnboardingTextField(
            label: 'Starter Package Title',
            hint: 'Starter Coaching',
            controller: _packageTitleController,
          ),
          const SizedBox(height: 18),
          OnboardingTextField(
            label: 'Package Description',
            hint:
                'Describe the support level, check-ins, and plan updates included.',
            controller: _packageDescriptionController,
            maxLines: 3,
          ),
          const SizedBox(height: 18),
          OnboardingTextField(
            label: 'Package Price',
            hint: '199',
            suffix: 'USD',
            controller: _packagePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_billingCycles.length, (index) {
              return ChoiceChip(
                label: Text(_billingCycles[index]),
                selected: _selectedBillingCycle == index,
                onSelected: (_) =>
                    setState(() => _selectedBillingCycle = index),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityStep() {
    return SingleChildScrollView(
      key: const ValueKey('coach-availability-step'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            title: 'When are you',
            accent: 'available?',
            subtitle:
                'Add one real recurring slot. You can expand your schedule later from the coach profile.',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_weekdayLabels.length, (index) {
              return ChoiceChip(
                label: Text(_weekdayLabels[index]),
                selected: _selectedWeekday == index,
                onSelected: (_) => setState(() => _selectedWeekday = index),
              );
            }),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OnboardingTextField(
                  label: 'Start Time',
                  hint: '09:00',
                  controller: _availabilityStartController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OnboardingTextField(
                  label: 'End Time',
                  hint: '17:00',
                  controller: _availabilityEndController,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isTimeValue(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return false;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
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
