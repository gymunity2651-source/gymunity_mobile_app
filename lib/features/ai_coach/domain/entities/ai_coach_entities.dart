class AiReadinessLogEntity {
  const AiReadinessLogEntity({
    required this.id,
    required this.logDate,
    this.energyLevel,
    this.sorenessLevel,
    this.stressLevel,
    this.availableMinutes,
    this.locationMode,
    this.equipmentOverride = const <String>[],
    required this.readinessScore,
    required this.intensityBand,
    this.note,
    required this.source,
    this.updatedAt,
  });

  final String id;
  final DateTime logDate;
  final int? energyLevel;
  final int? sorenessLevel;
  final int? stressLevel;
  final int? availableMinutes;
  final String? locationMode;
  final List<String> equipmentOverride;
  final int readinessScore;
  final String intensityBand;
  final String? note;
  final String source;
  final DateTime? updatedAt;

  factory AiReadinessLogEntity.fromMap(Map<String, dynamic> map) {
    return AiReadinessLogEntity(
      id: map['id'] as String? ?? '',
      logDate: _parseDateTime(map['log_date']) ?? _dateOnly(DateTime.now()),
      energyLevel: (map['energy_level'] as num?)?.toInt(),
      sorenessLevel: (map['soreness_level'] as num?)?.toInt(),
      stressLevel: (map['stress_level'] as num?)?.toInt(),
      availableMinutes: (map['available_minutes'] as num?)?.toInt(),
      locationMode: map['location_mode'] as String?,
      equipmentOverride: _stringList(map['equipment_override']),
      readinessScore: (map['readiness_score'] as num?)?.toInt() ?? 50,
      intensityBand: map['intensity_band'] as String? ?? 'yellow',
      note: map['note'] as String?,
      source: map['source'] as String? ?? 'member',
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }
}

class AiDailyBriefEntity {
  const AiDailyBriefEntity({
    required this.id,
    required this.briefDate,
    this.planId,
    this.dayId,
    this.primaryTaskId,
    required this.readinessScore,
    required this.intensityBand,
    required this.coachMode,
    this.recommendedWorkout = const <String, dynamic>{},
    this.habitFocus = const <String, dynamic>{},
    this.nutritionPriority = const <String, dynamic>{},
    this.recap = const <String, dynamic>{},
    this.recommendedActions = const <String>[],
    required this.whyShort,
    this.signalsUsed = const <String>[],
    required this.confidence,
    this.sourceContext = const <String, dynamic>{},
  });

  final String id;
  final DateTime briefDate;
  final String? planId;
  final String? dayId;
  final String? primaryTaskId;
  final int readinessScore;
  final String intensityBand;
  final bool coachMode;
  final Map<String, dynamic> recommendedWorkout;
  final Map<String, dynamic> habitFocus;
  final Map<String, dynamic> nutritionPriority;
  final Map<String, dynamic> recap;
  final List<String> recommendedActions;
  final String whyShort;
  final List<String> signalsUsed;
  final double confidence;
  final Map<String, dynamic> sourceContext;

  factory AiDailyBriefEntity.fromMap(Map<String, dynamic> map) {
    return AiDailyBriefEntity(
      id: map['id'] as String? ?? '',
      briefDate: _parseDateTime(map['brief_date']) ?? _dateOnly(DateTime.now()),
      planId: map['plan_id'] as String?,
      dayId: map['day_id'] as String?,
      primaryTaskId: map['primary_task_id'] as String?,
      readinessScore: (map['readiness_score'] as num?)?.toInt() ?? 50,
      intensityBand: map['intensity_band'] as String? ?? 'yellow',
      coachMode: map['coach_mode'] as bool? ?? false,
      recommendedWorkout: _map(map['recommended_workout_json']),
      habitFocus: _map(map['habit_focus_json']),
      nutritionPriority: _map(map['nutrition_priority_json']),
      recap: _map(map['recap_json']),
      recommendedActions: _stringList(map['recommended_actions_json']),
      whyShort: map['why_short'] as String? ?? '',
      signalsUsed: _stringList(map['signals_used']),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.85,
      sourceContext: _map(map['source_context_json']),
    );
  }

  factory AiDailyBriefEntity.fromTaiyoDailyBriefResponse(
    Map<String, dynamic> map, {
    DateTime? briefDate,
  }) {
    final result = _map(map['result']);
    final dataQuality = _map(map['data_quality']);
    final metadata = _map(map['metadata']);
    final normalizedDate = _dateOnly(briefDate ?? DateTime.now());
    final status = _stringValue(map['status']) ?? 'error';
    final riskLevel = _stringValue(result['risk_level']) ?? 'medium';
    final workoutFocus = _stringValue(result['workout_focus']) ?? '';
    final trainingDecision =
        _stringValue(result['training_decision']) ?? 'Review today\'s plan';
    final nutritionFocus = _stringValue(result['nutrition_focus']) ?? '';
    final motivationMessage =
        _stringValue(result['motivation_message']) ??
        'Stay consistent with the next useful action.';
    final safetyNotes = _stringList(result['safety_notes']);
    final missingFields = _stringList(dataQuality['missing_fields']);

    return AiDailyBriefEntity(
      id: 'taiyo-daily-brief-${_dateWire(normalizedDate)}',
      briefDate: normalizedDate,
      readinessScore: _readinessScoreForRisk(riskLevel),
      intensityBand: _intensityBandForRisk(riskLevel),
      coachMode: status == 'blocked_for_safety',
      recommendedWorkout: <String, dynamic>{
        'title': trainingDecision,
        if (workoutFocus.isNotEmpty) 'focus': workoutFocus,
        'risk_level': riskLevel,
      },
      habitFocus: <String, dynamic>{
        'title': 'TAIYO focus',
        'body': motivationMessage,
      },
      nutritionPriority: <String, dynamic>{
        'title': 'Nutrition focus',
        if (nutritionFocus.isNotEmpty) 'body': nutritionFocus,
      },
      recap: <String, dynamic>{
        if (safetyNotes.isNotEmpty) 'safety_notes': safetyNotes,
      },
      recommendedActions: <String>[
        if (workoutFocus.isNotEmpty) 'review_workout',
        if (nutritionFocus.isNotEmpty) 'review_nutrition',
        if (safetyNotes.isNotEmpty) 'review_safety_notes',
      ],
      whyShort: motivationMessage,
      signalsUsed: <String>[
        'taiyo_daily_brief',
        if (missingFields.isNotEmpty) 'missing_context',
      ],
      confidence: _confidenceFromDataQuality(dataQuality['confidence']),
      sourceContext: <String, dynamic>{
        'request_type': map['request_type'],
        'status': status,
        'data_quality': dataQuality,
        'metadata': metadata,
        'raw_result_keys': result.keys.toList(growable: false),
      },
    );
  }

  String get workoutTitle =>
      _stringValue(recommendedWorkout['title']) ??
      _stringValue(recommendedWorkout['label']) ??
      'Today\'s plan';

  int? get workoutDurationMinutes =>
      (recommendedWorkout['duration_minutes'] as num?)?.toInt();

  String get workoutSubtitle =>
      _stringValue(recommendedWorkout['focus']) ??
      _stringValue(recommendedWorkout['subtitle']) ??
      '';

  String get habitTitle =>
      _stringValue(habitFocus['title']) ?? 'Stay consistent today';

  String get habitBody =>
      _stringValue(habitFocus['body']) ??
      _stringValue(habitFocus['description']) ??
      '';

  String get nutritionTitle =>
      _stringValue(nutritionPriority['title']) ??
      'Support recovery with nutrition';

  String get nutritionBody =>
      _stringValue(nutritionPriority['body']) ??
      _stringValue(nutritionPriority['description']) ??
      '';

  List<String> get recapCompleted => _stringList(recap['completed']);

  List<String> get recapMissed => _stringList(recap['missed']);

  String get recapTomorrowFocus =>
      _stringValue(recap['tomorrow_focus']) ??
      _stringValue(recap['next_focus']) ??
      '';
}

class AiPlanAdaptationEntity {
  const AiPlanAdaptationEntity({
    required this.id,
    required this.adaptationType,
    required this.status,
    required this.whyShort,
    this.signalsUsed = const <String>[],
    required this.confidence,
    this.before = const <String, dynamic>{},
    this.after = const <String, dynamic>{},
    this.createdAt,
  });

  final String id;
  final String adaptationType;
  final String status;
  final String whyShort;
  final List<String> signalsUsed;
  final double confidence;
  final Map<String, dynamic> before;
  final Map<String, dynamic> after;
  final DateTime? createdAt;

  factory AiPlanAdaptationEntity.fromMap(Map<String, dynamic> map) {
    return AiPlanAdaptationEntity(
      id: map['id'] as String? ?? '',
      adaptationType: map['adaptation_type'] as String? ?? '',
      status: map['status'] as String? ?? 'applied',
      whyShort: map['why_short'] as String? ?? '',
      signalsUsed: _stringList(map['signals_used']),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.8,
      before: _map(map['before_json']),
      after: _map(map['after_json']),
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  factory AiPlanAdaptationEntity.fromRpc(Map<String, dynamic> map) {
    return AiPlanAdaptationEntity(
      id: map['adaptation_id'] as String? ?? '',
      adaptationType: map['adjustment_type'] as String? ?? '',
      status: map['status'] as String? ?? 'applied',
      whyShort: map['why_short'] as String? ?? '',
      signalsUsed: _stringList(map['signals_used']),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.8,
      before: _map(map['before']),
      after: _map(map['after']),
    );
  }
}

class AiNudgeEntity {
  const AiNudgeEntity({
    required this.id,
    required this.nudgeType,
    required this.title,
    required this.body,
    required this.actionType,
    this.actionPayload = const <String, dynamic>{},
    required this.whyShort,
    this.signalsUsed = const <String>[],
    required this.confidence,
    required this.status,
    this.availableAt,
  });

  final String id;
  final String nudgeType;
  final String title;
  final String body;
  final String actionType;
  final Map<String, dynamic> actionPayload;
  final String whyShort;
  final List<String> signalsUsed;
  final double confidence;
  final String status;
  final DateTime? availableAt;

  factory AiNudgeEntity.fromMap(Map<String, dynamic> map) {
    return AiNudgeEntity(
      id: map['id'] as String? ?? '',
      nudgeType: map['nudge_type'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      actionType: map['action_type'] as String? ?? 'open_ai',
      actionPayload: _map(map['action_payload_json']),
      whyShort: map['why_short'] as String? ?? '',
      signalsUsed: _stringList(map['signals_used']),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.8,
      status: map['status'] as String? ?? 'pending',
      availableAt: _parseDateTime(map['available_at']),
    );
  }
}

class ActiveWorkoutTaskEntity {
  const ActiveWorkoutTaskEntity({
    required this.taskId,
    required this.title,
    required this.taskType,
    required this.instructions,
    this.sets,
    this.reps,
    this.durationMinutes,
    this.restSeconds,
    this.blockLabel,
    this.sortOrder = 0,
  });

  final String taskId;
  final String title;
  final String taskType;
  final String instructions;
  final int? sets;
  final int? reps;
  final int? durationMinutes;
  final int? restSeconds;
  final String? blockLabel;
  final int sortOrder;

  factory ActiveWorkoutTaskEntity.fromMap(Map<String, dynamic> map) {
    return ActiveWorkoutTaskEntity(
      taskId: map['task_id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      taskType: map['task_type'] as String? ?? 'workout',
      instructions: map['instructions'] as String? ?? '',
      sets: (map['sets'] as num?)?.toInt(),
      reps: (map['reps'] as num?)?.toInt(),
      durationMinutes: (map['duration_minutes'] as num?)?.toInt(),
      restSeconds: (map['rest_seconds'] as num?)?.toInt(),
      blockLabel: map['block_label'] as String?,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ActiveWorkoutSessionEntity {
  const ActiveWorkoutSessionEntity({
    required this.id,
    this.planId,
    this.dayId,
    this.sourceTaskId,
    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.plannedMinutes,
    this.activeMinutes,
    this.readinessScore,
    this.difficultyScore,
    this.paceDeltaPercent,
    required this.wasShortened,
    required this.wasSwapped,
    this.completionRate,
    required this.whyShort,
    this.signalsUsed = const <String>[],
    required this.confidence,
    this.summary = const <String, dynamic>{},
  });

  final String id;
  final String? planId;
  final String? dayId;
  final String? sourceTaskId;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int plannedMinutes;
  final int? activeMinutes;
  final int? readinessScore;
  final int? difficultyScore;
  final double? paceDeltaPercent;
  final bool wasShortened;
  final bool wasSwapped;
  final double? completionRate;
  final String whyShort;
  final List<String> signalsUsed;
  final double confidence;
  final Map<String, dynamic> summary;

  factory ActiveWorkoutSessionEntity.fromMap(Map<String, dynamic> map) {
    return ActiveWorkoutSessionEntity(
      id: map['id'] as String? ?? '',
      planId: map['plan_id'] as String?,
      dayId: map['day_id'] as String?,
      sourceTaskId: map['source_task_id'] as String?,
      status: map['status'] as String? ?? 'active',
      startedAt: _parseDateTime(map['started_at']) ?? DateTime.now(),
      endedAt: _parseDateTime(map['ended_at']),
      plannedMinutes: (map['planned_minutes'] as num?)?.toInt() ?? 0,
      activeMinutes: (map['active_minutes'] as num?)?.toInt(),
      readinessScore: (map['readiness_score'] as num?)?.toInt(),
      difficultyScore: (map['difficulty_score'] as num?)?.toInt(),
      paceDeltaPercent: (map['pace_delta_percent'] as num?)?.toDouble(),
      wasShortened: map['was_shortened'] as bool? ?? false,
      wasSwapped: map['was_swapped'] as bool? ?? false,
      completionRate: (map['completion_rate'] as num?)?.toDouble(),
      whyShort: map['why_short'] as String? ?? '',
      signalsUsed: _stringList(map['signals_used']),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.85,
      summary: _map(map['summary_json']),
    );
  }

  List<ActiveWorkoutTaskEntity> get tasks =>
      _listOfMaps(
          summary['tasks'],
        ).map(ActiveWorkoutTaskEntity.fromMap).toList(growable: false)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<String> get completedTaskIds =>
      _stringList(summary['completed_task_ids']);

  List<String> get partialTaskIds => _stringList(summary['partial_task_ids']);

  List<String> get skippedTaskIds => _stringList(summary['skipped_task_ids']);

  String get planTitle => summary['plan_title'] as String? ?? 'TAIYO Session';

  String get dayLabel => summary['day_label'] as String? ?? 'Today';

  String get dayFocus => summary['day_focus'] as String? ?? '';
}

class AiWeeklySummaryEntity {
  const AiWeeklySummaryEntity({
    required this.id,
    required this.weekStart,
    required this.adherenceScore,
    required this.summaryText,
    this.wins = const <String>[],
    this.blockers = const <String>[],
    required this.nextFocus,
    this.workoutSummary = const <String, dynamic>{},
    this.nutritionSummary = const <String, dynamic>{},
    required this.whyShort,
    this.signalsUsed = const <String>[],
    required this.confidence,
    required this.shareStatus,
  });

  final String id;
  final DateTime weekStart;
  final int adherenceScore;
  final String summaryText;
  final List<String> wins;
  final List<String> blockers;
  final String nextFocus;
  final Map<String, dynamic> workoutSummary;
  final Map<String, dynamic> nutritionSummary;
  final String whyShort;
  final List<String> signalsUsed;
  final double confidence;
  final String shareStatus;

  factory AiWeeklySummaryEntity.fromMap(Map<String, dynamic> map) {
    return AiWeeklySummaryEntity(
      id: map['id'] as String? ?? '',
      weekStart: _parseDateTime(map['week_start']) ?? _dateOnly(DateTime.now()),
      adherenceScore: (map['adherence_score'] as num?)?.toInt() ?? 0,
      summaryText: map['summary_text'] as String? ?? '',
      wins: _stringList(map['wins']),
      blockers: _stringList(map['blockers']),
      nextFocus: map['next_focus'] as String? ?? '',
      workoutSummary: _map(map['workout_summary_json']),
      nutritionSummary: _map(map['nutrition_summary_json']),
      whyShort: map['why_short'] as String? ?? '',
      signalsUsed: _stringList(map['signals_used']),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.85,
      shareStatus: map['share_status'] as String? ?? 'private',
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic innerValue) => MapEntry(key.toString(), innerValue),
    );
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMaps(dynamic value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value.map((dynamic item) => _map(item)).toList(growable: false);
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((dynamic item) => item.toString().trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

String? _stringValue(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  return null;
}

DateTime? _parseDateTime(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _dateWire(DateTime value) {
  return _dateOnly(value).toIso8601String().split('T').first;
}

String _intensityBandForRisk(String riskLevel) {
  switch (riskLevel.trim().toLowerCase()) {
    case 'low':
      return 'green';
    case 'high':
      return 'red';
    case 'medium':
    default:
      return 'yellow';
  }
}

int _readinessScoreForRisk(String riskLevel) {
  switch (riskLevel.trim().toLowerCase()) {
    case 'low':
      return 72;
    case 'high':
      return 35;
    case 'medium':
    default:
      return 55;
  }
}

double _confidenceFromDataQuality(dynamic value) {
  final confidence = _stringValue(value)?.toLowerCase();
  switch (confidence) {
    case 'high':
      return 0.9;
    case 'medium':
      return 0.7;
    case 'low':
      return 0.45;
    default:
      return 0.6;
  }
}
