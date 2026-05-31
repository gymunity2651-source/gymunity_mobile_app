import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../coach/domain/entities/subscription_entity.dart';
import '../providers/member_providers.dart';

class MemberCheckinsScreen extends ConsumerWidget {
  const MemberCheckinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(memberSubscriptionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Weekly Check-ins'),
        backgroundColor: AppColors.background,
      ),
      body: subscriptionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (subscriptions) {
          final activeSubscriptions = subscriptions
              .where((subscription) => subscription.isActive)
              .toList(growable: false);

          if (activeSubscriptions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                child: Text(
                  'Activate a coaching subscription first, then your weekly check-ins will appear here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: activeSubscriptions
                .map(
                  (subscription) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _CheckinCard(subscription: subscription),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _CheckinCard extends ConsumerWidget {
  const _CheckinCard({required this.subscription});

  final SubscriptionEntity subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinsAsync = ref.watch(
      memberWeeklyCheckinsProvider(subscription.id),
    );
    final latest = checkinsAsync.valueOrNull?.isNotEmpty == true
        ? checkinsAsync.valueOrNull!.first
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subscription.coachName ?? 'Coach',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subscription.displayTitle,
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (latest != null)
            Text(
              'Latest: ${latest.weekStart.toLocal().toString().split(' ').first} • ${latest.adherenceScore}% adherence',
              style: GoogleFonts.inter(color: AppColors.textMuted),
            )
          else
            Text(
              'No check-in submitted yet.',
              style: GoogleFonts.inter(color: AppColors.textMuted),
            ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => _openCheckinDialog(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Submit this week'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCheckinDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _WeeklyCheckinDialog(subscription: subscription),
    );
  }
}

class _WeeklyCheckinDialog extends ConsumerStatefulWidget {
  const _WeeklyCheckinDialog({required this.subscription});

  final SubscriptionEntity subscription;

  @override
  ConsumerState<_WeeklyCheckinDialog> createState() =>
      _WeeklyCheckinDialogState();
}

class _WeeklyCheckinDialogState extends ConsumerState<_WeeklyCheckinDialog> {
  final _weightController = TextEditingController();
  final _waistController = TextEditingController();
  final _adherenceController = TextEditingController();
  final _energyController = TextEditingController();
  final _sleepController = TextEditingController();
  final _workoutsCompletedController = TextEditingController();
  final _missedWorkoutsController = TextEditingController();
  final _missedReasonController = TextEditingController();
  final _sorenessController = TextEditingController();
  final _fatigueController = TextEditingController();
  final _nutritionController = TextEditingController();
  final _habitController = TextEditingController();
  final _painController = TextEditingController();
  final _obstacleController = TextEditingController();
  final _supportController = TextEditingController();
  final _winsController = TextEditingController();
  final _blockersController = TextEditingController();
  final _questionsController = TextEditingController();

  bool _isSubmitting = false;
  int _stepIndex = 0;

  @override
  void dispose() {
    _weightController.dispose();
    _waistController.dispose();
    _adherenceController.dispose();
    _energyController.dispose();
    _sleepController.dispose();
    _workoutsCompletedController.dispose();
    _missedWorkoutsController.dispose();
    _missedReasonController.dispose();
    _sorenessController.dispose();
    _fatigueController.dispose();
    _nutritionController.dispose();
    _habitController.dispose();
    _painController.dispose();
    _obstacleController.dispose();
    _supportController.dispose();
    _winsController.dispose();
    _blockersController.dispose();
    _questionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_stepIndex == 0 ? 'Quick Check-in' : 'Advanced Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _stepIndex == 0 ? 'Step 1 of 2' : 'Step 2 of 2',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _stepIndex == 0
                  ? 'Submit the essentials first. You can add details on the next step.'
                  : 'Optional details help your coach adjust the plan.',
            ),
            const SizedBox(height: 16),
            if (_stepIndex == 0) _buildQuickStep() else _buildAdvancedStep(),
          ],
        ),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildQuickStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _adherenceController,
          decoration: const InputDecoration(labelText: 'Adherence %'),
          keyboardType: TextInputType.number,
        ),
        TextField(
          controller: _energyController,
          decoration: const InputDecoration(labelText: 'Energy 1-10'),
          keyboardType: TextInputType.number,
        ),
        TextField(
          controller: _sleepController,
          decoration: const InputDecoration(labelText: 'Sleep 1-10'),
          keyboardType: TextInputType.number,
        ),
        TextField(
          controller: _painController,
          decoration: const InputDecoration(
            labelText: 'Pain or injury warning',
          ),
        ),
        TextField(
          controller: _obstacleController,
          decoration: const InputDecoration(
            labelText: 'Biggest obstacle this week',
          ),
        ),
        TextField(
          controller: _supportController,
          decoration: const InputDecoration(
            labelText: 'Support needed from coach',
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _weightController,
          decoration: const InputDecoration(labelText: 'Weight (kg)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        TextField(
          controller: _waistController,
          decoration: const InputDecoration(labelText: 'Waist (cm)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nutritionController,
                decoration: const InputDecoration(labelText: 'Nutrition %'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _habitController,
                decoration: const InputDecoration(labelText: 'Habits %'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _workoutsCompletedController,
                decoration: const InputDecoration(
                  labelText: 'Workouts completed',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _missedWorkoutsController,
                decoration: const InputDecoration(labelText: 'Missed workouts'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        TextField(
          controller: _missedReasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for missed workouts',
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _sorenessController,
                decoration: const InputDecoration(labelText: 'Soreness 1-10'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _fatigueController,
                decoration: const InputDecoration(labelText: 'Fatigue 1-10'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        TextField(
          controller: _winsController,
          decoration: const InputDecoration(labelText: 'Wins'),
        ),
        TextField(
          controller: _blockersController,
          decoration: const InputDecoration(labelText: 'Blockers'),
        ),
        TextField(
          controller: _questionsController,
          decoration: const InputDecoration(labelText: 'Questions'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Progress photos can be added from the progress area when available.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions() {
    if (_stepIndex == 0) {
      return [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => _submit(includeAdvanced: false),
          child: Text(
            _isSubmitting ? 'Submitting...' : 'Submit Quick Check-in',
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _showAdvancedStep,
          child: const Text('Next: Advanced Details'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: _isSubmitting ? null : () => setState(() => _stepIndex = 0),
        child: const Text('Back'),
      ),
      ElevatedButton(
        onPressed: _isSubmitting ? null : () => _submit(includeAdvanced: true),
        child: _isSubmitting
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Submitting...'),
                ],
              )
            : const Text('Submit Check-in'),
      ),
    ];
  }

  void _showAdvancedStep() {
    final validationMessage = _validateQuickStep();
    if (validationMessage != null) {
      _showSnackBar(validationMessage);
      return;
    }
    setState(() => _stepIndex = 1);
  }

  Future<void> _submit({required bool includeAdvanced}) async {
    if (_isSubmitting) {
      return;
    }

    final validationMessage = includeAdvanced
        ? _validateAll()
        : _validateQuickStep();
    if (validationMessage != null) {
      _showSnackBar(validationMessage);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(memberRepositoryProvider)
          .submitWeeklyCheckin(
            subscriptionId: widget.subscription.id,
            weekStart: DateTime.now(),
            weightKg: includeAdvanced
                ? _parseOptionalDouble(_weightController)
                : null,
            waistCm: includeAdvanced
                ? _parseOptionalDouble(_waistController)
                : null,
            adherenceScore: _parseRequiredInt(_adherenceController),
            energyScore: _parseRequiredInt(_energyController),
            sleepScore: _parseRequiredInt(_sleepController),
            workoutsCompleted: includeAdvanced
                ? _parseOptionalInt(_workoutsCompletedController)
                : null,
            missedWorkouts: includeAdvanced
                ? _parseOptionalInt(_missedWorkoutsController)
                : null,
            missedWorkoutsReason: includeAdvanced
                ? _optionalText(_missedReasonController)
                : null,
            sorenessScore: includeAdvanced
                ? _parseOptionalInt(_sorenessController)
                : null,
            fatigueScore: includeAdvanced
                ? _parseOptionalInt(_fatigueController)
                : null,
            painWarning: _optionalText(_painController),
            nutritionAdherenceScore: includeAdvanced
                ? _parseOptionalInt(_nutritionController)
                : null,
            habitAdherenceScore: includeAdvanced
                ? _parseOptionalInt(_habitController)
                : null,
            biggestObstacle: _optionalText(_obstacleController),
            supportNeeded: _optionalText(_supportController),
            wins: includeAdvanced ? _optionalText(_winsController) : null,
            blockers: includeAdvanced
                ? _optionalText(_blockersController)
                : null,
            questions: includeAdvanced
                ? _optionalText(_questionsController)
                : null,
          );
      ref.invalidate(memberWeeklyCheckinsProvider(widget.subscription.id));
      ref.invalidate(memberSubscriptionsProvider);
      ref.invalidate(memberHomeSummaryProvider);
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Weekly check-in submitted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      _showSnackBar('Weekly check-in could not be submitted: $error');
    }
  }

  String? _validateQuickStep() {
    return _validatePercent(
          'Adherence',
          _adherenceController,
          required: true,
        ) ??
        _validateIntRange(
          _energyController,
          min: 1,
          max: 10,
          message: 'Energy must be between 1 and 10.',
          required: true,
        ) ??
        _validateIntRange(
          _sleepController,
          min: 1,
          max: 10,
          message: 'Sleep must be between 1 and 10.',
          required: true,
        );
  }

  String? _validateAdvancedFields() {
    return _validateDoubleRange(
          _weightController,
          min: 30,
          max: 300,
          message: 'Enter a realistic weight in kilograms.',
        ) ??
        _validateDoubleRange(
          _waistController,
          min: 40,
          max: 250,
          message: 'Enter a realistic waist measurement in centimeters.',
        ) ??
        _validateIntRange(
          _workoutsCompletedController,
          min: 0,
          max: 30,
          message: 'Workouts completed must be 0 or more.',
        ) ??
        _validateIntRange(
          _missedWorkoutsController,
          min: 0,
          max: 30,
          message: 'Missed workouts must be 0 or more.',
        ) ??
        _validateIntRange(
          _sorenessController,
          min: 1,
          max: 10,
          message: 'Soreness must be between 1 and 10.',
        ) ??
        _validateIntRange(
          _fatigueController,
          min: 1,
          max: 10,
          message: 'Fatigue must be between 1 and 10.',
        ) ??
        _validatePercent('Nutrition adherence', _nutritionController) ??
        _validatePercent('Habit adherence', _habitController);
  }

  String? _validateAll() {
    return _validateQuickStep() ?? _validateAdvancedFields();
  }

  String? _validatePercent(
    String label,
    TextEditingController controller, {
    bool required = false,
  }) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return required ? '$label must be between 0 and 100.' : null;
    }
    final value = int.tryParse(text);
    if (value == null || value < 0 || value > 100) {
      return '$label must be between 0 and 100.';
    }
    return null;
  }

  String? _validateIntRange(
    TextEditingController controller, {
    required int min,
    required int max,
    required String message,
    bool required = false,
  }) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return required ? message : null;
    }
    final value = int.tryParse(text);
    if (value == null || value < min || value > max) {
      return message;
    }
    return null;
  }

  String? _validateDoubleRange(
    TextEditingController controller, {
    required double min,
    required double max,
    required String message,
  }) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return null;
    }
    final value = double.tryParse(text);
    if (value == null || value < min || value > max) {
      return message;
    }
    return null;
  }

  int _parseRequiredInt(TextEditingController controller) {
    return int.parse(controller.text.trim());
  }

  int? _parseOptionalInt(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : int.parse(text);
  }

  double? _parseOptionalDouble(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : double.parse(text);
  }

  String? _optionalText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
