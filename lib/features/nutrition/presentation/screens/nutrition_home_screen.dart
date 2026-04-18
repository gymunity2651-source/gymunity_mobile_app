import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../../domain/entities/nutrition_entities.dart';
import '../controllers/nutrition_day_controller.dart';
import '../providers/nutrition_providers.dart';
import '../widgets/nutrition_widgets.dart';

class NutritionHomeScreen extends ConsumerWidget {
  const NutritionHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(nutritionDashboardProvider);
    final today = dateOnly(DateTime.now());
    final dayController = ref.watch(nutritionDayControllerProvider(today));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nutrition'),
        actions: [
          IconButton(
            tooltip: 'Insights',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.nutritionInsights,
            ),
            icon: const Icon(Icons.insights_outlined),
          ),
          IconButton(
            tooltip: 'Preferences',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.nutritionPreferences,
            ),
            icon: const Icon(Icons.tune_outlined),
          ),
        ],
      ),
      body: AppShellBackground(
        child: RefreshIndicator.adaptive(
          onRefresh: () async => ref.refresh(nutritionDashboardProvider.future),
          child: dashboardAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _NutritionState(
              title: 'Nutrition needs a refresh',
              message: error.toString(),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(nutritionDashboardProvider),
            ),
            data: (dashboard) {
              if (!dashboard.isSetupComplete) {
                return _NutritionState(
                  title: 'Build your nutrition plan',
                  message:
                      'GymUnity will calculate calories, macros, meals, hydration, and progress guidance from your profile and training data.',
                  actionLabel: 'Start nutrition setup',
                  onAction: () =>
                      Navigator.pushNamed(context, AppRoutes.nutritionSetup),
                );
              }
              final target = dashboard.target!;
              final summary = dayController.valueOrNull ?? dashboard.today;
              return ListView(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                children: [
                  _Header(target: target),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: NutritionMetricCard(
                          title: 'CALORIES',
                          value:
                              '${summary.caloriesConsumed}/${target.targetCalories}',
                          subtitle: 'Consumed vs target',
                          icon: Icons.local_fire_department_outlined,
                          progress: summary.calorieProgress,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NutritionMetricCard(
                          title: 'MEALS',
                          value:
                              '${summary.mealsCompleted}/${summary.plannedMeals.length}',
                          subtitle: 'Completed today',
                          icon: Icons.restaurant_menu_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  NutritionInsightCard(
                    insight: dashboard.insight,
                    onApply: dashboard.insight.hasAdjustment
                        ? () => _applyAdjustment(context, ref, dashboard)
                        : null,
                  ),
                  const SizedBox(height: 14),
                  MacroBreakdownCard(target: target, summary: summary),
                  const SizedBox(height: 14),
                  HydrationCard(
                    currentMl: summary.hydrationConsumed,
                    targetMl: target.hydrationMl,
                    onAdd: (amount) => ref
                        .read(nutritionDayControllerProvider(today).notifier)
                        .addHydration(amount),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.nutritionMealPlan,
                    ),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Open meal plan'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.nutritionSetup,
                    ),
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Recalculate targets'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _applyAdjustment(
    BuildContext context,
    WidgetRef ref,
    NutritionDashboardState dashboard,
  ) async {
    final target = dashboard.target;
    final adjustment = dashboard.insight.calorieAdjustment;
    final profile = dashboard.nutritionProfile;
    if (target == null || adjustment == null || profile == null) {
      return;
    }
    try {
      final repo = ref.read(nutritionRepositoryProvider);
      final updated = await repo.saveTarget(
        target.adjusted(
          id: '',
          targetCalories: target.targetCalories + adjustment,
          reason: dashboard.insight.title,
        ),
      );
      final templates = await repo.listMealTemplates();
      final generated = ref.read(mealPlanGeneratorProvider).generate(
        target: updated,
        profile: profile,
        templates: templates,
        startDate: DateTime.now(),
      );
      await repo.saveGeneratedMealPlan(
        target: updated,
        startDate: generated.startDate,
        mealCount: generated.mealCount,
        days: generated.days,
        generationContext: const <String, dynamic>{
          'source': 'nutrition_adjustment',
        },
      );
      ref.invalidate(nutritionDashboardProvider);
      ref.invalidate(activeNutritionTargetProvider);
      ref.invalidate(activeMealPlanProvider);
      if (context.mounted) {
        showAppFeedback(context, 'Nutrition target updated.');
      }
    } catch (error) {
      if (context.mounted) {
        showAppFeedback(context, error.toString());
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.target});

  final NutritionTargetEntity target;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s nutrition target',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${target.targetCalories} kcal based on ${target.tdeeCalories} kcal maintenance.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionState extends StatelessWidget {
  const _NutritionState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        const SizedBox(height: 80),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.restaurant_menu_outlined,
                color: AppColors.orange,
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ],
    );
  }
}
