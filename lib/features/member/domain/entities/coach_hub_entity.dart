import '../../../coach/domain/entities/coach_workspace_entity.dart';

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _double(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String _string(dynamic value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  if (value is List<dynamic>) return value;
  if (value is List) return List<dynamic>.from(value);
  return const <dynamic>[];
}

List<String> _strings(dynamic value) {
  return _list(value).map((item) => item.toString()).toList(growable: false);
}

class MemberCoachHubEntity {
  const MemberCoachHubEntity({
    this.subscription,
    this.relationshipStage = 'none',
    this.kickoff,
    this.todayAgenda = const <MemberCoachAgendaItemEntity>[],
    this.weekAgenda = const <MemberCoachAgendaItemEntity>[],
    this.progressSnapshot = const MemberCoachProgressSnapshotEntity(),
    this.latestFeedback,
    this.habits = const <MemberAssignedHabitEntity>[],
    this.resources = const <MemberAssignedResourceEntity>[],
    this.bookings = const <CoachBookingEntity>[],
  });

  final MemberCoachSubscriptionSummaryEntity? subscription;
  final String relationshipStage;
  final MemberCoachKickoffEntity? kickoff;
  final List<MemberCoachAgendaItemEntity> todayAgenda;
  final List<MemberCoachAgendaItemEntity> weekAgenda;
  final MemberCoachProgressSnapshotEntity progressSnapshot;
  final MemberCoachFeedbackEntity? latestFeedback;
  final List<MemberAssignedHabitEntity> habits;
  final List<MemberAssignedResourceEntity> resources;
  final List<CoachBookingEntity> bookings;

  bool get hasActiveSubscription => subscription?.status == 'active';

  bool get needsKickoff => relationshipStage == 'awaiting_kickoff';

  factory MemberCoachHubEntity.fromMap(Map<String, dynamic> map) {
    final subscriptionMap = _map(map['subscription']);
    final kickoffMap = _map(map['kickoff']);
    final feedbackMap = _map(map['latest_feedback']);
    return MemberCoachHubEntity(
      subscription: subscriptionMap.isEmpty
          ? null
          : MemberCoachSubscriptionSummaryEntity.fromMap(subscriptionMap),
      relationshipStage: _string(map['relationship_stage'], fallback: 'none'),
      kickoff: kickoffMap.isEmpty
          ? null
          : MemberCoachKickoffEntity.fromMap(kickoffMap),
      todayAgenda: _list(map['today_agenda'])
          .map((item) => MemberCoachAgendaItemEntity.fromMap(_map(item)))
          .toList(growable: false),
      weekAgenda: _list(map['week_agenda'])
          .map((item) => MemberCoachAgendaItemEntity.fromMap(_map(item)))
          .toList(growable: false),
      progressSnapshot: MemberCoachProgressSnapshotEntity.fromMap(
        _map(map['progress_snapshot']),
      ),
      latestFeedback: feedbackMap.isEmpty
          ? null
          : MemberCoachFeedbackEntity.fromMap(feedbackMap),
      habits: _list(map['habits'])
          .map((item) => MemberAssignedHabitEntity.fromMap(_map(item)))
          .toList(growable: false),
      resources: _list(map['resources'])
          .map((item) => MemberAssignedResourceEntity.fromMap(_map(item)))
          .toList(growable: false),
      bookings: _list(map['bookings'])
          .map((item) => CoachBookingEntity.fromMap(_map(item)))
          .toList(growable: false),
    );
  }
}

class MemberCoachSubscriptionSummaryEntity {
  const MemberCoachSubscriptionSummaryEntity({
    required this.id,
    required this.memberId,
    required this.coachId,
    this.coachName = 'Coach',
    this.coachAvatarPath,
    this.packageId,
    this.packageTitle = 'Coaching',
    this.planName = '',
    this.status = 'checkout_pending',
    this.checkoutStatus = 'not_started',
    this.billingCycle = 'monthly',
    this.amount = 0,
    this.currency = 'EGP',
    this.activatedAt,
    this.nextRenewalAt,
    this.threadId,
    this.feedbackSlaHours = 24,
    this.initialPlanSlaHours = 48,
    this.weeklyCheckinsIncluded = 1,
    this.sessionCountPerMonth = 0,
    this.packageSummaryForMember = '',
  });

  final String id;
  final String memberId;
  final String coachId;
  final String coachName;
  final String? coachAvatarPath;
  final String? packageId;
  final String packageTitle;
  final String planName;
  final String status;
  final String checkoutStatus;
  final String billingCycle;
  final double amount;
  final String currency;
  final DateTime? activatedAt;
  final DateTime? nextRenewalAt;
  final String? threadId;
  final int feedbackSlaHours;
  final int initialPlanSlaHours;
  final int weeklyCheckinsIncluded;
  final int sessionCountPerMonth;
  final String packageSummaryForMember;

  String get responseSlaLabel => feedbackSlaHours <= 1
      ? 'Feedback within 1 hour'
      : 'Feedback within $feedbackSlaHours hours';

  factory MemberCoachSubscriptionSummaryEntity.fromMap(
    Map<String, dynamic> map,
  ) {
    return MemberCoachSubscriptionSummaryEntity(
      id: _string(map['id']),
      memberId: _string(map['member_id']),
      coachId: _string(map['coach_id']),
      coachName: _string(map['coach_name'], fallback: 'Coach'),
      coachAvatarPath: _nullableString(map['coach_avatar_path']),
      packageId: _nullableString(map['package_id']),
      packageTitle: _string(map['package_title'], fallback: 'Coaching'),
      planName: _string(map['plan_name']),
      status: _string(map['status'], fallback: 'checkout_pending'),
      checkoutStatus: _string(map['checkout_status'], fallback: 'not_started'),
      billingCycle: _string(map['billing_cycle'], fallback: 'monthly'),
      amount: _double(map['amount']) ?? 0,
      currency: _string(map['currency'], fallback: 'EGP'),
      activatedAt: _date(map['activated_at']),
      nextRenewalAt: _date(map['next_renewal_at']),
      threadId: _nullableString(map['thread_id']),
      feedbackSlaHours: _int(map['feedback_sla_hours'], fallback: 24),
      initialPlanSlaHours: _int(map['initial_plan_sla_hours'], fallback: 48),
      weeklyCheckinsIncluded: _int(
        map['weekly_checkins_included'],
        fallback: 1,
      ),
      sessionCountPerMonth: _int(map['session_count_per_month']),
      packageSummaryForMember: _string(map['package_summary_for_member']),
    );
  }
}

class MemberCoachKickoffEntity {
  const MemberCoachKickoffEntity({
    required this.id,
    required this.subscriptionId,
    required this.coachId,
    required this.memberId,
    this.primaryGoal = '',
    this.trainingLevel = '',
    this.preferredTrainingDays = const <String>[],
    this.availableEquipment = const <String>[],
    this.injuriesLimitations = '',
    this.scheduleConstraints = '',
    this.nutritionSituation = '',
    this.sleepRecoveryNotes = '',
    this.biggestObstacle = '',
    this.coachExpectations = '',
    this.memberNote = '',
    this.completedAt,
  });

  final String id;
  final String subscriptionId;
  final String coachId;
  final String memberId;
  final String primaryGoal;
  final String trainingLevel;
  final List<String> preferredTrainingDays;
  final List<String> availableEquipment;
  final String injuriesLimitations;
  final String scheduleConstraints;
  final String nutritionSituation;
  final String sleepRecoveryNotes;
  final String biggestObstacle;
  final String coachExpectations;
  final String memberNote;
  final DateTime? completedAt;

  factory MemberCoachKickoffEntity.fromMap(Map<String, dynamic> map) {
    return MemberCoachKickoffEntity(
      id: _string(map['id']),
      subscriptionId: _string(map['subscription_id']),
      coachId: _string(map['coach_id']),
      memberId: _string(map['member_id']),
      primaryGoal: _string(map['primary_goal']),
      trainingLevel: _string(map['training_level']),
      preferredTrainingDays: _strings(map['preferred_training_days']),
      availableEquipment: _strings(map['available_equipment']),
      injuriesLimitations: _string(map['injuries_limitations']),
      scheduleConstraints: _string(map['schedule_constraints']),
      nutritionSituation: _string(map['nutrition_situation']),
      sleepRecoveryNotes: _string(map['sleep_recovery_notes']),
      biggestObstacle: _string(map['biggest_obstacle']),
      coachExpectations: _string(map['coach_expectations']),
      memberNote: _string(map['member_note']),
      completedAt: _date(map['completed_at']),
    );
  }
}

class MemberCoachAgendaItemEntity {
  const MemberCoachAgendaItemEntity({
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    this.status = 'pending',
    this.dueAt,
    this.completedAt,
    this.sourceTable = '',
    this.sourceId,
    this.coachId = '',
    this.memberId = '',
    this.subscriptionId = '',
    this.priority = 100,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final String status;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final String sourceTable;
  final String? sourceId;
  final String coachId;
  final String memberId;
  final String subscriptionId;
  final int priority;
  final Map<String, dynamic> metadata;

  bool get isDone =>
      status == 'completed' || status == 'viewed' || completedAt != null;

  factory MemberCoachAgendaItemEntity.fromMap(Map<String, dynamic> map) {
    return MemberCoachAgendaItemEntity(
      id: _string(map['id']),
      type: _string(map['type'], fallback: 'task'),
      title: _string(map['title'], fallback: 'Task'),
      description: _string(map['description']),
      status: _string(map['status'], fallback: 'pending'),
      dueAt: _date(map['due_at']),
      completedAt: _date(map['completed_at']),
      sourceTable: _string(map['source_table']),
      sourceId: _nullableString(map['source_id']),
      coachId: _string(map['coach_id']),
      memberId: _string(map['member_id']),
      subscriptionId: _string(map['subscription_id']),
      priority: _int(map['priority'], fallback: 100),
      metadata: _map(map['metadata']),
    );
  }
}

class MemberCoachProgressSnapshotEntity {
  const MemberCoachProgressSnapshotEntity({
    this.workoutsCompletedThisWeek = 0,
    this.habitsCompletedThisWeek = 0,
    this.checkinStatus = 'due',
  });

  final int workoutsCompletedThisWeek;
  final int habitsCompletedThisWeek;
  final String checkinStatus;

  factory MemberCoachProgressSnapshotEntity.fromMap(Map<String, dynamic> map) {
    return MemberCoachProgressSnapshotEntity(
      workoutsCompletedThisWeek: _int(map['workouts_completed_this_week']),
      habitsCompletedThisWeek: _int(map['habits_completed_this_week']),
      checkinStatus: _string(map['checkin_status'], fallback: 'due'),
    );
  }
}

class MemberCoachFeedbackEntity {
  const MemberCoachFeedbackEntity({
    required this.checkinId,
    this.weekStart,
    this.coachReply,
    this.feedback = const <String, dynamic>{},
    this.feedbackAt,
    this.nextCheckinDate,
  });

  final String checkinId;
  final DateTime? weekStart;
  final String? coachReply;
  final Map<String, dynamic> feedback;
  final DateTime? feedbackAt;
  final DateTime? nextCheckinDate;

  String get onePriority =>
      _string(feedback['one_priority'], fallback: coachReply ?? '');

  String get whatWentWell => _string(feedback['what_went_well']);

  String get whatNeedsAttention => _string(feedback['what_needs_attention']);

  String get adjustmentForNextWeek =>
      _string(feedback['adjustment_for_next_week']);

  String get planChangesSummary => _string(feedback['plan_changes_summary']);

  factory MemberCoachFeedbackEntity.fromMap(Map<String, dynamic> map) {
    return MemberCoachFeedbackEntity(
      checkinId: _string(map['checkin_id']),
      weekStart: _date(map['week_start']),
      coachReply: _nullableString(map['coach_reply']),
      feedback: _map(map['feedback']),
      feedbackAt: _date(map['feedback_at']),
      nextCheckinDate: _date(map['next_checkin_date']),
    );
  }
}

class MemberAssignedHabitEntity {
  const MemberAssignedHabitEntity({
    required this.id,
    required this.subscriptionId,
    required this.coachId,
    this.coachName = 'Coach',
    required this.memberId,
    required this.title,
    this.habitType = 'custom',
    this.description = '',
    this.targetValue,
    this.targetUnit,
    this.frequency = 'daily',
    this.status = 'active',
    this.startDate,
    this.endDate,
    this.logId,
    this.logDate,
    this.completionStatus,
    this.value,
    this.note,
    this.completedThisWeek = 0,
    this.totalThisWeek = 0,
    this.adherencePercent = 0,
  });

  final String id;
  final String subscriptionId;
  final String coachId;
  final String coachName;
  final String memberId;
  final String title;
  final String habitType;
  final String description;
  final double? targetValue;
  final String? targetUnit;
  final String frequency;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? logId;
  final DateTime? logDate;
  final String? completionStatus;
  final double? value;
  final String? note;
  final int completedThisWeek;
  final int totalThisWeek;
  final int adherencePercent;

  bool get loggedToday => completionStatus != null;

  factory MemberAssignedHabitEntity.fromMap(Map<String, dynamic> map) {
    return MemberAssignedHabitEntity(
      id: _string(map['id']),
      subscriptionId: _string(map['subscription_id']),
      coachId: _string(map['coach_id']),
      coachName: _string(map['coach_name'], fallback: 'Coach'),
      memberId: _string(map['member_id']),
      title: _string(map['title'], fallback: 'Habit'),
      habitType: _string(map['habit_type'], fallback: 'custom'),
      description: _string(map['description']),
      targetValue: _double(map['target_value']),
      targetUnit: _nullableString(map['target_unit']),
      frequency: _string(map['frequency'], fallback: 'daily'),
      status: _string(map['status'], fallback: 'active'),
      startDate: _date(map['start_date']),
      endDate: _date(map['end_date']),
      logId: _nullableString(map['log_id']),
      logDate: _date(map['log_date']),
      completionStatus: _nullableString(map['completion_status']),
      value: _double(map['value']),
      note: _nullableString(map['note']),
      completedThisWeek: _int(map['completed_this_week']),
      totalThisWeek: _int(map['total_this_week']),
      adherencePercent: _int(map['adherence_percent']),
    );
  }
}

class MemberAssignedResourceEntity {
  const MemberAssignedResourceEntity({
    required this.id,
    required this.resourceId,
    required this.subscriptionId,
    required this.coachId,
    this.coachName = 'Coach',
    required this.memberId,
    required this.title,
    this.description = '',
    this.resourceType = 'file',
    this.storagePath,
    this.externalUrl,
    this.note,
    this.assignedAt,
    this.viewedAt,
    this.completedAt,
    this.memberNote,
  });

  final String id;
  final String resourceId;
  final String subscriptionId;
  final String coachId;
  final String coachName;
  final String memberId;
  final String title;
  final String description;
  final String resourceType;
  final String? storagePath;
  final String? externalUrl;
  final String? note;
  final DateTime? assignedAt;
  final DateTime? viewedAt;
  final DateTime? completedAt;
  final String? memberNote;

  bool get isCompleted => completedAt != null;

  bool get isViewed => viewedAt != null || isCompleted;

  bool get isExternal => externalUrl?.trim().isNotEmpty == true;

  factory MemberAssignedResourceEntity.fromMap(Map<String, dynamic> map) {
    return MemberAssignedResourceEntity(
      id: _string(map['id']),
      resourceId: _string(map['resource_id']),
      subscriptionId: _string(map['subscription_id']),
      coachId: _string(map['coach_id']),
      coachName: _string(map['coach_name'], fallback: 'Coach'),
      memberId: _string(map['member_id']),
      title: _string(map['title'], fallback: 'Resource'),
      description: _string(map['description']),
      resourceType: _string(map['resource_type'], fallback: 'file'),
      storagePath: _nullableString(map['storage_path']),
      externalUrl: _nullableString(map['external_url']),
      note: _nullableString(map['note']),
      assignedAt: _date(map['assigned_at']),
      viewedAt: _date(map['viewed_at']),
      completedAt: _date(map['completed_at']),
      memberNote: _nullableString(map['member_note']),
    );
  }
}

class MemberBookableSlotEntity {
  const MemberBookableSlotEntity({
    required this.coachId,
    required this.sessionTypeId,
    required this.startsAt,
    required this.endsAt,
    this.timezone = 'UTC',
    this.deliveryMode = 'online',
  });

  final String coachId;
  final String sessionTypeId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String timezone;
  final String deliveryMode;

  factory MemberBookableSlotEntity.fromMap(Map<String, dynamic> map) {
    return MemberBookableSlotEntity(
      coachId: _string(map['coach_id']),
      sessionTypeId: _string(map['session_type_id']),
      startsAt: _date(map['starts_at']) ?? DateTime.now(),
      endsAt: _date(map['ends_at']) ?? DateTime.now(),
      timezone: _string(map['timezone'], fallback: 'UTC'),
      deliveryMode: _string(map['delivery_mode'], fallback: 'online'),
    );
  }
}
