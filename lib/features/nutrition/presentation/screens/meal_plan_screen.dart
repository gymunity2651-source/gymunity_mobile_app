import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../../domain/entities/nutrition_entities.dart';
import '../controllers/nutrition_day_controller.dart';
import '../providers/nutrition_providers.dart';
import '../widgets/nutrition_widgets.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key, this.openQuickAddOnLaunch = false});

  final bool openQuickAddOnLaunch;

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  late DateTime _selectedDate = dateOnly(DateTime.now());
  bool _openedQuickAdd = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_openedQuickAdd || !widget.openQuickAddOnLaunch) {
      return;
    }
    _openedQuickAdd = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _openQuickAddSheet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(activeMealPlanProvider);
    final summaryAsync = ref.watch(
      nutritionDayControllerProvider(_selectedDate),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Meal plan')),
      body: AppShellBackground(
        child: planAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _MessageState(message: error.toString()),
          data: (plan) {
            if (plan == null) {
              return const _MessageState(
                message: 'Set up nutrition to generate your first meal plan.',
              );
            }
            return Column(
              children: [
                SizedBox(
                  height: 82,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final date = dateOnly(
                        plan.startDate.add(Duration(days: index)),
                      );
                      final selected =
                          dateWire(date) == dateWire(_selectedDate);
                      return ChoiceChip(
                        label: Text(_dayLabel(date)),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedDate = date),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemCount:
                        plan.endDate.difference(plan.startDate).inDays + 1,
                  ),
                ),
                Expanded(
                  child: summaryAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) =>
                        _MessageState(message: error.toString()),
                    data: (summary) => ListView(
                      padding: const EdgeInsets.all(AppSizes.screenPadding),
                      children: [
                        NutritionMetricCard(
                          title: 'DAY TARGET',
                          value:
                              '${summary.caloriesConsumed}/${summary.day?.targetCalories ?? summary.target?.targetCalories ?? 0}',
                          subtitle: 'Calories tracked',
                          icon: Icons.local_fire_department_outlined,
                          progress: summary.calorieProgress,
                        ),
                        const SizedBox(height: 14),
                        for (final meal in summary.plannedMeals) ...[
                          PlannedMealCard(
                            meal: meal,
                            onToggle: () => _run(
                              ref
                                  .read(
                                    nutritionDayControllerProvider(
                                      _selectedDate,
                                    ).notifier,
                                  )
                                  .toggleMeal(meal),
                            ),
                            onSwap: () => _openSwapSheet(meal),
                          ),
                          const SizedBox(height: 12),
                        ],
                        HydrationCard(
                          currentMl: summary.hydrationConsumed,
                          targetMl:
                              summary.day?.hydrationMl ??
                              summary.target?.hydrationMl ??
                              0,
                          onAdd: (amount) => _run(
                            ref
                                .read(
                                  nutritionDayControllerProvider(
                                    _selectedDate,
                                  ).notifier,
                                )
                                .addHydration(amount),
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _openQuickAddSheet,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Quick add meal'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _run(Future<void> action) async {
    try {
      await action;
    } catch (error) {
      if (mounted) showAppFeedback(context, error.toString());
    }
  }

  Future<void> _openQuickAddSheet() async {
    final titleController = TextEditingController(text: 'Custom meal');
    final caloriesController = TextEditingController(text: '300');
    final proteinController = TextEditingController(text: '20');
    final carbsController = TextEditingController(text: '30');
    final fatsController = TextEditingController(text: '8');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Meal name'),
              ),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calories'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Protein'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Carbs'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Fats'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _run(
                    ref
                        .read(
                          nutritionDayControllerProvider(
                            _selectedDate,
                          ).notifier,
                        )
                        .quickAddMeal(
                          title: titleController.text.trim(),
                          calories: int.tryParse(caloriesController.text) ?? 0,
                          proteinG: int.tryParse(proteinController.text) ?? 0,
                          carbsG: int.tryParse(carbsController.text) ?? 0,
                          fatsG: int.tryParse(fatsController.text) ?? 0,
                        ),
                  );
                },
                child: const Text('Add meal'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSwapSheet(NutritionPlannedMealEntity meal) async {
    final templates = await ref.read(nutritionMealTemplatesProvider.future);
    if (!mounted) return;
    final candidates = templates
        .where((template) => template.mealType == meal.mealType)
        .take(8)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final template in candidates)
              ListTile(
                title: Text(template.titleEn),
                subtitle: Text(
                  '${template.calories} kcal | P ${template.proteinG}g',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _run(
                    ref
                        .read(
                          nutritionDayControllerProvider(
                            _selectedDate,
                          ).notifier,
                        )
                        .swapMeal(meal: meal, template: template),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

String _dayLabel(DateTime date) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[date.weekday - 1]}\n${date.month}/${date.day}';
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
