import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/nutrition_entities.dart';
import '../providers/nutrition_providers.dart';

class NutritionDayController
    extends StateNotifier<AsyncValue<NutritionDaySummaryEntity>> {
  NutritionDayController(this._ref, this._date)
    : super(const AsyncValue.loading()) {
    unawaited(load());
  }

  final Ref _ref;
  final DateTime _date;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final summary = await _ref
          .read(nutritionRepositoryProvider)
          .getDaySummary(_date);
      state = AsyncValue.data(summary);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> toggleMeal(NutritionPlannedMealEntity meal) async {
    final repo = _ref.read(nutritionRepositoryProvider);
    if (meal.isCompleted) {
      await repo.uncompletePlannedMeal(meal.id);
    } else {
      await repo.completePlannedMeal(meal.id);
    }
    _invalidate();
    await load();
  }

  Future<void> quickAddMeal({
    required String title,
    required int calories,
    int proteinG = 0,
    int carbsG = 0,
    int fatsG = 0,
  }) async {
    await _ref.read(nutritionRepositoryProvider).quickAddMeal(
      date: _date,
      title: title,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatsG: fatsG,
    );
    _invalidate();
    await load();
  }

  Future<void> addHydration(int amountMl) async {
    await _ref
        .read(nutritionRepositoryProvider)
        .addHydration(date: _date, amountMl: amountMl);
    _invalidate();
    await load();
  }

  Future<void> swapMeal({
    required NutritionPlannedMealEntity meal,
    required NutritionMealTemplateEntity template,
    bool arabic = false,
  }) async {
    await _ref.read(nutritionRepositoryProvider).swapPlannedMeal(
      plannedMealId: meal.id,
      template: template,
      arabic: arabic,
    );
    _invalidate();
    await load();
  }

  void _invalidate() {
    _ref.invalidate(nutritionDaySummaryProvider(_date));
    _ref.invalidate(nutritionDashboardProvider);
    _ref.invalidate(activeMealPlanProvider);
  }
}

final nutritionDayControllerProvider =
    StateNotifierProvider.autoDispose
        .family<
          NutritionDayController,
          AsyncValue<NutritionDaySummaryEntity>,
          DateTime
        >((ref, date) {
          return NutritionDayController(ref, date);
        });
