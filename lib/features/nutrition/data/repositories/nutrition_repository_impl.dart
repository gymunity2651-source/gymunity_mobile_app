import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../domain/entities/nutrition_entities.dart';
import '../../domain/repositories/nutrition_repository.dart';

class NutritionRepositoryImpl implements NutritionRepository {
  NutritionRepositoryImpl(this._client);

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'No authenticated member found.');
    }
    return userId;
  }

  @override
  Future<NutritionProfileEntity?> getProfile() async {
    try {
      final row = await _client
          .from('nutrition_profiles')
          .select()
          .eq('member_id', _userId)
          .maybeSingle();
      return row == null ? null : NutritionProfileEntity.fromMap(row);
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<NutritionProfileEntity> upsertProfile(
    NutritionProfileEntity profile,
  ) async {
    try {
      final row = await _client
          .from('nutrition_profiles')
          .upsert(profile.copyWith(memberId: _userId).toUpsertMap())
          .select()
          .single();
      return NutritionProfileEntity.fromMap(row);
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<NutritionTargetEntity?> getActiveTarget() async {
    try {
      final row = await _client
          .from('nutrition_targets')
          .select()
          .eq('member_id', _userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : NutritionTargetEntity.fromMap(row);
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<NutritionTargetEntity> saveTarget(NutritionTargetEntity target) async {
    try {
      await _client
          .from('nutrition_targets')
          .update(<String, dynamic>{'status': 'archived'})
          .eq('member_id', _userId)
          .eq('status', 'active');
      final row = await _client
          .from('nutrition_targets')
          .insert(target.toInsertMap(memberIdOverride: _userId))
          .select()
          .single();
      return NutritionTargetEntity.fromMap(row);
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<List<NutritionMealTemplateEntity>> listMealTemplates() async {
    try {
      final rows = await _client
          .from('nutrition_meal_templates')
          .select()
          .eq('is_active', true)
          .order('meal_type', ascending: true)
          .order('calories', ascending: true);
      return (rows as List<dynamic>)
          .map(
            (row) => NutritionMealTemplateEntity.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<NutritionMealPlanEntity?> getActiveMealPlan() async {
    try {
      final row = await _client
          .from('member_meal_plans')
          .select()
          .eq('member_id', _userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return _hydrateMealPlan(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<NutritionMealPlanEntity> saveGeneratedMealPlan({
    required NutritionTargetEntity target,
    required DateTime startDate,
    required int mealCount,
    required List<NutritionMealPlanDayEntity> days,
    Map<String, dynamic> generationContext = const <String, dynamic>{},
  }) async {
    try {
      await _client
          .from('member_meal_plans')
          .update(<String, dynamic>{'status': 'archived'})
          .eq('member_id', _userId)
          .eq('status', 'active');
      final planRow = await _client
          .from('member_meal_plans')
          .insert(<String, dynamic>{
            'member_id': _userId,
            'target_id': target.id,
            'start_date': dateWire(startDate),
            'end_date': dateWire(startDate.add(const Duration(days: 6))),
            'meal_count': mealCount,
            'status': 'active',
            'generation_context_json': generationContext,
          })
          .select()
          .single();
      final planId = planRow['id'] as String;

      for (final day in days) {
        final dayRow = await _client
            .from('member_meal_plan_days')
            .insert(<String, dynamic>{
              'meal_plan_id': planId,
              'member_id': _userId,
              'plan_date': dateWire(day.planDate),
              'target_calories': day.targetCalories,
              'protein_g': day.proteinG,
              'carbs_g': day.carbsG,
              'fats_g': day.fatsG,
              'hydration_ml': day.hydrationMl,
            })
            .select()
            .single();
        final dayId = dayRow['id'] as String;
        final mealRows = day.meals.map((meal) {
          return <String, dynamic>{
            'meal_plan_day_id': dayId,
            'meal_plan_id': planId,
            'member_id': _userId,
            'plan_date': dateWire(day.planDate),
            'meal_type': meal.mealType,
            'scheduled_time': meal.scheduledTime,
            'template_id': meal.templateId,
            'title': meal.title,
            'description': meal.description,
            'calories': meal.calories,
            'protein_g': meal.proteinG,
            'carbs_g': meal.carbsG,
            'fats_g': meal.fatsG,
            'ingredients_json': meal.ingredients,
            'instructions': meal.instructions,
            'sort_order': meal.sortOrder,
          }..removeWhere((key, value) => value == null);
        }).toList(growable: false);
        if (mealRows.isNotEmpty) {
          await _client.from('member_planned_meals').insert(mealRows);
        }
      }

      return (await getActiveMealPlan()) ??
          NutritionMealPlanEntity.fromMap(planRow);
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<NutritionDaySummaryEntity> getDaySummary(DateTime date) async {
    try {
      final normalized = dateOnly(date);
      final target = await getActiveTarget();
      final plan = await getActiveMealPlan();
      NutritionMealPlanDayEntity? day;
      if (plan != null) {
        for (final item in plan.days) {
          if (dateWire(item.planDate) == dateWire(normalized)) {
            day = item;
            break;
          }
        }
      }
      final logs = await _listMealLogs(normalized);
      final hydration = await _listHydrationLogs(normalized);
      return NutritionDaySummaryEntity(
        date: normalized,
        target: target,
        day: day,
        logs: logs,
        hydrationLogs: hydration,
      );
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<void> completePlannedMeal(String plannedMealId) async {
    try {
      final meal = await _client
          .from('member_planned_meals')
          .select()
          .eq('id', plannedMealId)
          .eq('member_id', _userId)
          .single();
      final now = DateTime.now().toUtc().toIso8601String();
      await _client
          .from('member_planned_meals')
          .update(<String, dynamic>{'completed_at': now})
          .eq('id', plannedMealId)
          .eq('member_id', _userId);
      await _client.from('meal_logs').upsert(<String, dynamic>{
        'member_id': _userId,
        'planned_meal_id': plannedMealId,
        'log_date': meal['plan_date'],
        'source': 'planned',
        'title': meal['title'],
        'calories': meal['calories'],
        'protein_g': meal['protein_g'],
        'carbs_g': meal['carbs_g'],
        'fats_g': meal['fats_g'],
        'completed_at': now,
      });
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<void> uncompletePlannedMeal(String plannedMealId) async {
    try {
      await _client
          .from('member_planned_meals')
          .update(<String, dynamic>{'completed_at': null})
          .eq('id', plannedMealId)
          .eq('member_id', _userId);
      await _client
          .from('meal_logs')
          .delete()
          .eq('planned_meal_id', plannedMealId)
          .eq('member_id', _userId);
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<void> quickAddMeal({
    required DateTime date,
    required String title,
    required int calories,
    int proteinG = 0,
    int carbsG = 0,
    int fatsG = 0,
    String? note,
  }) async {
    try {
      await _client.from('meal_logs').insert(<String, dynamic>{
        'member_id': _userId,
        'log_date': dateWire(date),
        'source': 'quick_add',
        'title': title,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fats_g': fatsG,
        'note': note,
      }..removeWhere((key, value) => value == null));
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<void> addHydration({
    required DateTime date,
    required int amountMl,
  }) async {
    try {
      await _client.from('hydration_logs').insert(<String, dynamic>{
        'member_id': _userId,
        'log_date': dateWire(date),
        'amount_ml': amountMl,
      });
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<NutritionPlannedMealEntity> swapPlannedMeal({
    required String plannedMealId,
    required NutritionMealTemplateEntity template,
    required bool arabic,
  }) async {
    try {
      final row = await _client
          .from('member_planned_meals')
          .update(<String, dynamic>{
            'template_id': template.id,
            'title': template.title(arabic: arabic),
            'description': template.description(arabic: arabic),
            'calories': template.calories,
            'protein_g': template.proteinG,
            'carbs_g': template.carbsG,
            'fats_g': template.fatsG,
            'ingredients_json': template.ingredientsFor(arabic: arabic),
            'instructions': template.instructions(arabic: arabic),
            'completed_at': null,
          })
          .eq('id', plannedMealId)
          .eq('member_id', _userId)
          .select()
          .single();
      await _client
          .from('meal_logs')
          .delete()
          .eq('planned_meal_id', plannedMealId)
          .eq('member_id', _userId);
      return NutritionPlannedMealEntity.fromMap(row);
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<List<NutritionCheckinEntity>> listCheckins() async {
    try {
      final rows = await _client
          .from('nutrition_checkins')
          .select()
          .eq('member_id', _userId)
          .order('week_start', ascending: false)
          .limit(12);
      return (rows as List<dynamic>)
          .map(
            (row) => NutritionCheckinEntity.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<NutritionCheckinEntity> saveCheckin({
    required DateTime weekStart,
    required int adherenceScore,
    int? hungerScore,
    int? energyScore,
    String? notes,
    Map<String, dynamic> suggestedAdjustment = const <String, dynamic>{},
  }) async {
    try {
      final row = await _client
          .from('nutrition_checkins')
          .upsert(
            <String, dynamic>{
              'member_id': _userId,
              'week_start': dateWire(weekStart),
              'adherence_score': adherenceScore,
              'hunger_score': hungerScore,
              'energy_score': energyScore,
              'notes': notes,
              'suggested_adjustment_json': suggestedAdjustment,
            }..removeWhere((key, value) => value == null),
          )
          .select()
          .single();
      return NutritionCheckinEntity.fromMap(row);
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<NutritionGuidanceEntity> requestTaiyoNutritionGuidance({
    DateTime? date,
  }) async {
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthFailure(message: 'No authenticated member found.');
    }

    try {
      final response = await _client.functions.invoke(
        'taiyo-nutrition-context',
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        body: <String, dynamic>{
          'request_type': 'nutrition_guidance',
          'date': dateWire(date ?? DateTime.now()),
        },
      );
      return NutritionGuidanceEntity.fromResponse(response.data);
    } on FunctionException catch (error, stackTrace) {
      if (error.status == 401) {
        throw AuthFailure(
          message: 'Please sign in again to use TAIYO nutrition guidance.',
          code: error.status.toString(),
          cause: error,
          stackTrace: stackTrace,
        );
      }
      if (error.status == 403) {
        throw AuthFailure(
          message:
              'TAIYO nutrition guidance is available for member accounts only.',
          code: error.status.toString(),
          cause: error,
          stackTrace: stackTrace,
        );
      }
      throw NetworkFailure(
        message: _functionErrorMessage(
          error,
          'TAIYO could not prepare nutrition guidance right now.',
        ),
        code: error.status.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      if (error is AppFailure) {
        rethrow;
      }
      throw NetworkFailure(
        message: 'TAIYO could not prepare nutrition guidance right now.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<NutritionMealPlanEntity> _hydrateMealPlan(
    Map<String, dynamic> planRow,
  ) async {
    final planId = planRow['id'] as String;
    final dayRows = await _client
        .from('member_meal_plan_days')
        .select()
        .eq('meal_plan_id', planId)
        .eq('member_id', _userId)
        .order('plan_date', ascending: true);
    final mealRows = await _client
        .from('member_planned_meals')
        .select()
        .eq('meal_plan_id', planId)
        .eq('member_id', _userId)
        .order('plan_date', ascending: true)
        .order('sort_order', ascending: true);
    final mealsByDay = <String, List<NutritionPlannedMealEntity>>{};
    for (final row in mealRows as List<dynamic>) {
      final meal = NutritionPlannedMealEntity.fromMap(
        Map<String, dynamic>.from(row as Map),
      );
      mealsByDay.putIfAbsent(meal.mealPlanDayId, () => []).add(meal);
    }
    final days = (dayRows as List<dynamic>).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['id'] as String? ?? '';
      return NutritionMealPlanDayEntity.fromMap(
        map,
        meals: mealsByDay[id] ?? const <NutritionPlannedMealEntity>[],
      );
    }).toList(growable: false);
    return NutritionMealPlanEntity.fromMap(planRow, days: days);
  }

  Future<List<MealLogEntity>> _listMealLogs(DateTime date) async {
    final rows = await _client
        .from('meal_logs')
        .select()
        .eq('member_id', _userId)
        .eq('log_date', dateWire(date))
        .order('completed_at', ascending: true);
    return (rows as List<dynamic>)
        .map(
          (row) => MealLogEntity.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<List<HydrationLogEntity>> _listHydrationLogs(DateTime date) async {
    final rows = await _client
        .from('hydration_logs')
        .select()
        .eq('member_id', _userId)
        .eq('log_date', dateWire(date))
        .order('logged_at', ascending: true);
    return (rows as List<dynamic>)
        .map(
          (row) =>
              HydrationLogEntity.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  NetworkFailure _failure(PostgrestException e, StackTrace st) {
    return NetworkFailure(
      message: e.message,
      code: e.code,
      cause: e,
      stackTrace: st,
    );
  }

  String _functionErrorMessage(
    FunctionException error,
    String fallbackMessage,
  ) {
    final details = error.details?.toString() ?? '';
    return details.trim().isEmpty ? fallbackMessage : details.trim();
  }
}
