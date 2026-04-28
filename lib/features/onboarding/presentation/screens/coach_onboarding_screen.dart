import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const OnboardingVisualStyle _visualStyle =
      OnboardingVisualStyle.curatedSanctuary;
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
      if (!_validateCurrentStepBeforeAdvance()) {
        return;
      }
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
      _jumpToStepWithMessage(1, 'Enter a valid years-of-experience value.');
      return;
    }
    if (hourlyRate == null || hourlyRate <= 0) {
      _jumpToStepWithMessage(1, 'Enter a valid hourly rate.');
      return;
    }
    if (bio.isEmpty || serviceSummary.isEmpty) {
      _jumpToStepWithMessage(1, 'Complete your coach bio and service summary.');
      return;
    }
    if (packageTitle.isEmpty || packageDescription.isEmpty) {
      _jumpToStepWithMessage(
        2,
        'Add a real starter package for members to request.',
      );
      return;
    }
    if (packagePrice == null || packagePrice <= 0) {
      _jumpToStepWithMessage(2, 'Enter a valid package price.');
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

  bool _validateCurrentStepBeforeAdvance() {
    switch (_currentStep) {
      case 1:
        final years = int.tryParse(_yearsController.text.trim());
        final hourlyRate = double.tryParse(_hourlyRateController.text.trim());
        final bio = _bioController.text.trim();
        final serviceSummary = _serviceSummaryController.text.trim();

        if (years == null || years < 0) {
          _showMessage('Enter a valid years-of-experience value.');
          return false;
        }
        if (hourlyRate == null || hourlyRate <= 0) {
          _showMessage('Enter a valid hourly rate.');
          return false;
        }
        if (bio.isEmpty || serviceSummary.isEmpty) {
          _showMessage('Complete your coach bio and service summary.');
          return false;
        }
        return true;
      case 2:
        final packageTitle = _packageTitleController.text.trim();
        final packageDescription = _packageDescriptionController.text.trim();
        final packagePrice = double.tryParse(
          _packagePriceController.text.trim(),
        );

        if (packageTitle.isEmpty || packageDescription.isEmpty) {
          _showMessage('Add a real starter package for members to request.');
          return false;
        }
        if (packagePrice == null || packagePrice <= 0) {
          _showMessage('Enter a valid package price.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _jumpToStepWithMessage(int step, String message) {
    if (_currentStep != step) {
      setState(() => _currentStep = step);
    }
    _showMessage(message);
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
      visualStyle: _visualStyle,
      currentStep: _currentStep,
      totalSteps: _totalSteps,
      onBack: _prevStep,
      primaryLabel: _currentStep < _totalSteps - 1
          ? 'Continue'
          : 'Start Coaching',
      onPrimaryAction: _nextStep,
      footerText: '',
      showFooterText: false,
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
      padding: const EdgeInsets.fromLTRB(28, 8, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            visualStyle: _visualStyle,
            title: 'What do\nyou',
            accent: 'coach best?',
            subtitle:
                'Select the primary discipline that defines your practice. This helps us curate the right environment for your clients.',
          ),
          const SizedBox(height: 30),
          ...List<Widget>.generate(_specialties.length, (index) {
            final specialty = _specialties[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _specialties.length - 1 ? 0 : 18,
              ),
              child: SizedBox(
                height: 182,
                child: OnboardingOptionCard(
                  visualStyle: _visualStyle,
                  icon: specialty.icon,
                  title: specialty.title,
                  description: specialty.description,
                  selected: _selectedSpecialty == index,
                  onTap: () => setState(() => _selectedSpecialty = index),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      key: const ValueKey('coach-profile-step'),
      padding: const EdgeInsets.fromLTRB(28, 8, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            visualStyle: _visualStyle,
            title: 'Describe your',
            accent: 'coaching offer.',
            subtitle:
                'Write with the calm authority of a premium studio. These details shape how clients first experience your practice.',
          ),
          const SizedBox(height: 28),
          OnboardingTextField(
            visualStyle: _visualStyle,
            label: 'Years of Experience',
            hint: '5',
            suffix: 'years',
            controller: _yearsController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          OnboardingTextField(
            visualStyle: _visualStyle,
            label: 'Hourly Rate',
            hint: '50',
            suffix: 'EGP',
            controller: _hourlyRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          OnboardingTextField(
            visualStyle: _visualStyle,
            label: 'Coach Bio',
            hint:
                'Describe your philosophy, tone, and the type of transformation you guide.',
            controller: _bioController,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          OnboardingTextField(
            visualStyle: _visualStyle,
            label: 'Service Summary',
            hint:
                'Summarize the support, accountability, and rhythm clients can expect.',
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
      padding: const EdgeInsets.fromLTRB(28, 8, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            visualStyle: _visualStyle,
            title: 'Shape your\nstarter',
            accent: 'package.',
            subtitle:
                'Create an offer that feels refined, clear, and instantly bookable for the right kind of client.',
          ),
          const SizedBox(height: 28),
          ...List.generate(_deliveryModes.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OnboardingSelectablePanel(
                visualStyle: _visualStyle,
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
          const SizedBox(height: 16),
          OnboardingTextField(
            visualStyle: _visualStyle,
            label: 'Starter Package Title',
            hint: 'Starter Coaching',
            controller: _packageTitleController,
          ),
          const SizedBox(height: 16),
          OnboardingTextField(
            visualStyle: _visualStyle,
            label: 'Package Description',
            hint:
                'Describe the cadence, deliverables, and level of care included.',
            controller: _packageDescriptionController,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          OnboardingTextField(
            visualStyle: _visualStyle,
            label: 'Package Price',
            hint: '199',
            suffix: 'EGP',
            controller: _packagePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 18),
          Text(
            'Billing Cycle',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B6B6B),
              letterSpacing: 0.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_billingCycles.length, (index) {
              return _CoachEditorialPill(
                label: _labelForBillingCycle(_billingCycles[index]),
                selected: _selectedBillingCycle == index,
                onTap: () => setState(() => _selectedBillingCycle = index),
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
      padding: const EdgeInsets.fromLTRB(28, 8, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingStepHeading(
            visualStyle: _visualStyle,
            title: 'When are you\nmost',
            accent: 'available?',
            subtitle:
                'Add one recurring window to anchor your schedule. You can refine your calendar later from the coach profile.',
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_weekdayLabels.length, (index) {
              return _CoachEditorialPill(
                label: _weekdayLabels[index],
                selected: _selectedWeekday == index,
                onTap: () => setState(() => _selectedWeekday = index),
              );
            }),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OnboardingTextField(
                  visualStyle: _visualStyle,
                  label: 'Start Time',
                  hint: '09:00',
                  controller: _availabilityStartController,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OnboardingTextField(
                  visualStyle: _visualStyle,
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

  String _labelForBillingCycle(String value) {
    switch (value) {
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'one_time':
        return 'One Time';
      default:
        return value;
    }
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

class _CoachEditorialPill extends StatelessWidget {
  const _CoachEditorialPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF4E2D8) : const Color(0xFFF4F3F1),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0D1A1C1A),
                blurRadius: 20,
                spreadRadius: -6,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF822700)
                  : const Color(0xFF1A1C1A),
            ),
          ),
        ),
      ),
    );
  }
}
