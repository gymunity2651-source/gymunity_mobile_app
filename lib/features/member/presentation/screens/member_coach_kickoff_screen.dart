import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../providers/member_providers.dart';

class MemberCoachKickoffScreen extends ConsumerStatefulWidget {
  const MemberCoachKickoffScreen({super.key, required this.subscriptionId});

  final String subscriptionId;

  @override
  ConsumerState<MemberCoachKickoffScreen> createState() =>
      _MemberCoachKickoffScreenState();
}

class _MemberCoachKickoffScreenState
    extends ConsumerState<MemberCoachKickoffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _goal = TextEditingController();
  final _level = TextEditingController();
  final _days = TextEditingController();
  final _equipment = TextEditingController();
  final _injuries = TextEditingController();
  final _schedule = TextEditingController();
  final _nutrition = TextEditingController();
  final _sleep = TextEditingController();
  final _obstacle = TextEditingController();
  final _expectations = TextEditingController();
  final _note = TextEditingController();

  var _shareProgress = true;
  var _shareNutrition = false;
  var _shareAi = false;
  var _shareWorkout = true;
  var _shareProduct = false;
  var _isSaving = false;

  @override
  void dispose() {
    _goal.dispose();
    _level.dispose();
    _days.dispose();
    _equipment.dispose();
    _injuries.dispose();
    _schedule.dispose();
    _nutrition.dispose();
    _sleep.dispose();
    _obstacle.dispose();
    _expectations.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Coach Kickoff'),
        backgroundColor: AppColors.background,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(
              'Set up your coaching relationship',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your coach uses this to build the first plan and decide what to review each week.',
              style: GoogleFonts.inter(
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _field(_goal, 'Primary goal', required: true),
            _field(_level, 'Training level', required: true),
            _field(_days, 'Preferred training days', hint: 'Sunday, Tuesday'),
            _field(_equipment, 'Available equipment', hint: 'Gym, dumbbells'),
            _field(_injuries, 'Injuries or pain limitations', lines: 2),
            _field(_schedule, 'Schedule constraints', lines: 2),
            _field(_nutrition, 'Nutrition situation', lines: 2),
            _field(_sleep, 'Sleep and recovery notes', lines: 2),
            _field(_obstacle, 'Biggest obstacle', lines: 2, required: true),
            _field(_expectations, 'Expectations from your coach', lines: 2),
            _field(_note, 'Optional note to coach', lines: 3),
            const SizedBox(height: 10),
            _PrivacyCard(
              shareProgress: _shareProgress,
              shareNutrition: _shareNutrition,
              shareAi: _shareAi,
              shareWorkout: _shareWorkout,
              shareProduct: _shareProduct,
              onProgress: (value) => setState(() => _shareProgress = value),
              onNutrition: (value) => setState(() => _shareNutrition = value),
              onAi: (value) => setState(() => _shareAi = value),
              onWorkout: (value) => setState(() => _shareWorkout = value),
              onProduct: (value) => setState(() => _shareProduct = value),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: AppColors.white,
              ),
              child: Text(_isSaving ? 'Saving...' : 'Complete kickoff'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int lines = 1,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 1,
        validator: required
            ? (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null
            : null,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(memberRepositoryProvider)
          .submitCoachKickoff(
            subscriptionId: widget.subscriptionId,
            primaryGoal: _goal.text.trim(),
            trainingLevel: _level.text.trim(),
            preferredTrainingDays: _split(_days.text),
            availableEquipment: _split(_equipment.text),
            injuriesLimitations: _injuries.text.trim(),
            scheduleConstraints: _schedule.text.trim(),
            nutritionSituation: _nutrition.text.trim(),
            sleepRecoveryNotes: _sleep.text.trim(),
            biggestObstacle: _obstacle.text.trim(),
            coachExpectations: _expectations.text.trim(),
            memberNote: _note.text.trim(),
            shareProgressSummary: _shareProgress,
            shareNutritionSummary: _shareNutrition,
            shareAiSummary: _shareAi,
            shareWorkoutAdherence: _shareWorkout,
            shareProductContext: _shareProduct,
          );
      ref.invalidate(memberCoachHubProvider(widget.subscriptionId));
      ref.invalidate(memberCoachHubProvider(null));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kickoff could not be saved: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<String> _split(String raw) => raw
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.shareProgress,
    required this.shareNutrition,
    required this.shareAi,
    required this.shareWorkout,
    required this.shareProduct,
    required this.onProgress,
    required this.onNutrition,
    required this.onAi,
    required this.onWorkout,
    required this.onProduct,
  });

  final bool shareProgress;
  final bool shareNutrition;
  final bool shareAi;
  final bool shareWorkout;
  final bool shareProduct;
  final ValueChanged<bool> onProgress;
  final ValueChanged<bool> onNutrition;
  final ValueChanged<bool> onAi;
  final ValueChanged<bool> onWorkout;
  final ValueChanged<bool> onProduct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coach visibility',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: shareProgress,
            onChanged: onProgress,
            title: const Text('Progress summary'),
          ),
          SwitchListTile.adaptive(
            value: shareWorkout,
            onChanged: onWorkout,
            title: const Text('Workout adherence'),
          ),
          SwitchListTile.adaptive(
            value: shareNutrition,
            onChanged: onNutrition,
            title: const Text('Nutrition summary'),
          ),
          SwitchListTile.adaptive(
            value: shareAi,
            onChanged: onAi,
            title: const Text('TAIYO summary'),
          ),
          SwitchListTile.adaptive(
            value: shareProduct,
            onChanged: onProduct,
            title: const Text('Store context'),
          ),
        ],
      ),
    );
  }
}
