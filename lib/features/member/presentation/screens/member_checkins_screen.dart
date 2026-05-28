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
  final _adherenceController = TextEditingController(text: '80');
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

  @override
  void dispose() {
    _weightController.dispose();
    _waistController.dispose();
    _adherenceController.dispose();
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
      title: Text('Check-in for ${widget.subscription.coachName ?? 'coach'}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextField(
              controller: _waistController,
              decoration: const InputDecoration(labelText: 'Waist (cm)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextField(
              controller: _adherenceController,
              decoration: const InputDecoration(labelText: 'Adherence %'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _workoutsCompletedController,
              decoration: const InputDecoration(
                labelText: 'Workouts completed',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _missedWorkoutsController,
              decoration: const InputDecoration(labelText: 'Missed workouts'),
              keyboardType: TextInputType.number,
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
                    decoration: const InputDecoration(
                      labelText: 'Soreness 1-10',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _fatigueController,
                    decoration: const InputDecoration(
                      labelText: 'Fatigue 1-10',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
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
              : const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final validationMessage = _validate();
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
            weightKg: _parseOptionalDouble(_weightController),
            waistCm: _parseOptionalDouble(_waistController),
            adherenceScore: _parseRequiredInt(_adherenceController),
            workoutsCompleted: _parseOptionalInt(_workoutsCompletedController),
            missedWorkouts: _parseOptionalInt(_missedWorkoutsController),
            missedWorkoutsReason: _optionalText(_missedReasonController),
            sorenessScore: _parseOptionalInt(_sorenessController),
            fatigueScore: _parseOptionalInt(_fatigueController),
            painWarning: _optionalText(_painController),
            nutritionAdherenceScore: _parseOptionalInt(_nutritionController),
            habitAdherenceScore: _parseOptionalInt(_habitController),
            biggestObstacle: _optionalText(_obstacleController),
            supportNeeded: _optionalText(_supportController),
            wins: _optionalText(_winsController),
            blockers: _optionalText(_blockersController),
            questions: _optionalText(_questionsController),
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

  String? _validate() {
    return _validatePercent(
          'Adherence',
          _adherenceController,
          required: true,
        ) ??
        _validateDoubleRange(
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
  }) {
    final text = controller.text.trim();
    if (text.isEmpty) {
      return null;
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
