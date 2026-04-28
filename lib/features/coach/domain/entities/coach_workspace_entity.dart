import '../../../coach_member_insights/domain/entities/visibility_settings_entity.dart';
import '../../../member/domain/entities/coaching_engagement_entity.dart';

class CoachWorkspaceEntity {
  const CoachWorkspaceEntity({
    this.activeClients = 0,
    this.newLeads = 0,
    this.pendingPaymentVerifications = 0,
    this.atRiskClients = 0,
    this.overdueCheckins = 0,
    this.unreadMessages = 0,
    this.renewalsDueSoon = 0,
    this.todaySessions = 0,
    this.revenueMonth = 0,
    this.packagePerformance = const <CoachPackagePerformanceEntity>[],
  });

  final int activeClients;
  final int newLeads;
  final int pendingPaymentVerifications;
  final int atRiskClients;
  final int overdueCheckins;
  final int unreadMessages;
  final int renewalsDueSoon;
  final int todaySessions;
  final double revenueMonth;
  final List<CoachPackagePerformanceEntity> packagePerformance;

  factory CoachWorkspaceEntity.fromMap(Map<String, dynamic> map) {
    return CoachWorkspaceEntity(
      activeClients: _int(map['active_clients']),
      newLeads: _int(map['new_leads']),
      pendingPaymentVerifications: _int(map['pending_payment_verifications']),
      atRiskClients: _int(map['at_risk_clients']),
      overdueCheckins: _int(map['overdue_checkins']),
      unreadMessages: _int(map['unread_messages']),
      renewalsDueSoon: _int(map['renewals_due_soon']),
      todaySessions: _int(map['today_sessions']),
      revenueMonth: _double(map['revenue_month']),
      packagePerformance: _list(map['package_performance'])
          .map((item) => CoachPackagePerformanceEntity.fromMap(_map(item)))
          .toList(growable: false),
    );
  }
}

class CoachPackagePerformanceEntity {
  const CoachPackagePerformanceEntity({
    required this.packageId,
    required this.title,
    this.activeClients = 0,
    this.pendingClients = 0,
    this.revenue = 0,
  });

  final String packageId;
  final String title;
  final int activeClients;
  final int pendingClients;
  final double revenue;

  factory CoachPackagePerformanceEntity.fromMap(Map<String, dynamic> map) {
    return CoachPackagePerformanceEntity(
      packageId: _string(map['package_id']),
      title: _string(map['title'], fallback: 'Package'),
      activeClients: _int(map['active_clients']),
      pendingClients: _int(map['pending_clients']),
      revenue: _double(map['revenue']),
    );
  }
}

class CoachActionItemEntity {
  const CoachActionItemEntity({
    required this.id,
    required this.eventType,
    required this.severity,
    required this.status,
    required this.title,
    required this.body,
    required this.ctaLabel,
    this.memberId,
    this.memberName,
    this.subscriptionId,
    this.dueAt,
    this.metadata = const <String, dynamic>{},
    this.createdAt,
  });

  final String id;
  final String eventType;
  final String severity;
  final String status;
  final String title;
  final String body;
  final String ctaLabel;
  final String? memberId;
  final String? memberName;
  final String? subscriptionId;
  final DateTime? dueAt;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  factory CoachActionItemEntity.fromMap(Map<String, dynamic> map) {
    return CoachActionItemEntity(
      id: _string(map['id']),
      eventType: _string(map['event_type']),
      severity: _string(map['severity'], fallback: 'medium'),
      status: _string(map['status'], fallback: 'open'),
      title: _string(map['title'], fallback: 'Action needed'),
      body: _string(map['body']),
      ctaLabel: _string(map['cta_label'], fallback: 'Open'),
      memberId: _nullableString(map['member_id']),
      memberName: _nullableString(map['member_name']),
      subscriptionId: _nullableString(map['subscription_id']),
      dueAt: _date(map['due_at']),
      metadata: _map(map['metadata_json']),
      createdAt: _date(map['created_at']),
    );
  }
}

class CoachClientPipelineFilter {
  const CoachClientPipelineFilter({
    this.pipelineStage,
    this.goal,
    this.packageId,
    this.city,
    this.gender,
    this.language,
    this.startDateFrom,
    this.startDateTo,
    this.renewalStatus,
    this.riskStatus,
    this.search,
  });

  final String? pipelineStage;
  final String? goal;
  final String? packageId;
  final String? city;
  final String? gender;
  final String? language;
  final DateTime? startDateFrom;
  final DateTime? startDateTo;
  final String? renewalStatus;
  final String? riskStatus;
  final String? search;

  Map<String, dynamic> toMap() =>
      <String, dynamic>{
        'pipeline_stage': pipelineStage,
        'goal': goal,
        'package_id': packageId,
        'city': city,
        'gender': gender,
        'language': language,
        'start_date_from': startDateFrom == null
            ? null
            : DateTime.utc(
                startDateFrom!.year,
                startDateFrom!.month,
                startDateFrom!.day,
              ).toIso8601String().split('T').first,
        'start_date_to': startDateTo == null
            ? null
            : DateTime.utc(
                startDateTo!.year,
                startDateTo!.month,
                startDateTo!.day,
              ).toIso8601String().split('T').first,
        'renewal_status': renewalStatus,
        'risk_status': riskStatus,
        'search': search,
      }..removeWhere(
        (key, value) => value == null || value.toString().trim().isEmpty,
      );
}

class CoachClientPipelineEntry {
  const CoachClientPipelineEntry({
    required this.subscriptionId,
    required this.memberId,
    required this.memberName,
    this.memberAvatarPath,
    this.packageId,
    this.packageTitle,
    required this.status,
    required this.checkoutStatus,
    required this.billingCycle,
    required this.amount,
    required this.pipelineStage,
    required this.internalStatus,
    required this.riskStatus,
    this.tags = const <String>[],
    this.coachNotes = '',
    this.goal,
    this.city,
    this.gender,
    this.language,
    this.startedAt,
    this.nextRenewalAt,
    this.lastCheckinAt,
    this.unreadMessages = 0,
    this.riskFlags = const <String>[],
  });

  final String subscriptionId;
  final String memberId;
  final String memberName;
  final String? memberAvatarPath;
  final String? packageId;
  final String? packageTitle;
  final String status;
  final String checkoutStatus;
  final String billingCycle;
  final double amount;
  final String pipelineStage;
  final String internalStatus;
  final String riskStatus;
  final List<String> tags;
  final String coachNotes;
  final String? goal;
  final String? city;
  final String? gender;
  final String? language;
  final DateTime? startedAt;
  final DateTime? nextRenewalAt;
  final DateTime? lastCheckinAt;
  final int unreadMessages;
  final List<String> riskFlags;

  bool get hasRisk => riskStatus != 'none' || riskFlags.isNotEmpty;

  bool get isPendingPayment =>
      pipelineStage == 'pending_payment' ||
      status == 'pending_payment' ||
      status == 'checkout_pending' ||
      checkoutStatus == 'checkout_pending';

  bool get canScheduleBookings => status == 'active';

  factory CoachClientPipelineEntry.fromMap(Map<String, dynamic> map) {
    return CoachClientPipelineEntry(
      subscriptionId: _string(map['subscription_id']),
      memberId: _string(map['member_id']),
      memberName: _string(map['member_name'], fallback: 'Member'),
      memberAvatarPath: _nullableString(map['member_avatar_path']),
      packageId: _nullableString(map['package_id']),
      packageTitle: _nullableString(map['package_title']),
      status: _string(map['status'], fallback: 'active'),
      checkoutStatus: _string(map['checkout_status'], fallback: 'not_started'),
      billingCycle: _string(map['billing_cycle'], fallback: 'monthly'),
      amount: _double(map['amount']),
      pipelineStage: _string(map['pipeline_stage'], fallback: 'lead'),
      internalStatus: _string(map['internal_status'], fallback: 'new'),
      riskStatus: _string(map['risk_status'], fallback: 'none'),
      tags: _strings(map['tags']),
      coachNotes: _string(map['coach_notes']),
      goal: _nullableString(map['goal']),
      city: _nullableString(map['city']),
      gender: _nullableString(map['gender']),
      language: _nullableString(map['language']),
      startedAt: _date(map['started_at']),
      nextRenewalAt: _date(map['next_renewal_at']),
      lastCheckinAt: _date(map['last_checkin_at']),
      unreadMessages: _int(map['unread_messages']),
      riskFlags: _strings(map['risk_flags']),
    );
  }
}

class CoachClientWorkspaceEntity {
  const CoachClientWorkspaceEntity({
    required this.client,
    this.notes = const <CoachClientNoteEntity>[],
    this.threads = const <CoachThreadEntity>[],
    this.checkins = const <WeeklyCheckinEntity>[],
    this.bookings = const <CoachBookingEntity>[],
    this.resources = const <CoachResourceAssignmentEntity>[],
    this.billing = const <CoachPaymentReceiptEntity>[],
    this.visibility,
  });

  final CoachClientPipelineEntry client;
  final List<CoachClientNoteEntity> notes;
  final List<CoachThreadEntity> threads;
  final List<WeeklyCheckinEntity> checkins;
  final List<CoachBookingEntity> bookings;
  final List<CoachResourceAssignmentEntity> resources;
  final List<CoachPaymentReceiptEntity> billing;
  final VisibilitySettingsEntity? visibility;

  factory CoachClientWorkspaceEntity.fromMap(Map<String, dynamic> map) {
    final clientMap = _map(map['client']);
    return CoachClientWorkspaceEntity(
      client: CoachClientPipelineEntry.fromMap(clientMap),
      notes: _list(map['notes'])
          .map((item) => CoachClientNoteEntity.fromMap(_map(item)))
          .toList(growable: false),
      threads: _list(map['threads'])
          .map((item) => CoachThreadEntity.fromMap(_map(item)))
          .toList(growable: false),
      checkins: _list(map['checkins'])
          .map((item) => WeeklyCheckinEntity.fromMap(_map(item)))
          .toList(growable: false),
      bookings: _list(map['bookings'])
          .map((item) => CoachBookingEntity.fromMap(_map(item)))
          .toList(growable: false),
      resources: _list(map['resources'])
          .map((item) => CoachResourceAssignmentEntity.fromMap(_map(item)))
          .toList(growable: false),
      billing: _list(map['billing'])
          .map((item) => CoachPaymentReceiptEntity.fromMap(_map(item)))
          .toList(growable: false),
      visibility: _map(map['visibility']).isEmpty
          ? null
          : VisibilitySettingsEntity.fromJson(_map(map['visibility'])),
    );
  }
}

class CoachClientNoteEntity {
  const CoachClientNoteEntity({
    required this.id,
    required this.subscriptionId,
    required this.memberId,
    required this.note,
    this.noteType = 'general',
    this.isPinned = false,
    this.createdAt,
  });

  final String id;
  final String subscriptionId;
  final String memberId;
  final String note;
  final String noteType;
  final bool isPinned;
  final DateTime? createdAt;

  factory CoachClientNoteEntity.fromMap(Map<String, dynamic> map) {
    return CoachClientNoteEntity(
      id: _string(map['id']),
      subscriptionId: _string(map['subscription_id']),
      memberId: _string(map['member_id']),
      note: _string(map['note']),
      noteType: _string(map['note_type'], fallback: 'general'),
      isPinned: map['is_pinned'] as bool? ?? false,
      createdAt: _date(map['created_at']),
    );
  }
}

class CoachThreadEntity {
  const CoachThreadEntity({
    required this.id,
    required this.subscriptionId,
    required this.memberId,
    required this.coachId,
    this.lastMessagePreview = '',
    this.lastMessageAt,
    this.updatedAt,
  });

  final String id;
  final String subscriptionId;
  final String memberId;
  final String coachId;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime? updatedAt;

  factory CoachThreadEntity.fromMap(Map<String, dynamic> map) {
    return CoachThreadEntity(
      id: _string(map['id']),
      subscriptionId: _string(map['subscription_id']),
      memberId: _string(map['member_id']),
      coachId: _string(map['coach_id']),
      lastMessagePreview: _string(map['last_message_preview']),
      lastMessageAt: _date(map['last_message_at']),
      updatedAt: _date(map['updated_at']),
    );
  }
}

class CoachMessageEntity {
  const CoachMessageEntity({
    required this.id,
    required this.threadId,
    required this.senderUserId,
    required this.senderRole,
    required this.content,
    required this.createdAt,
    this.messageType = 'text',
  });

  final String id;
  final String threadId;
  final String senderUserId;
  final String senderRole;
  final String messageType;
  final String content;
  final DateTime createdAt;

  bool get isSystem => senderRole == 'system' || messageType == 'system';

  bool get isCoach => senderRole == 'coach';

  factory CoachMessageEntity.fromMap(Map<String, dynamic> map) {
    return CoachMessageEntity(
      id: _string(map['id']),
      threadId: _string(map['thread_id']),
      senderUserId: _string(map['sender_user_id']),
      senderRole: _string(map['sender_role'], fallback: 'system'),
      messageType: _string(map['message_type'], fallback: 'text'),
      content: _string(map['content']),
      createdAt: _date(map['created_at']) ?? DateTime.now(),
    );
  }
}

class CoachProgramTemplateEntity {
  const CoachProgramTemplateEntity({
    required this.id,
    this.ownerCoachId,
    required this.title,
    required this.goalType,
    this.description = '',
    this.durationWeeks = 4,
    this.difficultyLevel = 'beginner',
    this.locationMode = 'online',
    this.weeklyStructureJson = const <dynamic>[],
    this.tags = const <String>[],
    this.isSystem = false,
    this.createdAt,
  });

  final String id;
  final String? ownerCoachId;
  final String title;
  final String goalType;
  final String description;
  final int durationWeeks;
  final String difficultyLevel;
  final String locationMode;
  final List<dynamic> weeklyStructureJson;
  final List<String> tags;
  final bool isSystem;
  final DateTime? createdAt;

  factory CoachProgramTemplateEntity.fromMap(Map<String, dynamic> map) {
    return CoachProgramTemplateEntity(
      id: _string(map['id']),
      ownerCoachId: _nullableString(map['owner_coach_id']),
      title: _string(map['title'], fallback: 'Program'),
      goalType: _string(map['goal_type'], fallback: 'custom'),
      description: _string(map['description']),
      durationWeeks: _int(map['duration_weeks'], fallback: 4),
      difficultyLevel: _string(map['difficulty_level'], fallback: 'beginner'),
      locationMode: _string(map['location_mode'], fallback: 'online'),
      weeklyStructureJson: _list(map['weekly_structure_json']),
      tags: _strings(map['tags']),
      isSystem: map['is_system'] as bool? ?? false,
      createdAt: _date(map['created_at']),
    );
  }
}

class CoachExerciseEntity {
  const CoachExerciseEntity({
    required this.id,
    required this.title,
    this.category = 'strength',
    this.primaryMuscles = const <String>[],
    this.equipmentTags = const <String>[],
    this.difficultyLevel = 'beginner',
    this.instructions = '',
    this.videoUrl,
    this.progressionRule = '',
    this.regressionRule = '',
    this.restGuidanceSeconds,
    this.isSystem = false,
  });

  final String id;
  final String title;
  final String category;
  final List<String> primaryMuscles;
  final List<String> equipmentTags;
  final String difficultyLevel;
  final String instructions;
  final String? videoUrl;
  final String progressionRule;
  final String regressionRule;
  final int? restGuidanceSeconds;
  final bool isSystem;

  factory CoachExerciseEntity.fromMap(Map<String, dynamic> map) {
    return CoachExerciseEntity(
      id: _string(map['id']),
      title: _string(map['title'], fallback: 'Exercise'),
      category: _string(map['category'], fallback: 'strength'),
      primaryMuscles: _strings(map['primary_muscles']),
      equipmentTags: _strings(map['equipment_tags']),
      difficultyLevel: _string(map['difficulty_level'], fallback: 'beginner'),
      instructions: _string(map['instructions']),
      videoUrl: _nullableString(map['video_url']),
      progressionRule: _string(map['progression_rule']),
      regressionRule: _string(map['regression_rule']),
      restGuidanceSeconds: _nullableInt(map['rest_guidance_seconds']),
      isSystem: map['is_system'] as bool? ?? false,
    );
  }
}

class CoachHabitAssignmentEntity {
  const CoachHabitAssignmentEntity({
    required this.id,
    required this.subscriptionId,
    required this.memberId,
    required this.title,
    this.habitType = 'custom',
    this.description = '',
    this.targetValue,
    this.targetUnit,
    this.frequency = 'daily',
    this.status = 'active',
  });

  final String id;
  final String subscriptionId;
  final String memberId;
  final String title;
  final String habitType;
  final String description;
  final double? targetValue;
  final String? targetUnit;
  final String frequency;
  final String status;

  factory CoachHabitAssignmentEntity.fromMap(Map<String, dynamic> map) {
    return CoachHabitAssignmentEntity(
      id: _string(map['id']),
      subscriptionId: _string(map['subscription_id']),
      memberId: _string(map['member_id']),
      title: _string(map['title'], fallback: 'Habit'),
      habitType: _string(map['habit_type'], fallback: 'custom'),
      description: _string(map['description']),
      targetValue: _nullableDouble(map['target_value']),
      targetUnit: _nullableString(map['target_unit']),
      frequency: _string(map['frequency'], fallback: 'daily'),
      status: _string(map['status'], fallback: 'active'),
    );
  }
}

class CoachOnboardingTemplateEntity {
  const CoachOnboardingTemplateEntity({
    required this.id,
    required this.title,
    this.clientType = 'general',
    this.description = '',
    this.welcomeMessage = '',
    this.starterProgramTemplateId,
    this.resourceIds = const <String>[],
    this.habitTemplates = const <dynamic>[],
  });

  final String id;
  final String title;
  final String clientType;
  final String description;
  final String welcomeMessage;
  final String? starterProgramTemplateId;
  final List<String> resourceIds;
  final List<dynamic> habitTemplates;

  factory CoachOnboardingTemplateEntity.fromMap(Map<String, dynamic> map) {
    return CoachOnboardingTemplateEntity(
      id: _string(map['id']),
      title: _string(map['title'], fallback: 'Onboarding flow'),
      clientType: _string(map['client_type'], fallback: 'general'),
      description: _string(map['description']),
      welcomeMessage: _string(map['welcome_message']),
      starterProgramTemplateId: _nullableString(
        map['starter_program_template_id'],
      ),
      resourceIds: _strings(map['resource_ids']),
      habitTemplates: _list(map['habit_templates_json']),
    );
  }
}

class CoachSessionTypeEntity {
  const CoachSessionTypeEntity({
    required this.id,
    required this.title,
    required this.sessionKind,
    this.coachId = '',
    this.durationMinutes = 45,
    this.deliveryMode = 'online',
    this.isSelfBookable = true,
  });

  final String id;
  final String title;
  final String sessionKind;
  final String coachId;
  final int durationMinutes;
  final String deliveryMode;
  final bool isSelfBookable;

  factory CoachSessionTypeEntity.fromMap(Map<String, dynamic> map) {
    return CoachSessionTypeEntity(
      id: _string(map['id']),
      title: _string(map['title'], fallback: 'Session'),
      sessionKind: _string(map['session_kind'], fallback: 'consultation'),
      coachId: _string(map['coach_id']),
      durationMinutes: _int(map['duration_minutes'], fallback: 45),
      deliveryMode: _string(map['delivery_mode'], fallback: 'online'),
      isSelfBookable: map['is_self_bookable'] as bool? ?? true,
    );
  }
}

class CoachBookingEntity {
  const CoachBookingEntity({
    required this.id,
    required this.coachId,
    required this.memberId,
    this.memberName,
    this.subscriptionId,
    this.sessionTypeId,
    this.sessionTypeTitle,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.timezone = 'UTC',
    this.status = 'scheduled',
    this.deliveryMode = 'online',
    this.locationNote,
    this.videoJoinUrl,
  });

  final String id;
  final String coachId;
  final String memberId;
  final String? memberName;
  final String? subscriptionId;
  final String? sessionTypeId;
  final String? sessionTypeTitle;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String timezone;
  final String status;
  final String deliveryMode;
  final String? locationNote;
  final String? videoJoinUrl;

  factory CoachBookingEntity.fromMap(Map<String, dynamic> map) {
    return CoachBookingEntity(
      id: _string(map['id']),
      coachId: _string(map['coach_id']),
      memberId: _string(map['member_id']),
      memberName: _nullableString(map['member_name']),
      subscriptionId: _nullableString(map['subscription_id']),
      sessionTypeId: _nullableString(map['session_type_id']),
      sessionTypeTitle: _nullableString(map['session_type_title']),
      title: _string(map['title'], fallback: 'Session'),
      startsAt: _date(map['starts_at']) ?? DateTime.now(),
      endsAt: _date(map['ends_at']) ?? DateTime.now(),
      timezone: _string(map['timezone'], fallback: 'UTC'),
      status: _string(map['status'], fallback: 'scheduled'),
      deliveryMode: _string(map['delivery_mode'], fallback: 'online'),
      locationNote: _nullableString(map['location_note']),
      videoJoinUrl: _nullableString(map['video_join_url']),
    );
  }
}

class CoachPaymentReceiptEntity {
  const CoachPaymentReceiptEntity({
    required this.id,
    required this.subscriptionId,
    required this.memberId,
    this.memberName,
    this.packageTitle,
    this.amount = 0,
    this.currency = 'EGP',
    this.paymentReference,
    this.receiptStoragePath,
    this.status = 'awaiting_payment',
    this.billingState = 'awaiting_payment',
    this.paymentGateway,
    this.paymentOrderId,
    this.paymentOrderStatus,
    this.payoutStatus,
    this.submittedAt,
    this.reviewedAt,
    this.failureReason,
  });

  final String id;
  final String subscriptionId;
  final String memberId;
  final String? memberName;
  final String? packageTitle;
  final double amount;
  final String currency;
  final String? paymentReference;
  final String? receiptStoragePath;
  final String status;
  final String billingState;
  final String? paymentGateway;
  final String? paymentOrderId;
  final String? paymentOrderStatus;
  final String? payoutStatus;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? failureReason;

  bool get isPaymobPayment => paymentGateway?.toLowerCase() == 'paymob';

  factory CoachPaymentReceiptEntity.fromMap(Map<String, dynamic> map) {
    return CoachPaymentReceiptEntity(
      id: _string(map['receipt_id'] ?? map['id']),
      subscriptionId: _string(map['subscription_id']),
      memberId: _string(map['member_id']),
      memberName: _nullableString(map['member_name']),
      packageTitle: _nullableString(map['package_title']),
      amount: _double(map['amount']),
      currency: _string(map['currency'], fallback: 'EGP'),
      paymentReference: _nullableString(map['payment_reference']),
      receiptStoragePath: _nullableString(map['receipt_storage_path']),
      status: _string(
        map['receipt_status'] ?? map['status'],
        fallback: 'awaiting_payment',
      ),
      billingState: _string(map['billing_state'], fallback: 'awaiting_payment'),
      paymentGateway: _nullableString(map['payment_gateway']),
      paymentOrderId: _nullableString(map['payment_order_id']),
      paymentOrderStatus: _nullableString(map['payment_order_status']),
      payoutStatus: _nullableString(map['payout_status']),
      submittedAt: _date(map['submitted_at'] ?? map['created_at']),
      reviewedAt: _date(map['reviewed_at']),
      failureReason: _nullableString(map['failure_reason']),
    );
  }
}

class CoachPaymentAuditEntity {
  const CoachPaymentAuditEntity({
    required this.id,
    this.actorName,
    this.oldState,
    required this.newState,
    this.note,
    this.createdAt,
  });

  final String id;
  final String? actorName;
  final String? oldState;
  final String newState;
  final String? note;
  final DateTime? createdAt;

  factory CoachPaymentAuditEntity.fromMap(Map<String, dynamic> map) {
    return CoachPaymentAuditEntity(
      id: _string(map['id']),
      actorName: _nullableString(map['actor_name']),
      oldState: _nullableString(map['old_state']),
      newState: _string(map['new_state'], fallback: 'updated'),
      note: _nullableString(map['note']),
      createdAt: _date(map['created_at']),
    );
  }
}

class CoachResourceEntity {
  const CoachResourceEntity({
    required this.id,
    required this.title,
    this.description = '',
    this.resourceType = 'file',
    this.storagePath,
    this.externalUrl,
    this.tags = const <String>[],
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String resourceType;
  final String? storagePath;
  final String? externalUrl;
  final List<String> tags;
  final DateTime? createdAt;

  factory CoachResourceEntity.fromMap(Map<String, dynamic> map) {
    return CoachResourceEntity(
      id: _string(map['resource_id'] ?? map['id']),
      title: _string(map['title'], fallback: 'Resource'),
      description: _string(map['description']),
      resourceType: _string(map['resource_type'], fallback: 'file'),
      storagePath: _nullableString(map['storage_path']),
      externalUrl: _nullableString(map['external_url']),
      tags: _strings(map['tags']),
      createdAt: _date(map['created_at']),
    );
  }
}

class CoachResourceAssignmentEntity {
  const CoachResourceAssignmentEntity({
    required this.id,
    required this.resourceId,
    required this.title,
    this.resourceType = 'file',
    this.storagePath,
    this.externalUrl,
    this.assignedAt,
    this.viewedAt,
    this.completedAt,
    this.memberNote,
  });

  final String id;
  final String resourceId;
  final String title;
  final String resourceType;
  final String? storagePath;
  final String? externalUrl;
  final DateTime? assignedAt;
  final DateTime? viewedAt;
  final DateTime? completedAt;
  final String? memberNote;

  factory CoachResourceAssignmentEntity.fromMap(Map<String, dynamic> map) {
    return CoachResourceAssignmentEntity(
      id: _string(map['id']),
      resourceId: _string(map['resource_id']),
      title: _string(map['title'], fallback: 'Resource'),
      resourceType: _string(map['resource_type'], fallback: 'file'),
      storagePath: _nullableString(map['storage_path']),
      externalUrl: _nullableString(map['external_url']),
      assignedAt: _date(map['assigned_at'] ?? map['created_at']),
      viewedAt: _date(map['viewed_at']),
      completedAt: _date(map['completed_at']),
      memberNote: _nullableString(map['member_note']),
    );
  }
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  return _int(value);
}

double _double(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _nullableDouble(dynamic value) {
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

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
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
