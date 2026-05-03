import '../../../../core/result/paged.dart';
import '../../../member/domain/entities/coaching_engagement_entity.dart';
import '../entities/coach_entity.dart';
import '../entities/coach_taiyo_entity.dart';
import '../entities/coach_workspace_entity.dart';
import '../entities/subscription_entity.dart';
import '../entities/workout_plan_entity.dart';

abstract class CoachRepository {
  Future<Paged<CoachEntity>> listCoaches({
    String? specialty,
    String? city,
    String? language,
    String? coachGender,
    double? maxBudget,
    String? cursor,
    int limit = 20,
  });

  Future<CoachEntity?> getCoachDetails(String coachId);

  Future<void> upsertCoachProfile({
    required String bio,
    required List<String> specialties,
    required int yearsExperience,
    required double hourlyRate,
    required String deliveryMode,
    required String serviceSummary,
    String? city,
    List<String> languages = const <String>[],
    String? coachGender,
    int responseSlaHours = 12,
    bool trialOfferEnabled = true,
    double trialPriceEgp = 0,
    bool remoteOnly = false,
    String headline = '',
    String positioningStatement = '',
  });

  Future<List<CoachPackageEntity>> listCoachPackages({
    String? coachId,
    bool activeOnly = false,
  });

  Future<void> saveCoachPackage({
    String? packageId,
    required String title,
    required String description,
    required String billingCycle,
    required double price,
    String subtitle = '',
    String outcomeSummary = '',
    List<String> idealFor = const <String>[],
    int durationWeeks = 4,
    int sessionsPerWeek = 3,
    String difficultyLevel = 'beginner',
    List<String> equipmentTags = const <String>[],
    List<String> includedFeatures = const <String>[],
    String checkInFrequency = '',
    String supportSummary = '',
    List<CoachPackageFaqEntity> faqItems = const <CoachPackageFaqEntity>[],
    Map<String, dynamic> planPreviewJson = const <String, dynamic>{},
    String? visibilityStatus,
    bool isActive = true,
    List<String> targetGoalTags = const <String>[],
    String locationMode = 'online',
    String deliveryMode = 'chat',
    String weeklyCheckinType = 'form',
    int trialDays = 7,
    double depositAmountEgp = 0,
    double renewalPriceEgp = 0,
    int maxSlots = 100,
    bool pauseAllowed = true,
    List<String> paymentRails = const <String>[],
    int weeklyCheckinsIncluded = 1,
    int feedbackSlaHours = 24,
    int initialPlanSlaHours = 48,
    bool workoutPlanIncluded = true,
    bool nutritionGuidanceIncluded = false,
    bool habitsIncluded = true,
    bool resourcesIncluded = true,
    bool sessionsIncluded = false,
    bool monthlyReviewIncluded = false,
    int sessionCountPerMonth = 0,
    String packageSummaryForMember = '',
  });

  Future<void> deleteCoachPackage(String packageId);

  Future<List<CoachAvailabilitySlotEntity>> listAvailability({String? coachId});

  Future<void> saveAvailabilitySlot({
    String? slotId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String timezone,
    bool isActive = true,
  });

  Future<void> deleteAvailabilitySlot(String slotId);

  Future<CoachDashboardSummaryEntity> getDashboardSummary();

  Future<List<CoachClientEntity>> listClients();

  Future<CoachWorkspaceEntity> getWorkspaceSummary();

  Future<List<CoachActionItemEntity>> listActionItems();

  Future<void> dismissAutomationEvent(String eventId);

  Future<List<CoachClientPipelineEntry>> listClientPipeline(
    CoachClientPipelineFilter filter,
  );

  Future<CoachClientWorkspaceEntity> getClientWorkspace(String subscriptionId);

  Future<void> saveClientRecord({
    required String subscriptionId,
    String? pipelineStage,
    String? internalStatus,
    String? riskStatus,
    List<String>? tags,
    String? coachNotes,
    String? preferredLanguage,
    DateTime? followUpAt,
  });

  Future<CoachClientNoteEntity> addClientNote({
    required String subscriptionId,
    required String note,
    String noteType = 'general',
    bool isPinned = false,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  });

  Future<List<CoachThreadEntity>> listCoachThreads();

  Future<List<CoachMessageEntity>> listCoachMessages(String threadId);

  Future<void> sendCoachMessage({
    required String threadId,
    required String content,
  });

  Future<void> markThreadRead(String threadId);

  Future<List<WeeklyCheckinEntity>> listCheckinInbox();

  Future<void> submitCheckinFeedback({
    required String checkinId,
    required String threadId,
    required String feedback,
    String whatWentWell = '',
    String whatNeedsAttention = '',
    String adjustmentForNextWeek = '',
    String onePriority = '',
    String coachNote = '',
    String planChangesSummary = '',
    DateTime? nextCheckinDate,
  });

  Future<List<CoachProgramTemplateEntity>> listProgramTemplates();

  Future<CoachProgramTemplateEntity> saveProgramTemplate({
    String? templateId,
    required String title,
    required String goalType,
    String description = '',
    int durationWeeks = 4,
    String difficultyLevel = 'beginner',
    String locationMode = 'online',
    List<dynamic> weeklyStructure = const <dynamic>[],
    List<String> tags = const <String>[],
  });

  Future<void> assignProgramTemplate({
    required String subscriptionId,
    required String templateId,
    DateTime? startDate,
    String? defaultReminderTime,
  });

  Future<List<CoachExerciseEntity>> listExercises();

  Future<CoachExerciseEntity> saveExercise({
    String? exerciseId,
    required String title,
    String category = 'strength',
    List<String> primaryMuscles = const <String>[],
    List<String> equipmentTags = const <String>[],
    String difficultyLevel = 'beginner',
    String instructions = '',
    String? videoUrl,
    List<dynamic> substitutions = const <dynamic>[],
    String progressionRule = '',
    String regressionRule = '',
    int? restGuidanceSeconds,
    List<dynamic> cues = const <dynamic>[],
  });

  Future<List<CoachHabitAssignmentEntity>> assignHabits({
    required String subscriptionId,
    required List<Map<String, dynamic>> habits,
  });

  Future<List<CoachOnboardingTemplateEntity>> listOnboardingTemplates();

  Future<CoachOnboardingTemplateEntity> saveOnboardingTemplate({
    String? templateId,
    required String title,
    String clientType = 'general',
    String description = '',
    String welcomeMessage = '',
    Map<String, dynamic> intakeForm = const <String, dynamic>{},
    Map<String, dynamic> goalsQuestionnaire = const <String, dynamic>{},
    String? starterProgramTemplateId,
    List<dynamic> habitTemplates = const <dynamic>[],
    List<dynamic> nutritionTasks = const <dynamic>[],
    Map<String, dynamic> checkinSchedule = const <String, dynamic>{},
    List<String> resourceIds = const <String>[],
  });

  Future<Map<String, dynamic>> applyOnboardingTemplate({
    required String subscriptionId,
    required String templateId,
  });

  Future<List<CoachSessionTypeEntity>> listSessionTypes();

  Future<CoachSessionTypeEntity> saveSessionType({
    String? sessionTypeId,
    required String title,
    String sessionKind = 'consultation',
    int durationMinutes = 45,
    int bufferBeforeMinutes = 0,
    int bufferAfterMinutes = 10,
    String deliveryMode = 'online',
    String? locationNote,
    int cancellationNoticeHours = 12,
    int rescheduleNoticeHours = 12,
    bool isSelfBookable = true,
  });

  Future<List<CoachBookingEntity>> listBookings({
    DateTime? from,
    DateTime? to,
    String? subscriptionId,
  });

  Future<CoachBookingEntity> createBooking({
    required String subscriptionId,
    required String sessionTypeId,
    required DateTime startsAt,
    String timezone = 'UTC',
    String? note,
  });

  Future<CoachBookingEntity> updateBookingStatus({
    required String bookingId,
    required String status,
    String? reason,
  });

  Future<List<CoachPaymentReceiptEntity>> listPaymentQueue();

  Future<CoachPaymentReceiptEntity> verifyPayment({
    required String receiptId,
    String? note,
  });

  Future<CoachPaymentReceiptEntity> failPayment({
    required String receiptId,
    required String reason,
  });

  Future<List<CoachPaymentAuditEntity>> listPaymentAuditTrail(
    String subscriptionId,
  );

  Future<String> uploadCoachResource({
    required List<int> bytes,
    required String fileName,
  });

  Future<List<CoachResourceEntity>> listCoachResources();

  Future<CoachResourceEntity> saveCoachResource({
    String? resourceId,
    required String title,
    String description = '',
    String resourceType = 'file',
    String? storagePath,
    String? externalUrl,
    List<String> tags = const <String>[],
  });

  Future<void> assignResourceToClient({
    required String subscriptionId,
    required String resourceId,
    String? note,
  });

  Future<WorkoutPlanEntity> createWorkoutPlan({
    required String memberId,
    required String source,
    required String title,
    required Map<String, dynamic> planJson,
  });

  Future<List<WorkoutPlanEntity>> listWorkoutPlans({String? memberId});

  Future<void> updateWorkoutPlanStatus({
    required String planId,
    required String status,
  });

  Future<List<SubscriptionEntity>> listSubscriptions();

  Future<List<SubscriptionEntity>> listSubscriptionRequests();

  Future<SubscriptionEntity> requestSubscription({
    required String packageId,
    CoachSubscriptionIntakeEntity intakeSnapshot =
        const CoachSubscriptionIntakeEntity(),
    String? note,
    String paymentRail = 'instapay',
  });

  Future<void> updateSubscriptionStatus({
    required String subscriptionId,
    required String newStatus,
    String? note,
  });

  Future<SubscriptionEntity> activateSubscriptionWithStarterPlan({
    required String subscriptionId,
    DateTime? startDate,
    String? reminderTime,
    String? note,
  });

  Future<List<CoachReviewEntity>> listCoachReviews(String coachId);

  Future<void> submitCoachReview({
    required String coachId,
    required String subscriptionId,
    required int rating,
    required String reviewText,
  });

  Future<CoachTaiyoClientBriefEntity> requestTaiyoCoachClientBrief({
    required String clientId,
    required String subscriptionId,
    String requestType = 'coach_client_brief',
  });
}
