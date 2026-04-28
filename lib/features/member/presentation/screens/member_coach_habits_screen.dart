import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/coach_hub_entity.dart';
import '../providers/member_providers.dart';

class MemberCoachHabitsScreen extends ConsumerWidget {
  const MemberCoachHabitsScreen({super.key, this.subscriptionId});

  final String? subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(memberAssignedHabitsProvider(subscriptionId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Coach Habits'),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(memberAssignedHabitsProvider(subscriptionId));
          await ref.read(memberAssignedHabitsProvider(subscriptionId).future);
        },
        child: habitsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.orange),
          ),
          error: (error, _) => _StateText(text: error.toString()),
          data: (habits) {
            if (habits.isEmpty) {
              return const _StateText(
                text: 'Assigned habits from your coach will appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: habits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _HabitCard(
                habit: habits[index],
                subscriptionId: subscriptionId,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({required this.habit, required this.subscriptionId});

  final MemberAssignedHabitEntity habit;
  final String? subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  habit.title,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _Badge(habit.loggedToday ? habit.completionStatus! : 'pending'),
            ],
          ),
          const SizedBox(height: 6),
          if (habit.description.trim().isNotEmpty)
            Text(
              habit.description,
              style: GoogleFonts.inter(
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(habit.frequency),
              if (habit.targetValue != null)
                _Badge(
                  '${habit.targetValue!.toStringAsFixed(0)} ${habit.targetUnit ?? ''}',
                ),
              _Badge('${habit.adherencePercent}% this week'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _log(context, ref, 'completed'),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _log(context, ref, 'skipped'),
                  child: const Text('Skipped'),
                ),
              ),
              IconButton(
                tooltip: 'Add note',
                onPressed: () => _note(context, ref),
                icon: const Icon(Icons.note_add_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _log(
    BuildContext context,
    WidgetRef ref,
    String status, {
    String? note,
  }) async {
    try {
      await ref
          .read(memberRepositoryProvider)
          .logAssignedHabit(
            assignmentId: habit.id,
            completionStatus: status,
            note: note,
          );
      ref.invalidate(memberAssignedHabitsProvider(subscriptionId));
      ref.invalidate(memberCoachHubProvider(subscriptionId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Habit marked $status.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Habit could not be logged: $error')),
      );
    }
  }

  Future<void> _note(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: habit.note ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Habit note'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    if (!context.mounted) return;
    await _log(context, ref, 'partial', note: note);
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12)),
    );
  }
}

class _StateText extends StatelessWidget {
  const _StateText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        const SizedBox(height: 160),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
