import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/planner_builder_entities.dart';

class PlannerBuilderProgressHeader extends StatelessWidget {
  const PlannerBuilderProgressHeader({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.progress,
  });

  final int stepNumber;
  final int totalSteps;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              totalSteps == 0 ? 'Builder' : 'Step $stepNumber of $totalSteps',
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
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            backgroundColor: AppColors.surfaceRaised,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
          ),
        ),
      ],
    );
  }
}

class PlannerBuilderQuestionCard extends StatelessWidget {
  const PlannerBuilderQuestionCard({
    super.key,
    required this.question,
    required this.answer,
    required this.onChanged,
  });

  final PlannerBuilderQuestion question;
  final PlannerBuilderAnswer? answer;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.confirmation)
            const _QuestionPill(label: 'Pre-filled from your data'),
          if (question.confirmation) const SizedBox(height: 12),
          Text(
            question.title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            question.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _QuestionInput(
            question: question,
            answer: answer,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class PlannerBuilderSummaryTile extends StatelessWidget {
  const PlannerBuilderSummaryTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.borderLight),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.edit_outlined, color: AppColors.orange, size: 18),
          ],
        ),
      ),
    );
  }
}

class PlannerBuilderNoticeCard extends StatelessWidget {
  const PlannerBuilderNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.orange, size: 38),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _QuestionInput extends StatelessWidget {
  const _QuestionInput({
    required this.question,
    required this.answer,
    required this.onChanged,
  });

  final PlannerBuilderQuestion question;
  final PlannerBuilderAnswer? answer;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (question.inputKind) {
      case PlannerBuilderInputKind.notice:
        return const SizedBox.shrink();
      case PlannerBuilderInputKind.slider:
        return _SliderInput(
          question: question,
          value: answer?.intValue,
          onChanged: onChanged,
        );
      case PlannerBuilderInputKind.multiChoice:
        return _ChoiceWrap(
          question: question,
          selectedValues: answer?.stringListValue ?? const <String>[],
          multiple: true,
          onChanged: onChanged,
        );
      case PlannerBuilderInputKind.singleChoice:
        return _ChoiceWrap(
          question: question,
          selectedValues: answer?.stringValue == null
              ? const <String>[]
              : <String>[answer!.stringValue!],
          multiple: false,
          onChanged: onChanged,
        );
      case PlannerBuilderInputKind.text:
        return TextFormField(
          initialValue: answer?.stringValue ?? '',
          minLines: 2,
          maxLines: 4,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: question.placeholder ?? 'Type your answer',
          ),
        );
    }
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.question,
    required this.selectedValues,
    required this.multiple,
    required this.onChanged,
  });

  final PlannerBuilderQuestion question;
  final List<String> selectedValues;
  final bool multiple;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: question.options
          .map((option) {
            final selected = selectedValues.contains(option.value);
            return _OptionPill(
              option: option,
              selected: selected,
              onTap: () {
                if (!multiple) {
                  onChanged(option.value);
                  return;
                }
                final next = List<String>.from(selectedValues);
                if (selected) {
                  next.remove(option.value);
                } else {
                  if (option.value == 'none') {
                    next.clear();
                  } else {
                    next.remove('none');
                  }
                  next.add(option.value);
                }
                onChanged(next);
              },
            );
          })
          .toList(growable: false),
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PlannerBuilderOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.orange.withValues(alpha: 0.13)
              : AppColors.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_rounded,
                color: AppColors.orange,
                size: 17,
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                option.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.orange : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderInput extends StatefulWidget {
  const _SliderInput({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final PlannerBuilderQuestion question;
  final int? value;
  final ValueChanged<Object?> onChanged;

  @override
  State<_SliderInput> createState() => _SliderInputState();
}

class _SliderInputState extends State<_SliderInput> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = (widget.value ?? 45).toDouble();
  }

  @override
  void didUpdateWidget(covariant _SliderInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != null) {
      _value = widget.value!.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final min = widget.question.min ?? 0;
    final max = widget.question.max ?? 100;
    final divisions = widget.question.divisions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Text(
            '${_value.round()}${widget.question.valueSuffix}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.orange,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Slider(
          value: _value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.orange,
          inactiveColor: AppColors.border,
          onChanged: (next) {
            setState(() => _value = next);
            widget.onChanged(next.round());
          },
        ),
      ],
    );
  }
}

class _QuestionPill extends StatelessWidget {
  const _QuestionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.orange,
        ),
      ),
    );
  }
}
