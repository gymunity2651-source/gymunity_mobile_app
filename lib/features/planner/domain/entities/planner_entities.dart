class PlannerProfileSnapshotEntity {
  const PlannerProfileSnapshotEntity({
    this.goal,
    this.experienceLevel,
    this.daysPerWeek,
    this.sessionMinutes,
    this.equipment = const <String>[],
    this.limitations = const <String>[],
    this.preferredLanguage,
    this.measurementUnit,
  });

  final String? goal;
  final String? experienceLevel;
  final int? daysPerWeek;
  final int? sessionMinutes;
  final List<String> equipment;
  final List<String> limitations;
  final String? preferredLanguage;
  final String? measurementUnit;

  factory PlannerProfileSnapshotEntity.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const PlannerProfileSnapshotEntity();
    }
    return PlannerProfileSnapshotEntity(
      goal: map['goal'] as String?,
      experienceLevel: map['experience_level'] as String?,
      daysPerWeek: (map['days_per_week'] as num?)?.toInt(),
      sessionMinutes: (map['session_minutes'] as num?)?.toInt(),
      equipment: _stringList(map['equipment']),
      limitations: _stringList(map['limitations']),
      preferredLanguage: map['preferred_language'] as String?,
      measurementUnit: map['measurement_unit'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'goal': goal,
      'experience_level': experienceLevel,
      'days_per_week': daysPerWeek,
      'session_minutes': sessionMinutes,
      'equipment': equipment,
      'limitations': limitations,
      'preferred_language': preferredLanguage,
      'measurement_unit': measurementUnit,
    };
  }
}

class GeneratedPlanTaskEntity {
  const GeneratedPlanTaskEntity({
    required this.type,
    required this.title,
    required this.instructions,
    this.sets,
    this.reps,
    this.durationMinutes,
    this.targetValue,
    this.targetUnit,
    this.scheduledTime,
    this.reminderTime,
    this.isRequired = true,
  });

  final String type;
  final String title;
  final String instructions;
  final int? sets;
  final int? reps;
  final int? durationMinutes;
  final double? targetValue;
  final String? targetUnit;
  final String? scheduledTime;
  final String? reminderTime;
  final bool isRequired;

  factory GeneratedPlanTaskEntity.fromMap(Map<String, dynamic> map) {
    return GeneratedPlanTaskEntity(
      type: map['type'] as String? ?? 'workout',
      title: map['title'] as String? ?? '',
      instructions: map['instructions'] as String? ?? '',
      sets: (map['sets'] as num?)?.toInt(),
      reps: (map['reps'] as num?)?.toInt(),
      durationMinutes: (map['duration_minutes'] as num?)?.toInt(),
      targetValue: (map['target_value'] as num?)?.toDouble(),
      targetUnit: map['target_unit'] as String?,
      scheduledTime: map['scheduled_time'] as String?,
      reminderTime: map['reminder_time'] as String?,
      isRequired: map['is_required'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type,
      'title': title,
      'instructions': instructions,
      'sets': sets,
      'reps': reps,
      'duration_minutes': durationMinutes,
      'target_value': targetValue,
      'target_unit': targetUnit,
      'scheduled_time': scheduledTime,
      'reminder_time': reminderTime,
      'is_required': isRequired,
    };
  }
}

class GeneratedPlanDayEntity {
  const GeneratedPlanDayEntity({
    required this.weekNumber,
    required this.dayNumber,
    required this.label,
    required this.focus,
    this.tasks = const <GeneratedPlanTaskEntity>[],
  });

  final int weekNumber;
  final int dayNumber;
  final String label;
  final String focus;
  final List<GeneratedPlanTaskEntity> tasks;

  factory GeneratedPlanDayEntity.fromMap(
    Map<String, dynamic> map, {
    required int fallbackWeekNumber,
  }) {
    return GeneratedPlanDayEntity(
      weekNumber: (map['week_number'] as num?)?.toInt() ?? fallbackWeekNumber,
      dayNumber: (map['day_number'] as num?)?.toInt() ?? 1,
      label: map['label'] as String? ?? 'Day',
      focus: map['focus'] as String? ?? '',
      tasks: _mapList(
        map['tasks'],
        (item) => GeneratedPlanTaskEntity.fromMap(item),
      ),
    );
  }
}

class GeneratedPlanWeekEntity {
  const GeneratedPlanWeekEntity({
    required this.weekNumber,
    this.days = const <GeneratedPlanDayEntity>[],
  });

  final int weekNumber;
  final List<GeneratedPlanDayEntity> days;

  factory GeneratedPlanWeekEntity.fromMap(Map<String, dynamic> map) {
    final weekNumber = (map['week_number'] as num?)?.toInt() ?? 1;
    return GeneratedPlanWeekEntity(
      weekNumber: weekNumber,
      days: _mapList(
        map['days'],
        (item) => GeneratedPlanDayEntity.fromMap(
          item,
          fallbackWeekNumber: weekNumber,
        ),
      ),
    );
  }
}

class GeneratedPlanEntity {
  const GeneratedPlanEntity({
    required this.title,
    required this.summary,
    required this.durationWeeks,
    required this.level,
    this.startDateSuggestion,
    this.safetyNotes = const <String>[],
    this.restGuidance,
    this.nutritionGuidance,
    this.hydrationGuidance,
    this.sleepGuidance,
    this.stepTarget,
    this.weeklyStructure = const <GeneratedPlanWeekEntity>[],
  });

  final String title;
  final String summary;
  final int durationWeeks;
  final String level;
  final DateTime? startDateSuggestion;
  final List<String> safetyNotes;
  final String? restGuidance;
  final String? nutritionGuidance;
  final String? hydrationGuidance;
  final String? sleepGuidance;
  final String? stepTarget;
  final List<GeneratedPlanWeekEntity> weeklyStructure;

  factory GeneratedPlanEntity.fromMap(Map<String, dynamic> map) {
    return GeneratedPlanEntity(
      title: map['title'] as String? ?? 'TAIYO Workout Plan',
      summary: map['summary'] as String? ?? '',
      durationWeeks: (map['duration_weeks'] as num?)?.toInt() ?? 1,
      level: map['level'] as String? ?? 'beginner',
      startDateSuggestion: _parseDateTime(map['start_date_suggestion']),
      safetyNotes: _stringList(map['safety_notes']),
      restGuidance: map['rest_guidance'] as String?,
      nutritionGuidance: map['nutrition_guidance'] as String?,
      hydrationGuidance: map['hydration_guidance'] as String?,
      sleepGuidance: map['sleep_guidance'] as String?,
      stepTarget: map['step_target'] as String?,
      weeklyStructure: _mapList(
        map['weekly_structure'],
        (item) => GeneratedPlanWeekEntity.fromMap(item),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'summary': summary,
      'duration_weeks': durationWeeks,
      'level': level,
      'start_date_suggestion': startDateSuggestion?.toIso8601String(),
      'safety_notes': safetyNotes,
      'rest_guidance': restGuidance,
      'nutrition_guidance': nutritionGuidance,
      'hydration_guidance': hydrationGuidance,
      'sleep_guidance': sleepGuidance,
      'step_target': stepTarget,
      'weekly_structure': weeklyStructure
          .map(
            (week) => <String, dynamic>{
              'week_number': week.weekNumber,
              'days': week.days
                  .map(
                    (day) => <String, dynamic>{
                      'week_number': day.weekNumber,
                      'day_number': day.dayNumber,
                      'label': day.label,
                      'focus': day.focus,
                      'tasks': day.tasks.map((task) => task.toMap()).toList(),
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }
}

class PlannerDraftEntity {
  const PlannerDraftEntity({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.status,
    required this.assistantMessage,
    this.missingFields = const <String>[],
    this.extractedProfile = const PlannerProfileSnapshotEntity(),
    this.plan,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String sessionId;
  final String status;
  final String assistantMessage;
  final List<String> missingFields;
  final PlannerProfileSnapshotEntity extractedProfile;
  final GeneratedPlanEntity? plan;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PlannerDraftEntity.fromMap(Map<String, dynamic> map) {
    final planMap = _asMap(map['plan_json']);
    return PlannerDraftEntity(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      sessionId: map['session_id'] as String? ?? '',
      status: map['status'] as String? ?? 'collecting_info',
      assistantMessage: map['assistant_message'] as String? ?? '',
      missingFields: _stringList(map['missing_fields']),
      extractedProfile: PlannerProfileSnapshotEntity.fromMap(
        _asMap(map['extracted_profile_json']),
      ),
      plan: planMap.isEmpty ? null : GeneratedPlanEntity.fromMap(planMap),
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updated_at']) ?? DateTime.now(),
    );
  }
}

enum TaskCompletionStatus { pending, completed, partial, skipped, missed }

extension TaskCompletionStatusX on TaskCompletionStatus {
  String get wireValue {
    switch (this) {
      case TaskCompletionStatus.pending:
        return 'pending';
      case TaskCompletionStatus.completed:
        return 'completed';
      case TaskCompletionStatus.partial:
        return 'partial';
      case TaskCompletionStatus.skipped:
        return 'skipped';
      case TaskCompletionStatus.missed:
        return 'missed';
    }
  }

  String get label {
    switch (this) {
      case TaskCompletionStatus.pending:
        return 'Pending';
      case TaskCompletionStatus.completed:
        return 'Completed';
      case TaskCompletionStatus.partial:
        return 'Partial';
      case TaskCompletionStatus.skipped:
        return 'Skipped';
      case TaskCompletionStatus.missed:
        return 'Missed';
    }
  }
}

TaskCompletionStatus taskCompletionStatusFromString(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'completed':
      return TaskCompletionStatus.completed;
    case 'partial':
      return TaskCompletionStatus.partial;
    case 'skipped':
      return TaskCompletionStatus.skipped;
    case 'missed':
      return TaskCompletionStatus.missed;
    default:
      return TaskCompletionStatus.pending;
  }
}

class PlanTaskEntity {
  const PlanTaskEntity({
    required this.planId,
    required this.planTitle,
    required this.planStatus,
    required this.planSource,
    this.planStartDate,
    this.planEndDate,
    required this.dayId,
    required this.weekNumber,
    required this.dayNumber,
    required this.dayIndex,
    required this.dayLabel,
    this.dayFocus,
    required this.scheduledDate,
    required this.taskId,
    required this.taskType,
    required this.title,
    required this.instructions,
    this.sets,
    this.reps,
    this.durationMinutes,
    this.targetValue,
    this.targetUnit,
    this.scheduledTime,
    this.reminderTime,
    required this.isRequired,
    required this.sortOrder,
    this.logId,
    required this.completionStatus,
    this.completionPercent,
    this.logNote,
    this.loggedAt,
  });

  final String planId;
  final String planTitle;
  final String planStatus;
  final String planSource;
  final DateTime? planStartDate;
  final DateTime? planEndDate;
  final String dayId;
  final int weekNumber;
  final int dayNumber;
  final int dayIndex;
  final String dayLabel;
  final String? dayFocus;
  final DateTime scheduledDate;
  final String taskId;
  final String taskType;
  final String title;
  final String instructions;
  final int? sets;
  final int? reps;
  final int? durationMinutes;
  final double? targetValue;
  final String? targetUnit;
  final String? scheduledTime;
  final String? reminderTime;
  final bool isRequired;
  final int sortOrder;
  final String? logId;
  final TaskCompletionStatus completionStatus;
  final int? completionPercent;
  final String? logNote;
  final DateTime? loggedAt;

  factory PlanTaskEntity.fromMap(Map<String, dynamic> map) {
    return PlanTaskEntity(
      planId: map['plan_id'] as String? ?? '',
      planTitle: map['plan_title'] as String? ?? '',
      planStatus: map['plan_status'] as String? ?? 'active',
      planSource: map['plan_source'] as String? ?? 'ai',
      planStartDate: _parseDateTime(map['plan_start_date']),
      planEndDate: _parseDateTime(map['plan_end_date']),
      dayId: map['day_id'] as String? ?? '',
      weekNumber: (map['week_number'] as num?)?.toInt() ?? 1,
      dayNumber: (map['day_number'] as num?)?.toInt() ?? 1,
      dayIndex: (map['day_index'] as num?)?.toInt() ?? 1,
      dayLabel: map['day_label'] as String? ?? 'Day',
      dayFocus: map['day_focus'] as String?,
      scheduledDate: _parseDateTime(map['scheduled_date']) ?? DateTime.now(),
      taskId: map['task_id'] as String? ?? '',
      taskType: map['task_type'] as String? ?? 'workout',
      title: map['task_title'] as String? ?? '',
      instructions: map['task_instructions'] as String? ?? '',
      sets: (map['sets'] as num?)?.toInt(),
      reps: (map['reps'] as num?)?.toInt(),
      durationMinutes: (map['duration_minutes'] as num?)?.toInt(),
      targetValue: (map['target_value'] as num?)?.toDouble(),
      targetUnit: map['target_unit'] as String?,
      scheduledTime: map['scheduled_time'] as String?,
      reminderTime: map['reminder_time'] as String?,
      isRequired: map['is_required'] as bool? ?? true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      logId: map['log_id'] as String?,
      completionStatus: taskCompletionStatusFromString(
        map['effective_status'] as String? ??
            map['completion_status'] as String?,
      ),
      completionPercent: (map['completion_percent'] as num?)?.toInt(),
      logNote: map['log_note'] as String?,
      loggedAt: _parseDateTime(map['logged_at']),
    );
  }

  PlanTaskEntity copyWith({
    TaskCompletionStatus? completionStatus,
    int? completionPercent,
    String? logId,
    String? logNote,
    DateTime? loggedAt,
  }) {
    return PlanTaskEntity(
      planId: planId,
      planTitle: planTitle,
      planStatus: planStatus,
      planSource: planSource,
      planStartDate: planStartDate,
      planEndDate: planEndDate,
      dayId: dayId,
      weekNumber: weekNumber,
      dayNumber: dayNumber,
      dayIndex: dayIndex,
      dayLabel: dayLabel,
      dayFocus: dayFocus,
      scheduledDate: scheduledDate,
      taskId: taskId,
      taskType: taskType,
      title: title,
      instructions: instructions,
      sets: sets,
      reps: reps,
      durationMinutes: durationMinutes,
      targetValue: targetValue,
      targetUnit: targetUnit,
      scheduledTime: scheduledTime,
      reminderTime: reminderTime,
      isRequired: isRequired,
      sortOrder: sortOrder,
      logId: logId ?? this.logId,
      completionStatus: completionStatus ?? this.completionStatus,
      completionPercent: completionPercent ?? this.completionPercent,
      logNote: logNote ?? this.logNote,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }

  bool get isToday {
    final now = DateTime.now();
    return scheduledDate.year == now.year &&
        scheduledDate.month == now.month &&
        scheduledDate.day == now.day;
  }
}

class PlanDayEntity {
  const PlanDayEntity({
    required this.id,
    required this.weekNumber,
    required this.dayNumber,
    required this.dayIndex,
    required this.scheduledDate,
    required this.label,
    this.focus,
    this.tasks = const <PlanTaskEntity>[],
  });

  final String id;
  final int weekNumber;
  final int dayNumber;
  final int dayIndex;
  final DateTime scheduledDate;
  final String label;
  final String? focus;
  final List<PlanTaskEntity> tasks;
}

class PlanDetailEntity {
  const PlanDetailEntity({
    required this.planId,
    required this.planTitle,
    required this.planStatus,
    required this.planSource,
    this.startDate,
    this.endDate,
    this.defaultReminderTime,
    this.generatedPlan,
    this.days = const <PlanDayEntity>[],
  });

  final String planId;
  final String planTitle;
  final String planStatus;
  final String planSource;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? defaultReminderTime;
  final GeneratedPlanEntity? generatedPlan;
  final List<PlanDayEntity> days;
}

class PlanActivationResultEntity {
  const PlanActivationResultEntity({
    required this.planId,
    required this.created,
  });

  final String planId;
  final bool created;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic entryValue) => MapEntry(key.toString(), entryValue),
    );
  }
  return const <String, dynamic>{};
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((dynamic item) => item.toString()).toList(growable: false);
  }
  return const <String>[];
}

List<T> _mapList<T>(dynamic value, T Function(Map<String, dynamic>) mapper) {
  if (value is! List) {
    return <T>[];
  }
  return value
      .map((dynamic item) => mapper(_asMap(item)))
      .toList(growable: false);
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}
