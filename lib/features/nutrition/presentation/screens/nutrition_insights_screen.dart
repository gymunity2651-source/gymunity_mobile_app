import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../providers/nutrition_providers.dart';
import '../widgets/nutrition_widgets.dart';

class NutritionInsightsScreen extends ConsumerWidget {
  const NutritionInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(nutritionDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nutrition insights')),
      body: AppShellBackground(
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          data: (dashboard) {
            final target = dashboard.target;
            return ListView(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              children: [
                NutritionInsightCard(insight: dashboard.insight),
                const SizedBox(height: 14),
                if (target != null)
                  Container(
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
                          'Why this target?',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ExplainRow(
                          label: 'BMR',
                          value: '${target.bmrCalories} kcal',
                        ),
                        _ExplainRow(
                          label: 'Maintenance',
                          value: '${target.tdeeCalories} kcal',
                        ),
                        _ExplainRow(
                          label: 'Target',
                          value: '${target.targetCalories} kcal',
                        ),
                        _ExplainRow(
                          label: 'Formula',
                          value:
                              target.explanation['formula']?.toString() ??
                              'Mifflin-St Jeor',
                        ),
                        _ExplainRow(
                          label: 'Rule',
                          value:
                              target.explanation['goal_rule']?.toString() ??
                              'Goal-aware calories and macros.',
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExplainRow extends StatelessWidget {
  const _ExplainRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
