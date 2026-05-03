import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../../ai_chat/domain/entities/planner_turn_result.dart';
import '../../../coach/domain/entities/workout_plan_entity.dart';
import '../../domain/entities/planner_entities.dart';
import '../../domain/repositories/planner_repository.dart';

const String kTaiyoWorkoutPlannerFunctionName = 'taiyo-workout-planner';

class PlannerRepositoryImpl implements PlannerRepository {
  PlannerRepositoryImpl(this._client);

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthFailure(message: 'No authenticated member found.');
    }
    return userId;
  }

  @override
  Future<PlannerDraftEntity?> getLatestDraft(String sessionId) async {
    try {
      final row = await _client
          .from('ai_plan_drafts')
          .select()
          .eq('session_id', sessionId)
          .eq('user_id', _userId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return PlannerDraftEntity.fromMap(row);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<PlannerDraftEntity?> getDraft(String draftId) async {
    try {
      final row = await _client
          .from('ai_plan_drafts')
          .select()
          .eq('id', draftId)
          .eq('user_id', _userId)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return PlannerDraftEntity.fromMap(row);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<PlannerTurnResult> requestTaiyoWorkoutPlanDraft({
    required Map<String, dynamic> plannerAnswers,
    String? sessionId,
    String? draftId,
    String requestType = 'workout_plan_draft',
  }) async {
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthFailure(message: 'No authenticated member found.');
    }

    try {
      final response = await _client.functions.invoke(
        kTaiyoWorkoutPlannerFunctionName,
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
        body: <String, dynamic>{
          'request_type': requestType,
          'planner_answers': plannerAnswers,
          if ((sessionId ?? '').trim().isNotEmpty) 'session_id': sessionId,
          if ((draftId ?? '').trim().isNotEmpty) 'draft_id': draftId,
        },
      );
      return plannerTurnResultFromTaiyoWorkoutPlannerResponse(response.data);
    } on FunctionException catch (e, st) {
      if (e.status == 401) {
        throw AuthFailure(
          message: 'Please sign in again to use TAIYO workout planner.',
          code: e.status.toString(),
          cause: e,
          stackTrace: st,
        );
      }
      if (e.status == 403) {
        throw AuthFailure(
          message:
              'TAIYO workout planner is available for member accounts only.',
          code: e.status.toString(),
          cause: e,
          stackTrace: st,
        );
      }
      throw NetworkFailure(
        message: _functionErrorMessage(
          e,
          'TAIYO could not generate this workout plan right now.',
        ),
        code: e.status.toString(),
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is AppFailure) {
        rethrow;
      }
      throw NetworkFailure(
        message: 'TAIYO could not generate this workout plan right now.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<PlanActivationResultEntity> activateDraft({
    required String draftId,
    required DateTime startDate,
    String? reminderTime,
  }) async {
    try {
      final rows = await _client.rpc(
        'activate_ai_workout_plan',
        params: <String, dynamic>{
          'input_draft_id': draftId,
          'input_start_date': _dateOnly(startDate),
          'input_default_reminder_time': reminderTime,
        },
      );
      final map = _firstRow(rows);
      return PlanActivationResultEntity(
        planId: map['plan_id'] as String? ?? '',
        created: map['created'] as bool? ?? true,
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<List<PlanTaskEntity>> listTodayAgenda() {
    final today = DateTime.now();
    return listPlanAgenda(dateFrom: today, dateTo: today);
  }

  @override
  Future<List<PlanTaskEntity>> listPlanAgenda({
    String? planId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_member_plan_agenda',
        params: <String, dynamic>{
          'input_plan_id': planId,
          'input_date_from': _dateOnly(dateFrom ?? DateTime.now()),
          'input_date_to': _dateOnly(
            dateTo ??
                (dateFrom ?? DateTime.now()).add(const Duration(days: 14)),
          ),
        },
      );
      if (rows is! List) {
        assert(() {
          debugPrint(
            '[planner] listPlanAgenda returned non-list for planId=$planId',
          );
          return true;
        }());
        return const <PlanTaskEntity>[];
      }
      assert(() {
        debugPrint(
          '[planner] listPlanAgenda planId=$planId count=${rows.length} from=${_dateOnly(dateFrom ?? DateTime.now())} to=${_dateOnly(dateTo ?? (dateFrom ?? DateTime.now()).add(const Duration(days: 14)))}',
        );
        return true;
      }());
      return rows
          .map((dynamic row) => PlanTaskEntity.fromMap(_rowMap(row)))
          .toList(growable: false);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<PlanDetailEntity?> getPlanDetail({String? planId}) async {
    try {
      final row = planId == null || planId.isEmpty
          ? await _client
                .from('workout_plans')
                .select()
                .eq('member_id', _userId)
                .eq('source', 'ai')
                .eq('status', 'active')
                .order('assigned_at', ascending: false)
                .limit(1)
                .maybeSingle()
          : await _client
                .from('workout_plans')
                .select()
                .eq('id', planId)
                .eq('member_id', _userId)
                .maybeSingle();
      if (row == null) {
        assert(() {
          debugPrint(
            '[planner] getPlanDetail no active plan for planId=$planId',
          );
          return true;
        }());
        return null;
      }

      final plan = _mapWorkoutPlan(row);
      final agenda = await listPlanAgenda(
        planId: plan.id,
        dateFrom: plan.startDate ?? DateTime.now(),
        dateTo:
            plan.endDate ??
            (plan.startDate ?? DateTime.now()).add(const Duration(days: 84)),
      );
      final generatedPlan = plan.planJson.isEmpty
          ? null
          : GeneratedPlanEntity.fromMap(plan.planJson);
      assert(() {
        debugPrint(
          '[planner] getPlanDetail loaded plan=${plan.id} title=${plan.title} status=${plan.status} agenda=${agenda.length} generated=${generatedPlan != null}',
        );
        return true;
      }());
      return PlanDetailEntity(
        planId: plan.id,
        planTitle: plan.title,
        planStatus: plan.status,
        planSource: plan.source,
        startDate: plan.startDate,
        endDate: plan.endDate,
        defaultReminderTime: plan.defaultReminderTime,
        generatedPlan: generatedPlan,
        days: _groupDays(agenda),
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<PlanTaskEntity> updateTaskStatus({
    required String taskId,
    required TaskCompletionStatus status,
    int? completionPercent,
    String? note,
    int? durationMinutes,
  }) async {
    try {
      final taskRow = await _client
          .from('workout_plan_tasks')
          .select('workout_plan_id,scheduled_date')
          .eq('id', taskId)
          .eq('member_id', _userId)
          .single();

      await _client.rpc(
        'upsert_workout_task_log',
        params: <String, dynamic>{
          'input_task_id': taskId,
          'input_completion_status': status.wireValue,
          'input_completion_percent': completionPercent,
          'input_note': note,
          'input_duration_minutes': durationMinutes,
          'input_logged_at': DateTime.now().toUtc().toIso8601String(),
        },
      );

      final agenda = await listPlanAgenda(
        planId: taskRow['workout_plan_id'] as String?,
        dateFrom: DateTime.parse(taskRow['scheduled_date'] as String),
        dateTo: DateTime.parse(taskRow['scheduled_date'] as String),
      );
      return agenda.firstWhere((PlanTaskEntity task) => task.taskId == taskId);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<int> updateReminderTime({
    required String planId,
    required String reminderTime,
    required String timeZone,
  }) async {
    try {
      final updatedCount = await _client.rpc(
        'update_ai_plan_reminder_time',
        params: <String, dynamic>{
          'input_plan_id': planId,
          'input_reminder_time': reminderTime,
          'input_time_zone': timeZone,
        },
      );
      if (updatedCount is int) {
        return updatedCount;
      }
      if (updatedCount is num) {
        return updatedCount.toInt();
      }
      return 0;
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<int> syncReminders({required String timeZone, int limit = 50}) async {
    try {
      final synced = await _client.rpc(
        'sync_member_task_notifications',
        params: <String, dynamic>{
          'input_time_zone': timeZone,
          'input_limit': limit,
        },
      );
      if (synced is int) {
        return synced;
      }
      if (synced is num) {
        return synced.toInt();
      }
      return 0;
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  WorkoutPlanEntity _mapWorkoutPlan(Map<String, dynamic> row) {
    return WorkoutPlanEntity(
      id: row['id'] as String,
      memberId: row['member_id'] as String,
      coachId: row['coach_id'] as String?,
      source: row['source'] as String? ?? 'ai',
      title: row['title'] as String? ?? '',
      status: row['status'] as String? ?? 'active',
      planJson: _rowMap(row['plan_json']),
      startDate: _parseDate(row['start_date']),
      endDate: _parseDate(row['end_date']),
      assignedAt: _parseDate(row['assigned_at']),
      updatedAt: _parseDate(row['updated_at']),
      completedAt: _parseDate(row['completed_at']),
      conversationSessionId: row['conversation_session_id'] as String?,
      generatedFromDraftId: row['generated_from_draft_id'] as String?,
      planVersion: (row['plan_version'] as num?)?.toInt() ?? 1,
      defaultReminderTime: row['default_reminder_time'] as String?,
    );
  }

  List<PlanDayEntity> _groupDays(List<PlanTaskEntity> agenda) {
    final buckets = <String, List<PlanTaskEntity>>{};
    for (final task in agenda) {
      buckets.putIfAbsent(task.dayId, () => <PlanTaskEntity>[]).add(task);
    }
    final days =
        buckets.entries
            .map((entry) {
              final tasks = entry.value
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
              final first = tasks.first;
              return PlanDayEntity(
                id: first.dayId,
                weekNumber: first.weekNumber,
                dayNumber: first.dayNumber,
                dayIndex: first.dayIndex,
                scheduledDate: first.scheduledDate,
                label: first.dayLabel,
                focus: first.dayFocus,
                tasks: List<PlanTaskEntity>.from(tasks),
              );
            })
            .toList(growable: false)
          ..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));
    return days;
  }

  Map<String, dynamic> _firstRow(dynamic response) {
    if (response is List && response.isNotEmpty) {
      return _rowMap(response.first);
    }
    return _rowMap(response);
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
    return const <String, dynamic>{};
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }

  String _dateOnly(DateTime value) {
    final utc = DateTime.utc(value.year, value.month, value.day);
    return utc.toIso8601String().split('T').first;
  }
}

PlannerTurnResult plannerTurnResultFromTaiyoWorkoutPlannerResponse(
  dynamic value,
) {
  final map = _asMap(value);
  if (map.isEmpty) {
    throw const NetworkFailure(
      message: 'TAIYO returned an empty workout planner response.',
    );
  }
  final status = map['status']?.toString() ?? 'error';
  final result = _asMap(map['result']);
  final metadata = _asMap(map['metadata']);
  final dataQuality = _asMap(map['data_quality']);
  final requestType = map['request_type']?.toString();
  final planMap = _asMap(metadata['plan_json']);
  final extractedProfile = _asMap(metadata['extracted_profile']);
  final draftId =
      metadata['draft_id']?.toString() ?? map['draft_id']?.toString();

  final turnStatus = switch (status) {
    'success' => requestType == 'plan_review' ? 'plan_updated' : 'plan_ready',
    'blocked_for_safety' => 'unsafe_request',
    'needs_more_context' => 'needs_more_info',
    _ => 'error',
  };

  final message = _firstNonEmpty(<String?>[
    result['summary']?.toString(),
    (result['safety_notes'] is List &&
            (result['safety_notes'] as List).isNotEmpty)
        ? (result['safety_notes'] as List).join(' ')
        : null,
    status == 'blocked_for_safety'
        ? 'TAIYO found safety flags that need attention before planning.'
        : null,
    status == 'needs_more_context'
        ? 'TAIYO needs a little more planner detail before drafting.'
        : null,
  ]);

  final missingFields = dataQuality['missing_fields'] is List
      ? (dataQuality['missing_fields'] as List)
            .map((dynamic item) => item.toString())
            .toList(growable: false)
      : const <String>[];

  return PlannerTurnResult(
    assistantMessage: message,
    status: turnStatus,
    draftId: draftId,
    missingFields: missingFields,
    extractedProfile: PlannerProfileSnapshotEntity.fromMap(extractedProfile),
    plan: planMap.isEmpty ? null : GeneratedPlanEntity.fromMap(planMap),
    conversationMode: requestType,
    personalizationUsed: const <String>['TAIYO workout planner'],
  );
}

String _functionErrorMessage(FunctionException error, String fallback) {
  final details = _asMap(error.details);
  return details['message']?.toString() ??
      details['error']?.toString() ??
      error.details?.toString() ??
      fallback;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic rowValue) => MapEntry(key.toString(), rowValue),
    );
  }
  return const <String, dynamic>{};
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return 'TAIYO prepared your workout plan draft.';
}
