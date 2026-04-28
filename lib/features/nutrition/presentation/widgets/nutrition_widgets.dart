import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/nutrition_entities.dart';
import '../../domain/services/nutrition_setup_question_factory.dart';

class NutritionMetricCard extends StatelessWidget {
  const NutritionMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.progress,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1),
                minHeight: 7,
                backgroundColor: AppColors.surfaceRaised,
                valueColor: const AlwaysStoppedAnimation(AppColors.orange),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MacroBreakdownCard extends StatelessWidget {
  const MacroBreakdownCard({super.key, required this.target, this.summary});

  final NutritionTargetEntity target;
  final NutritionDaySummaryEntity? summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macro targets',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _MacroRow(
            label: 'Protein',
            current: summary?.proteinConsumed ?? 0,
            target: target.proteinG,
            color: AppColors.orange,
          ),
          _MacroRow(
            label: 'Carbs',
            current: summary?.carbsConsumed ?? 0,
            target: target.carbsG,
            color: AppColors.info,
          ),
          _MacroRow(
            label: 'Fats',
            current: summary?.fatsConsumed ?? 0,
            target: target.fatsG,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class NutritionInsightCard extends StatelessWidget {
  const NutritionInsightCard({super.key, required this.insight, this.onApply});

  final NutritionInsightEntity insight;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_outlined, color: AppColors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  insight.title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.message,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (insight.hasAdjustment && onApply != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.tune_outlined),
              label: Text(
                insight.calorieAdjustment! > 0
                    ? 'Apply +${insight.calorieAdjustment} kcal'
                    : 'Apply ${insight.calorieAdjustment} kcal',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PlannedMealCard extends StatelessWidget {
  const PlannedMealCard({
    super.key,
    required this.meal,
    required this.onToggle,
    required this.onSwap,
  });

  final NutritionPlannedMealEntity meal;
  final VoidCallback onToggle;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: meal.isCompleted ? AppColors.success : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                meal.isCompleted
                    ? Icons.check_circle
                    : Icons.restaurant_menu_outlined,
                color: meal.isCompleted ? AppColors.success : AppColors.orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  meal.title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${meal.calories} kcal  |  P ${meal.proteinG}g  C ${meal.carbsG}g  F ${meal.fatsG}g',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (meal.ingredients.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meal.ingredients.join(', '),
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onToggle,
                  child: Text(meal.isCompleted ? 'Undo' : 'Mark complete'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Swap meal',
                onPressed: onSwap,
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HydrationCard extends StatelessWidget {
  const HydrationCard({
    super.key,
    required this.currentMl,
    required this.targetMl,
    required this.onAdd,
  });

  final int currentMl;
  final int targetMl;
  final ValueChanged<int> onAdd;

  @override
  Widget build(BuildContext context) {
    final progress = targetMl <= 0 ? 0.0 : currentMl / targetMl;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hydration',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$currentMl / $targetMl ml',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            backgroundColor: AppColors.surfaceRaised,
            valueColor: const AlwaysStoppedAnimation(AppColors.info),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              ActionChip(label: const Text('+250 ml'), onPressed: () => onAdd(250)),
              ActionChip(label: const Text('+500 ml'), onPressed: () => onAdd(500)),
            ],
          ),
        ],
      ),
    );
  }
}

class NutritionSetupQuestionCard extends StatelessWidget {
  const NutritionSetupQuestionCard({
    super.key,
    required this.question,
    required this.answer,
    required this.progressLabel,
    required this.progress,
    required this.onChanged,
  });

  final NutritionSetupQuestion question;
  final Object? answer;
  final String progressLabel;
  final double progress;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                progressLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 7,
            backgroundColor: AppColors.surfaceRaised,
            valueColor: const AlwaysStoppedAnimation(AppColors.orange),
          ),
          const SizedBox(height: 20),
          Text(
            question.title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            question.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          _SetupInput(question: question, answer: answer, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  final String label;
  final int current;
  final int target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 0.0 : current / target;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$current / $target g',
                style: GoogleFonts.inter(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 7,
            backgroundColor: AppColors.surfaceRaised,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ],
      ),
    );
  }
}

class _SetupInput extends StatelessWidget {
  const _SetupInput({
    required this.question,
    required this.answer,
    required this.onChanged,
  });

  final NutritionSetupQuestion question;
  final Object? answer;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (question.inputKind) {
      case NutritionSetupInputKind.singleChoice:
        final selected = answer?.toString();
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: question.options.map((option) {
            return ChoiceChip(
              label: Text(option.label),
              selected: selected == option.value,
              onSelected: (_) => onChanged(option.value),
            );
          }).toList(growable: false),
        );
      case NutritionSetupInputKind.multiChoice:
        final selectedValues = switch (answer) {
          final Iterable<Object?> items => items,
          _ => const <Object?>[],
        };
        final selected = selectedValues
            .map((item) => item.toString())
            .toSet();
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: question.options.map((option) {
            final isSelected = selected.contains(option.value);
            return FilterChip(
              label: Text(option.label),
              selected: isSelected,
              onSelected: (_) {
                final next = Set<String>.from(selected);
                if (isSelected) {
                  next.remove(option.value);
                } else {
                  next.add(option.value);
                }
                onChanged(next.toList());
              },
            );
          }).toList(growable: false),
        );
      case NutritionSetupInputKind.slider:
      case NutritionSetupInputKind.number:
        final min = question.min ?? 0;
        final max = question.max ?? 100;
        final numericAnswer = answer;
        final current =
            ((numericAnswer is num)
                    ? numericAnswer.toDouble()
                    : (min + max) / 2)
                .clamp(min, max)
                .toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${current.round()}${question.suffix}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.orange,
              ),
            ),
            Slider(
              value: current,
              min: min,
              max: max,
              divisions: question.divisions,
              onChanged: (value) => onChanged(value.round()),
            ),
          ],
        );
    }
  }
}
