import '../../../member/domain/entities/member_progress_entity.dart';
import '../entities/nutrition_entities.dart';

class NutritionAdaptationEngine {
  const NutritionAdaptationEngine();

  NutritionInsightEntity evaluate({
    required String goal,
    required NutritionTargetEntity? target,
    required List<WeightEntryEntity> weightEntries,
    required List<NutritionCheckinEntity> checkins,
    required NutritionDaySummaryEntity? today,
  }) {
    if (target == null) {
      return const NutritionInsightEntity(
        title: 'Set up nutrition',
        message: 'Complete nutrition setup to unlock calorie and meal guidance.',
      );
    }

    final adherence = _recentAdherence(checkins, today);
    final trend = _weightTrendPerWeek(weightEntries);
    if (trend == null) {
      return NutritionInsightEntity(
        title: 'Building your baseline',
        message:
            'Log weight a few more times so GymUnity can tune nutrition with real progress.',
        severity: 'info',
      );
    }

    final latestWeight = weightEntries.isEmpty ? null : weightEntries.last.weightKg;
    final normalizedGoal = goal.trim().toLowerCase();

    if (_isFatLoss(normalizedGoal) && latestWeight != null) {
      final percentWeekly = trend / latestWeight;
      if (percentWeekly <= -0.01) {
        return const NutritionInsightEntity(
          title: 'Progress is fast',
          message:
              'Your weight is dropping quickly. Consider a small calorie increase to protect energy and training quality.',
          calorieAdjustment: 125,
          severity: 'warning',
        );
      }
      if (percentWeekly > -0.002 && adherence >= 80) {
        return const NutritionInsightEntity(
          title: 'Fat-loss trend is flat',
          message:
              'Adherence looks solid, so a small calorie reduction may restart progress without becoming extreme.',
          calorieAdjustment: -125,
          severity: 'action',
        );
      }
      if (percentWeekly > -0.002 && adherence < 70) {
        return const NutritionInsightEntity(
          title: 'Consistency first',
          message:
              'Progress is flat, but adherence is still building. Complete more planned meals before cutting calories.',
        );
      }
    }

    if (_isMuscleGain(normalizedGoal)) {
      if (trend < 0.05 && adherence >= 80) {
        return const NutritionInsightEntity(
          title: 'Surplus may be low',
          message:
              'Training nutrition looks consistent, but weight is not moving. A small calorie bump can support muscle gain.',
          calorieAdjustment: 150,
          severity: 'action',
        );
      }
      if (trend > 0.6) {
        return const NutritionInsightEntity(
          title: 'Gain rate is high',
          message:
              'You are gaining quickly. Reducing calories slightly can keep the bulk cleaner.',
          calorieAdjustment: -100,
          severity: 'warning',
        );
      }
    }

    if (!_isFatLoss(normalizedGoal) && !_isMuscleGain(normalizedGoal)) {
      if (trend.abs() > 0.4 && adherence >= 75) {
        return NutritionInsightEntity(
          title: 'Maintenance drift detected',
          message:
              'Your trend is moving away from maintenance. A small target refresh can bring it back in line.',
          calorieAdjustment: trend > 0 ? -100 : 100,
          severity: 'action',
        );
      }
    }

    return const NutritionInsightEntity(
      title: 'Targets look reasonable',
      message:
          'Keep following the plan and log meals, hydration, and weight so recommendations stay personalized.',
      severity: 'success',
    );
  }

  double _recentAdherence(
    List<NutritionCheckinEntity> checkins,
    NutritionDaySummaryEntity? today,
  ) {
    if (checkins.isNotEmpty) {
      final recent = checkins.take(3).toList();
      return recent.fold<double>(
            0,
            (sum, checkin) => sum + checkin.adherenceScore,
          ) /
          recent.length;
    }
    if (today == null || today.plannedMeals.isEmpty) {
      return 0;
    }
    return today.mealsCompleted / today.plannedMeals.length * 100;
  }

  double? _weightTrendPerWeek(List<WeightEntryEntity> entries) {
    if (entries.length < 4) {
      return null;
    }
    final sorted = [...entries]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    final recent = sorted.length > 8 ? sorted.sublist(sorted.length - 8) : sorted;
    final first = recent.first;
    final last = recent.last;
    final days = last.recordedAt.difference(first.recordedAt).inDays.abs();
    if (days < 10) {
      return null;
    }
    return (last.weightKg - first.weightKg) / days * 7;
  }

  bool _isFatLoss(String goal) {
    return goal == 'weight_loss' || goal == 'fat_loss' || goal == 'lose_weight';
  }

  bool _isMuscleGain(String goal) {
    return goal == 'build_muscle' ||
        goal == 'muscle_gain' ||
        goal == 'strength';
  }
}
