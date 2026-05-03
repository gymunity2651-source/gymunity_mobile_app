import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../domain/entities/ai_coach_entities.dart';
import '../../domain/repositories/ai_coach_repository.dart';

const String kAiCoachBackendUnavailableMessage =
    'TAIYO Coach needs the latest backend update before this action can run.';

const String _taiyoDailyBriefFunctionName = 'taiyo-daily-brief';

const String _legacyCoachFallbackReason =
    'This summary is built from your active plan and nutrition progress while the full coach engine finishes syncing.';

const List<String> _aiCoachBackendMarkers = <String>[
  'ai-coach',
  'member_ai_daily_briefs',
  'member_ai_nudges',
  'member_ai_weekly_summaries',
  'member_active_workout_sessions',
  'member_active_workout_events',
  'member_daily_readiness_logs',
  'get_member_ai_coach_context',
  'upsert_member_readiness_log',
  'apply_member_ai_adjustment',
  'start_member_active_workout',
  'record_member_active_workout_event',
  'complete_member_active_workout',
  'share_member_ai_weekly_summary',
  'build_member_ai_weekly_summary',
];

const List<String> _missingSchemaPhrases = <String>[
  'does not exist',
  'could not find',
  'schema cache',
  'not found',
];

bool isMissingAiCoachSchemaError(PostgrestException error) {
  final code = (error.code ?? '').trim().toUpperCase();
  if (code == '42P01' ||
      code == '42883' ||
      code == 'PGRST202' ||
      code == 'PGRST205') {
    return true;
  }
  return _matchesAiCoachBackendGapText(error.message);
}

bool isAiCoachBackendUnavailableFailure(AppFailure failure) {
  if (failure.message == kAiCoachBackendUnavailableMessage) {
    return true;
  }
  final message = '${failure.message} ${failure.cause ?? ''}';
  if (_matchesAiCoachBackendGapText(message)) {
    return true;
  }
  final code = (failure.code ?? '').trim();
  return code == '404' && message.toLowerCase().contains('ai-coach');
}

bool _matchesAiCoachBackendGapText(String text) {
  final normalized = text.toLowerCase();
  final hasMarker = _aiCoachBackendMarkers.any(normalized.contains);
  final hasMissingPhrase = _missingSchemaPhrases.any(normalized.contains);
  return hasMarker && hasMissingPhrase;
}

bool _matchesTaiyoDailyBriefBackendGapText(String text) {
  final normalized = text.toLowerCase();
  final hasMarker =
      normalized.contains(_taiyoDailyBriefFunctionName) ||
      normalized.contains('daily_member_brief');
  final hasMissingPhrase = _missingSchemaPhrases.any(normalized.contains);
  return hasMarker && hasMissingPhrase;
}

class _LegacyNutritionSnapshot {
  const _LegacyNutritionSnapshot({
    this.targetCalories,
    this.targetHydrationMl,
    this.plannedMeals = 0,
    this.loggedMeals = 0,
    this.hydrationConsumedMl = 0,
  });

  final int? targetCalories;
  final int? targetHydrationMl;
  final int plannedMeals;
  final int loggedMeals;
  final int hydrationConsumedMl;

  bool get hasAnyData =>
      targetCalories != null ||
      targetHydrationMl != null ||
      plannedMeals > 0 ||
      loggedMeals > 0 ||
      hydrationConsumedMl > 0;

  double get hydrationProgress {
    final target = targetHydrationMl ?? 0;
    if (target <= 0) {
      return 0;
    }
    return hydrationConsumedMl / target;
  }
}

class AiCoachRepositoryImpl implements AiCoachRepository {
  AiCoachRepositoryImpl(this._client);

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'No authenticated member found.');
    }
    return userId;
  }

  @override
  Future<AiDailyBriefEntity?> getDailyBrief(DateTime date) async {
    try {
      final row = await _client
          .from('member_ai_daily_briefs')
          .select()
          .eq('member_id', _userId)
          .eq('brief_date', _dateWire(date))
          .maybeSingle();
      return row == null ? null : AiDailyBriefEntity.fromMap(_rowMap(row));
    } on PostgrestException catch (e, st) {
      if (isMissingAiCoachSchemaError(e)) {
        return _buildLegacyDailyBrief(date);
      }
      throw _failure(e, st);
    }
  }

  @override
  Future<AiDailyBriefEntity> refreshDailyBrief(DateTime date) async {
    try {
      final response = await _invokeTaiyoDailyBrief(<String, dynamic>{
        'date': _dateWire(date),
      });
      final responseMap = _rowMap(response);
      _validateTaiyoDailyBriefResponse(responseMap);
      return AiDailyBriefEntity.fromTaiyoDailyBriefResponse(
        responseMap,
        briefDate: date,
      );
    } catch (e, st) {
      if (e is AppFailure) {
        if (isAiCoachBackendUnavailableFailure(e)) {
          return _buildLegacyDailyBrief(date);
        }
        rethrow;
      }
      throw NetworkFailure(
        message: 'TAIYO could not refresh today\'s coach brief.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<AiReadinessLogEntity> upsertReadiness({
    DateTime? logDate,
    int? energyLevel,
    int? sorenessLevel,
    int? stressLevel,
    int? availableMinutes,
    String? locationMode,
    List<String> equipmentOverride = const <String>[],
    String? note,
    String source = 'member',
  }) async {
    try {
      final result = await _client.rpc(
        'upsert_member_readiness_log',
        params: <String, dynamic>{
          'input_log_date': _dateWire(logDate ?? DateTime.now()),
          'input_energy_level': energyLevel,
          'input_soreness_level': sorenessLevel,
          'input_stress_level': stressLevel,
          'input_available_minutes': availableMinutes,
          'input_location_mode': locationMode,
          'input_equipment_override': equipmentOverride,
          'input_note': note,
          'input_source': source,
        },
      );
      return AiReadinessLogEntity.fromMap(_rowMap(result));
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<AiPlanAdaptationEntity> applyAdjustment({
    required String adjustmentType,
    DateTime? briefDate,
    String? taskId,
  }) async {
    try {
      final result = await _client.rpc(
        'apply_member_ai_adjustment',
        params: <String, dynamic>{
          'input_adjustment_type': adjustmentType,
          'input_brief_date': _dateWire(briefDate ?? DateTime.now()),
          'input_task_id': taskId,
        },
      );
      return AiPlanAdaptationEntity.fromRpc(_rowMap(result));
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<List<AiNudgeEntity>> listNudges() async {
    try {
      final rows = await _client
          .from('member_ai_nudges')
          .select()
          .eq('member_id', _userId)
          .inFilter('status', <String>['pending', 'delivered'])
          .order('available_at', ascending: true);
      return (rows as List<dynamic>)
          .map((dynamic row) => AiNudgeEntity.fromMap(_rowMap(row)))
          .toList(growable: false);
    } on PostgrestException catch (e, st) {
      if (isMissingAiCoachSchemaError(e)) {
        return const <AiNudgeEntity>[];
      }
      throw _failure(e, st);
    }
  }

  @override
  Future<void> runAccountabilityScan() async {
    try {
      await _invokeAiCoach(<String, dynamic>{
        'mode': 'run_accountability_scan',
      });
    } on AppFailure catch (e) {
      if (isAiCoachBackendUnavailableFailure(e)) {
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> maintainMemory() async {
    try {
      await _invokeAiCoach(<String, dynamic>{'mode': 'maintain_memory'});
    } on AppFailure catch (e) {
      if (isAiCoachBackendUnavailableFailure(e)) {
        return;
      }
      rethrow;
    }
  }

  @override
  Future<ActiveWorkoutSessionEntity?> getActiveWorkoutSession(
    String sessionId,
  ) async {
    try {
      final row = await _client
          .from('member_active_workout_sessions')
          .select()
          .eq('id', sessionId)
          .eq('member_id', _userId)
          .maybeSingle();
      return row == null
          ? null
          : ActiveWorkoutSessionEntity.fromMap(_rowMap(row));
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<ActiveWorkoutSessionEntity> startActiveWorkout({
    required String planId,
    String? dayId,
    DateTime? targetDate,
  }) async {
    try {
      final result = await _client.rpc(
        'start_member_active_workout',
        params: <String, dynamic>{
          'input_plan_id': planId,
          'input_day_id': dayId,
          'input_target_date': _dateWire(targetDate ?? DateTime.now()),
        },
      );
      return ActiveWorkoutSessionEntity.fromMap(_rowMap(result));
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<void> recordActiveWorkoutEvent({
    required String sessionId,
    required String eventType,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    try {
      await _client.rpc(
        'record_member_active_workout_event',
        params: <String, dynamic>{
          'input_session_id': sessionId,
          'input_event_type': eventType,
          'input_event_payload': payload,
        },
      );
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<ActiveWorkoutSessionEntity> completeActiveWorkout({
    required String sessionId,
    int? difficultyScore,
    Map<String, dynamic> summary = const <String, dynamic>{},
  }) async {
    try {
      final result = await _client.rpc(
        'complete_member_active_workout',
        params: <String, dynamic>{
          'input_session_id': sessionId,
          'input_difficulty_score': difficultyScore,
          'input_summary': summary,
        },
      );
      return ActiveWorkoutSessionEntity.fromMap(_rowMap(result));
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  @override
  Future<Map<String, dynamic>> getWorkoutPrompt({
    required String sessionId,
    String promptKind = 'mid_session',
  }) async {
    final response = await _invokeAiCoach(<String, dynamic>{
      'mode': 'workout_prompt',
      'session_id': sessionId,
      'prompt_kind': promptKind,
    });
    return _rowMap(_rowMap(response)['prompt']);
  }

  @override
  Future<AiWeeklySummaryEntity?> getWeeklySummary(DateTime weekStart) async {
    try {
      final row = await _client
          .from('member_ai_weekly_summaries')
          .select()
          .eq('member_id', _userId)
          .eq('week_start', _dateWire(_startOfWeek(weekStart)))
          .maybeSingle();
      return row == null ? null : AiWeeklySummaryEntity.fromMap(_rowMap(row));
    } on PostgrestException catch (e, st) {
      if (isMissingAiCoachSchemaError(e)) {
        return null;
      }
      throw _failure(e, st);
    }
  }

  @override
  Future<AiWeeklySummaryEntity> refreshWeeklySummary(DateTime weekStart) async {
    final response = await _invokeAiCoach(<String, dynamic>{
      'mode': 'refresh_weekly_summary',
      'week_start': _dateWire(_startOfWeek(weekStart)),
    });
    final summaryMap = _rowMap(_rowMap(response)['weekly_summary']);
    if (summaryMap.isEmpty) {
      throw const NetworkFailure(
        message: 'TAIYO could not refresh the weekly summary.',
      );
    }
    return AiWeeklySummaryEntity.fromMap(summaryMap);
  }

  @override
  Future<void> shareWeeklySummary(DateTime weekStart) async {
    try {
      await _client.rpc(
        'share_member_ai_weekly_summary',
        params: <String, dynamic>{
          'input_week_start': _dateWire(_startOfWeek(weekStart)),
        },
      );
    } on PostgrestException catch (e, st) {
      throw _failure(e, st);
    }
  }

  Future<dynamic> _invokeAiCoach(Map<String, dynamic> body) async {
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthFailure(message: 'No authenticated member found.');
    }

    try {
      final response = await _client.functions.invoke(
        'ai-coach',
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        body: body,
      );
      return response.data;
    } on FunctionException catch (e, st) {
      final detailsText = e.details?.toString() ?? '';
      final message =
          e.status == 404 || _matchesAiCoachBackendGapText(detailsText)
          ? kAiCoachBackendUnavailableMessage
          : (detailsText.isNotEmpty
                ? detailsText
                : 'TAIYO is unavailable right now.');
      throw NetworkFailure(
        message: message,
        code: e.status.toString(),
        cause: e,
        stackTrace: st,
      );
    }
  }

  Future<dynamic> _invokeTaiyoDailyBrief(Map<String, dynamic> body) async {
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthFailure(message: 'No authenticated member found.');
    }

    try {
      final response = await _client.functions.invoke(
        _taiyoDailyBriefFunctionName,
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        body: body,
      );
      return response.data;
    } on FunctionException catch (e, st) {
      if (e.status == 401) {
        throw AuthFailure(
          message: 'Please sign in again to refresh your TAIYO daily brief.',
          code: e.status.toString(),
          cause: e,
          stackTrace: st,
        );
      }
      if (e.status == 403) {
        throw AuthFailure(
          message: 'TAIYO daily brief is available for member accounts only.',
          code: e.status.toString(),
          cause: e,
          stackTrace: st,
        );
      }
      final detailsText = e.details?.toString() ?? '';
      final message =
          e.status == 404 || _matchesTaiyoDailyBriefBackendGapText(detailsText)
          ? kAiCoachBackendUnavailableMessage
          : 'TAIYO could not refresh today\'s daily brief.';
      throw NetworkFailure(
        message: message,
        code: e.status.toString(),
        cause: e,
        stackTrace: st,
      );
    }
  }

  void _validateTaiyoDailyBriefResponse(Map<String, dynamic> response) {
    if (response.isEmpty || _rowMap(response['result']).isEmpty) {
      throw const NetworkFailure(
        message: 'TAIYO returned an unexpected daily brief response.',
      );
    }

    final status = _nonEmptyString(response['status']) ?? 'error';
    const allowedStatuses = <String>{
      'success',
      'needs_more_context',
      'blocked_for_safety',
    };
    if (!allowedStatuses.contains(status)) {
      throw NetworkFailure(
        message: _taiyoDailyBriefStatusMessage(status),
        code: status,
      );
    }
  }

  String _taiyoDailyBriefStatusMessage(String status) {
    switch (status) {
      case 'error':
        return 'TAIYO could not generate today\'s daily brief.';
      default:
        return 'TAIYO returned an unsupported daily brief status.';
    }
  }

  NetworkFailure _failure(PostgrestException e, StackTrace st) {
    if (isMissingAiCoachSchemaError(e)) {
      return NetworkFailure(
        message: kAiCoachBackendUnavailableMessage,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
    return NetworkFailure(
      message: e.message,
      code: e.code,
      cause: e,
      stackTrace: st,
    );
  }

  Future<AiDailyBriefEntity> _buildLegacyDailyBrief(DateTime date) async {
    final normalized = _dateWire(date);
    final activePlan = await _loadLegacyActivePlan();
    final planId = _nonEmptyString(activePlan['id']);
    final planTitle = _nonEmptyString(activePlan['title']);
    final agendaRows = await _loadLegacyAgenda(
      date,
      planId: planId,
      planTitle: planTitle,
    );
    final nutrition = await _loadLegacyNutritionSnapshot(date);
    final firstAgenda = agendaRows.isEmpty
        ? const <String, dynamic>{}
        : agendaRows.first;
    final workoutRows = agendaRows
        .where(
          (row) => _isTrainingTask(
            _nonEmptyString(row['task_type']) ??
                _nonEmptyString(row['taskType']),
          ),
        )
        .toList(growable: false);
    final firstWorkout = workoutRows.isEmpty ? firstAgenda : workoutRows.first;
    final plannedTasks = agendaRows.length;
    final completedTasks = agendaRows.where(_isCompletedAgendaRow).length;
    final workoutTitle = _legacyWorkoutTitle(
      planTitle: planTitle,
      firstWorkout: firstWorkout,
      hasAgenda: plannedTasks > 0,
      hasNutrition: nutrition.hasAnyData,
    );
    final workoutSubtitle = _legacyWorkoutSubtitle(
      agendaRows: agendaRows,
      planTitle: planTitle,
    );
    final dayFocus =
        _nonEmptyString(firstAgenda['day_focus']) ??
        _nonEmptyString(firstWorkout['task_title']) ??
        _nonEmptyString(firstWorkout['title']) ??
        planTitle ??
        '';
    final totalMinutes = workoutRows.fold<int>(
      0,
      (sum, row) => sum + ((row['duration_minutes'] as num?)?.toInt() ?? 0),
    );
    final readinessScore = _legacyReadinessScore(
      plannedTasks: plannedTasks,
      completedTasks: completedTasks,
      nutrition: nutrition,
    );
    final intensityBand = _intensityBandFor(readinessScore);

    return AiDailyBriefEntity(
      id: 'legacy-brief-$normalized',
      briefDate: _dateOnly(date),
      readinessScore: readinessScore,
      intensityBand: intensityBand,
      coachMode: false,
      recommendedWorkout: <String, dynamic>{
        'title': workoutTitle,
        if (workoutSubtitle.isNotEmpty) 'subtitle': workoutSubtitle,
        if (dayFocus.isNotEmpty) 'focus': dayFocus,
        if (totalMinutes > 0) 'duration_minutes': totalMinutes,
        'planned_tasks': plannedTasks,
        'legacy_fallback': true,
      },
      habitFocus: _legacyHabitFocus(
        firstWorkout: firstWorkout,
        plannedTasks: plannedTasks,
        completedTasks: completedTasks,
      ),
      nutritionPriority: _legacyNutritionPriority(nutrition),
      recommendedActions: <String>[
        if (plannedTasks > 0) 'open_plan' else 'open_builder',
        'log_meal',
        'log_hydration',
      ],
      whyShort: _legacyWhyShort(
        planTitle: planTitle,
        firstWorkout: firstWorkout,
        plannedTasks: plannedTasks,
        nutrition: nutrition,
      ),
      signalsUsed: <String>[
        if (planTitle != null) 'active_plan',
        if (plannedTasks > 0) 'plan_agenda',
        if (nutrition.hasAnyData) 'nutrition_progress',
        'legacy_fallback',
      ],
      confidence: 0.42,
      sourceContext: <String, dynamic>{
        'legacy_fallback': true,
        'plan_id': planId,
        'reason': _legacyCoachFallbackReason,
      },
    );
  }

  Future<Map<String, dynamic>> _loadLegacyActivePlan() async {
    try {
      final row = await _client
          .from('workout_plans')
          .select()
          .eq('member_id', _userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return _rowMap(row);
    } on PostgrestException {
      return const <String, dynamic>{};
    }
  }

  Future<List<Map<String, dynamic>>> _loadLegacyAgenda(
    DateTime date, {
    String? planId,
    String? planTitle,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_member_plan_agenda',
        params: <String, dynamic>{
          'input_plan_id': planId,
          'input_date_from': _dateWire(date),
          'input_date_to': _dateWire(date),
        },
      );
      if (rows is! List) {
        return const <Map<String, dynamic>>[];
      }
      return rows.map((dynamic row) => _rowMap(row)).toList(growable: false);
    } on PostgrestException {
      return _loadLegacyAgendaDirect(
        date,
        planId: planId,
        planTitle: planTitle,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadLegacyAgendaDirect(
    DateTime date, {
    String? planId,
    String? planTitle,
  }) async {
    try {
      dynamic query = _client
          .from('workout_plan_tasks')
          .select(
            'id,task_type,title,instructions,duration_minutes,sort_order,day_id,workout_plan_id',
          )
          .eq('member_id', _userId)
          .eq('scheduled_date', _dateWire(date));
      if (planId != null && planId.isNotEmpty) {
        query = query.eq('workout_plan_id', planId);
      }
      final taskRows = await query.order('sort_order', ascending: true);
      if (taskRows is! List || taskRows.isEmpty) {
        return const <Map<String, dynamic>>[];
      }
      final firstRow = _rowMap(taskRows.first);
      final dayInfo = await _loadLegacyDayInfo(firstRow['day_id']?.toString());
      final resolvedPlanTitle =
          planTitle ??
          _nonEmptyString(
            (await _loadLegacyPlanInfo(
              firstRow['workout_plan_id']?.toString(),
            ))['title'],
          );
      return taskRows
          .map((dynamic row) {
            final map = _rowMap(row);
            return <String, dynamic>{
              'task_id': map['id'],
              'task_type': map['task_type'],
              'task_title': map['title'],
              'task_instructions': map['instructions'],
              'duration_minutes': map['duration_minutes'],
              'sort_order': map['sort_order'],
              'day_label': dayInfo['label'],
              'day_focus': dayInfo['focus'],
              'plan_title': resolvedPlanTitle,
            };
          })
          .toList(growable: false);
    } on PostgrestException {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> _loadLegacyDayInfo(String? dayId) async {
    if (dayId == null || dayId.isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      final row = await _client
          .from('workout_plan_days')
          .select('id,label,focus')
          .eq('id', dayId)
          .maybeSingle();
      return _rowMap(row);
    } on PostgrestException {
      return const <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _loadLegacyPlanInfo(String? planId) async {
    if (planId == null || planId.isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      final row = await _client
          .from('workout_plans')
          .select('id,title')
          .eq('id', planId)
          .maybeSingle();
      return _rowMap(row);
    } on PostgrestException {
      return const <String, dynamic>{};
    }
  }

  Future<_LegacyNutritionSnapshot> _loadLegacyNutritionSnapshot(
    DateTime date,
  ) async {
    try {
      final activeMealPlan = await _client
          .from('member_meal_plans')
          .select('id')
          .eq('member_id', _userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      var targetCalories = 0;
      var targetHydrationMl = 0;
      var plannedMeals = 0;
      final activeMealPlanId = _nonEmptyString(_rowMap(activeMealPlan)['id']);
      if (activeMealPlanId != null) {
        final dayRow = await _client
            .from('member_meal_plan_days')
            .select('id,target_calories,hydration_ml')
            .eq('meal_plan_id', activeMealPlanId)
            .eq('member_id', _userId)
            .eq('plan_date', _dateWire(date))
            .maybeSingle();
        final dayMap = _rowMap(dayRow);
        targetCalories = (dayMap['target_calories'] as num?)?.toInt() ?? 0;
        targetHydrationMl = (dayMap['hydration_ml'] as num?)?.toInt() ?? 0;
        final dayId = _nonEmptyString(dayMap['id']);
        if (dayId != null) {
          final plannedRows = await _client
              .from('member_planned_meals')
              .select('id')
              .eq('meal_plan_day_id', dayId)
              .eq('member_id', _userId);
          plannedMeals = (plannedRows as List<dynamic>).length;
        }
      }

      if (targetCalories == 0 && targetHydrationMl == 0) {
        final targetRow = await _client
            .from('nutrition_targets')
            .select('target_calories,hydration_ml')
            .eq('member_id', _userId)
            .eq('status', 'active')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        final targetMap = _rowMap(targetRow);
        targetCalories = (targetMap['target_calories'] as num?)?.toInt() ?? 0;
        targetHydrationMl = (targetMap['hydration_ml'] as num?)?.toInt() ?? 0;
      }

      final mealLogs = await _client
          .from('meal_logs')
          .select('id')
          .eq('member_id', _userId)
          .eq('log_date', _dateWire(date));
      final hydrationRows = await _client
          .from('hydration_logs')
          .select('amount_ml')
          .eq('member_id', _userId)
          .eq('log_date', _dateWire(date));

      final hydrationConsumedMl = (hydrationRows as List<dynamic>).fold<int>(
        0,
        (sum, dynamic row) =>
            sum + ((_rowMap(row)['amount_ml'] as num?)?.toInt() ?? 0),
      );

      return _LegacyNutritionSnapshot(
        targetCalories: targetCalories > 0 ? targetCalories : null,
        targetHydrationMl: targetHydrationMl > 0 ? targetHydrationMl : null,
        plannedMeals: plannedMeals,
        loggedMeals: (mealLogs as List<dynamic>).length,
        hydrationConsumedMl: hydrationConsumedMl,
      );
    } on PostgrestException {
      return const _LegacyNutritionSnapshot();
    }
  }

  String _legacyWorkoutTitle({
    required String? planTitle,
    required Map<String, dynamic> firstWorkout,
    required bool hasAgenda,
    required bool hasNutrition,
  }) {
    final taskTitle =
        _nonEmptyString(firstWorkout['task_title']) ??
        _nonEmptyString(firstWorkout['title']);
    if (taskTitle != null) {
      return taskTitle;
    }
    if (planTitle != null) {
      return planTitle;
    }
    if (hasAgenda) {
      return 'Today\'s plan';
    }
    if (hasNutrition) {
      return 'Recovery and nutrition focus';
    }
    return 'Open your plan builder';
  }

  String _legacyWorkoutSubtitle({
    required List<Map<String, dynamic>> agendaRows,
    required String? planTitle,
  }) {
    if (agendaRows.isEmpty) {
      return planTitle ?? '';
    }
    final first = agendaRows.first;
    final dayLabel = _nonEmptyString(first['day_label']);
    final dayFocus = _nonEmptyString(first['day_focus']);
    if (dayLabel != null && dayFocus != null) {
      return '$dayLabel • $dayFocus';
    }
    if (dayFocus != null) {
      return dayFocus;
    }
    if (dayLabel != null) {
      return dayLabel;
    }
    return planTitle ?? '';
  }

  Map<String, dynamic> _legacyHabitFocus({
    required Map<String, dynamic> firstWorkout,
    required int plannedTasks,
    required int completedTasks,
  }) {
    final firstTaskTitle =
        _nonEmptyString(firstWorkout['task_title']) ??
        _nonEmptyString(firstWorkout['title']);
    if (plannedTasks == 0) {
      return const <String, dynamic>{
        'title': 'Create one anchor',
        'body':
            'Set one non-negotiable action today so TAIYO has fresh behavior to guide from tomorrow.',
      };
    }
    if (completedTasks > 0) {
      return const <String, dynamic>{
        'title': 'Keep momentum clean',
        'body':
            'You already logged progress today. Finish the next planned block before adding anything extra.',
      };
    }
    return <String, dynamic>{
      'title': 'Start with the first block',
      'body': firstTaskTitle == null
          ? 'Reduce friction by starting the first scheduled task before reshuffling the whole day.'
          : 'Start with $firstTaskTitle before making any other decisions. Early execution protects the rest of the day.',
    };
  }

  Map<String, dynamic> _legacyNutritionPriority(
    _LegacyNutritionSnapshot nutrition,
  ) {
    final hydrationTarget = nutrition.targetHydrationMl ?? 0;
    if (hydrationTarget > 0 && nutrition.hydrationProgress < 0.6) {
      return <String, dynamic>{
        'title': 'Close the hydration gap',
        'body':
            '${nutrition.hydrationConsumedMl} ml logged so far. Aim for ${nutrition.targetHydrationMl} ml to keep recovery and training quality stable.',
      };
    }
    if (nutrition.plannedMeals > 0 &&
        nutrition.loggedMeals < nutrition.plannedMeals) {
      final remaining = nutrition.plannedMeals - nutrition.loggedMeals;
      return <String, dynamic>{
        'title': 'Finish planned meals',
        'body':
            'You still have $remaining planned meal${remaining == 1 ? '' : 's'} to close today\'s recovery loop.',
      };
    }
    if (nutrition.targetCalories != null && nutrition.targetCalories! > 0) {
      return <String, dynamic>{
        'title': 'Support recovery with nutrition',
        'body':
            'Keep intake aligned with today\'s target of ${nutrition.targetCalories} kcal and maintain hydration consistency.',
      };
    }
    return const <String, dynamic>{
      'title': 'Log the basics',
      'body':
          'Track meals and water today so tomorrow\'s coaching can stay specific instead of generic.',
    };
  }

  String _legacyWhyShort({
    required String? planTitle,
    required Map<String, dynamic> firstWorkout,
    required int plannedTasks,
    required _LegacyNutritionSnapshot nutrition,
  }) {
    final taskTitle =
        _nonEmptyString(firstWorkout['task_title']) ??
        _nonEmptyString(firstWorkout['title']);
    if (plannedTasks > 0 && nutrition.plannedMeals > 0) {
      return '$_legacyCoachFallbackReason Finish ${taskTitle ?? 'the first planned task'} and close the meal or hydration gaps to keep momentum clean.';
    }
    if (plannedTasks > 0) {
      return '$_legacyCoachFallbackReason Start with ${taskTitle ?? (planTitle ?? 'today\'s first block')} and keep the day finishable.';
    }
    if (nutrition.hasAnyData) {
      return 'Your full AI coach brief is still syncing, so this summary is leaning on today\'s nutrition and recovery data. Log what you complete so the next brief gets sharper.';
    }
    return 'Your full AI coach brief is still syncing. Open the plan builder or nutrition setup so TAIYO has current data to coach from.';
  }

  int _legacyReadinessScore({
    required int plannedTasks,
    required int completedTasks,
    required _LegacyNutritionSnapshot nutrition,
  }) {
    var score = 48;
    if (plannedTasks > 0) {
      score += 8;
    }
    if (completedTasks > 0) {
      score += 6;
    }
    if (nutrition.plannedMeals > 0) {
      score += 4;
    }
    if (nutrition.loggedMeals > 0) {
      score += 4;
    }
    final hydrationProgress = nutrition.hydrationProgress;
    if (hydrationProgress >= 1) {
      score += 8;
    } else if (hydrationProgress >= 0.6) {
      score += 4;
    } else if (hydrationProgress > 0) {
      score -= 2;
    }
    return score.clamp(38, 78).toInt();
  }

  String _intensityBandFor(int score) {
    if (score >= 68) {
      return 'green';
    }
    if (score >= 54) {
      return 'yellow';
    }
    return 'red';
  }

  bool _isCompletedAgendaRow(Map<String, dynamic> row) {
    final status =
        _nonEmptyString(row['completion_status']) ??
        _nonEmptyString(row['effective_status']) ??
        '';
    return status.toLowerCase() == 'completed';
  }

  bool _isTrainingTask(String? taskType) {
    switch (taskType?.trim().toLowerCase()) {
      case 'workout':
      case 'cardio':
      case 'mobility':
      case 'recovery':
      case 'steps':
        return true;
      default:
        return false;
    }
  }

  String? _nonEmptyString(dynamic value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Map<String, dynamic> _rowMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic rowValue) => MapEntry(key.toString(), rowValue),
      );
    }
    return <String, dynamic>{};
  }

  String _dateWire(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    return normalized.toIso8601String().split('T').first;
  }

  DateTime _startOfWeek(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
