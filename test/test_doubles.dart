import 'dart:async';

import 'package:my_app/core/supabase/auth_callback_ingress.dart';
import 'package:my_app/core/result/paged.dart';
import 'package:my_app/features/ai_coach/domain/entities/ai_coach_entities.dart';
import 'package:my_app/features/ai_coach/domain/repositories/ai_coach_repository.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_message_entity.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_session_entity.dart';
import 'package:my_app/features/ai_chat/domain/entities/planner_turn_result.dart';
import 'package:my_app/features/ai_chat/domain/repositories/chat_repository.dart';
import 'package:my_app/features/admin/domain/entities/admin_entities.dart';
import 'package:my_app/features/admin/domain/repositories/admin_repository.dart';
import 'package:my_app/features/auth/domain/entities/auth_session.dart';
import 'package:my_app/features/auth/domain/entities/auth_provider_type.dart';
import 'package:my_app/features/auth/domain/entities/otp_flow.dart';
import 'package:my_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_app/features/coach/domain/entities/coach_entity.dart';
import 'package:my_app/features/coach/domain/entities/coach_taiyo_entity.dart';
import 'package:my_app/features/coach/domain/entities/coach_workspace_entity.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/coach/domain/entities/workout_plan_entity.dart';
import 'package:my_app/features/coach/domain/repositories/coach_repository.dart';
import 'package:my_app/features/coach_member_insights/domain/entities/member_insight_entity.dart';
import 'package:my_app/features/coach_member_insights/domain/entities/visibility_audit_entity.dart';
import 'package:my_app/features/coach_member_insights/domain/entities/visibility_settings_entity.dart';
import 'package:my_app/features/coach_member_insights/domain/repositories/coach_member_insights_repository.dart';
import 'package:my_app/features/member/domain/entities/member_home_summary_entity.dart';
import 'package:my_app/features/member/domain/entities/coach_hub_entity.dart';
import 'package:my_app/features/member/domain/entities/coaching_engagement_entity.dart';
import 'package:my_app/features/member/domain/entities/member_profile_entity.dart';
import 'package:my_app/features/member/domain/entities/member_progress_entity.dart';
import 'package:my_app/features/member/domain/repositories/member_repository.dart';
import 'package:my_app/features/news/domain/entities/news_article.dart';
import 'package:my_app/features/news/domain/repositories/news_repository.dart';
import 'package:my_app/features/planner/domain/entities/planner_entities.dart';
import 'package:my_app/features/planner/domain/repositories/planner_repository.dart';
import 'package:my_app/features/seller/domain/entities/seller_profile_entity.dart';
import 'package:my_app/features/seller/domain/entities/seller_taiyo_entity.dart';
import 'package:my_app/features/seller/domain/repositories/seller_repository.dart';
import 'package:my_app/features/store/domain/entities/cart_entity.dart';
import 'package:my_app/features/store/domain/entities/order_entity.dart';
import 'package:my_app/features/store/domain/entities/product_entity.dart';
import 'package:my_app/features/store/domain/entities/shipping_address_entity.dart';
import 'package:my_app/features/store/domain/entities/store_recommendation_entity.dart';
import 'package:my_app/features/store/domain/repositories/store_repository.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/account_status.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';
import 'package:my_app/features/user/domain/repositories/user_repository.dart';

class FakeAuthRepository implements AuthRepository {
  AuthSession loginResult = const AuthSession.unauthenticated();
  AuthSession registerResult = const AuthSession.unauthenticated();
  AuthSession verifyOtpResult = const AuthSession.unauthenticated();
  Stream<AuthSession?> sessionStream = const Stream<AuthSession?>.empty();
  bool signInWithOAuthResult = true;
  AuthProviderType? currentProvider = AuthProviderType.emailPassword;

  Object? loginError;
  Object? registerError;
  Object? verifyOtpError;
  Object? sendOtpError;
  Object? resetPasswordError;
  Object? signInWithOAuthError;
  Object? updatePasswordError;
  Object? deleteAccountError;
  int signInWithOAuthCalls = 0;
  int logoutCalls = 0;

  set signInWithGoogleResult(bool value) => signInWithOAuthResult = value;
  bool get signInWithGoogleResult => signInWithOAuthResult;

  set signInWithGoogleError(Object? value) => signInWithOAuthError = value;
  Object? get signInWithGoogleError => signInWithOAuthError;

  int get signInWithGoogleCalls => signInWithOAuthCalls;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    return loginResult;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (registerError != null) throw registerError!;
    return registerResult;
  }

  @override
  Future<bool> signInWithOAuth({required AuthProviderType provider}) async {
    signInWithOAuthCalls++;
    if (signInWithOAuthError != null) throw signInWithOAuthError!;
    return signInWithOAuthResult;
  }

  @override
  Future<void> sendOtp({
    required String email,
    required OtpFlowMode mode,
  }) async {
    if (sendOtpError != null) throw sendOtpError!;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    if (resetPasswordError != null) throw resetPasswordError!;
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    if (updatePasswordError != null) throw updatePasswordError!;
  }

  @override
  Future<AuthProviderType?> getCurrentAuthProvider() async => currentProvider;

  @override
  Future<void> deleteAccount({String? currentPassword}) async {
    if (deleteAccountError != null) throw deleteAccountError!;
  }

  @override
  Future<AuthSession> verifyOtp({
    required String email,
    required String token,
    required OtpFlowMode mode,
  }) async {
    if (verifyOtpError != null) throw verifyOtpError!;
    return verifyOtpResult;
  }

  @override
  Stream<AuthSession?> watchSession() => sessionStream;

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

class FakeAdminRepository implements AdminRepository {
  AdminUserEntity? currentAdmin;
  AdminDashboardSummaryEntity dashboardSummary =
      const AdminDashboardSummaryEntity(
        paymentKpis: <String, num>{
          'total_paid_amount_cents': 120000,
          'payments_today': 1,
          'pending_payments': 1,
          'failed_payments': 0,
        },
        payoutKpis: <String, num>{
          'pending_coach_payouts': 1,
          'total_coach_net_payable_cents': 90000,
          'platform_fees_earned_cents': 30000,
        },
        operationalKpis: <String, num>{'hmac_failures': 0},
      );
  List<AdminPaymentOrderEntity> paymentOrders = const <AdminPaymentOrderEntity>[
    AdminPaymentOrderEntity(
      id: 'payment-1',
      memberName: 'Mona Member',
      coachName: 'Omar Coach',
      packageTitle: 'Starter Coaching',
      amountGrossCents: 120000,
      status: 'paid',
      specialReference: 'gymunity_coach_test',
    ),
    AdminPaymentOrderEntity(
      id: 'payment-2',
      memberName: 'Ali Member',
      coachName: 'Omar Coach',
      packageTitle: 'Cut Plan',
      amountGrossCents: 90000,
      status: 'failed',
    ),
  ];
  List<AdminPayoutEntity> payouts = const <AdminPayoutEntity>[
    AdminPayoutEntity(
      id: 'payout-1',
      coachId: 'coach-1',
      coachName: 'Omar Coach',
      amountCents: 90000,
      status: 'ready',
      itemCount: 1,
    ),
  ];
  List<AdminCoachBalanceEntity> coachBalances = const <AdminCoachBalanceEntity>[
    AdminCoachBalanceEntity(
      coachId: 'coach-1',
      coachName: 'Omar Coach',
      activeClientsCount: 3,
      totalPaidClientPaymentsCents: 120000,
      totalCoachNetEarnedCents: 90000,
    ),
  ];
  List<AdminSubscriptionEntity> subscriptions = const <AdminSubscriptionEntity>[
    AdminSubscriptionEntity(
      subscriptionId: 'sub-1',
      memberName: 'Mona Member',
      coachName: 'Omar Coach',
      packageTitle: 'Starter Coaching',
      status: 'active',
      checkoutStatus: 'paid',
      threadExists: false,
    ),
  ];
  List<AdminAuditEventEntity> auditEvents = const <AdminAuditEventEntity>[
    AdminAuditEventEntity(
      id: 'audit-1',
      action: 'admin_mark_payout_paid',
      targetType: 'coach_payout',
    ),
  ];
  AdminSettingsEntity settings = const AdminSettingsEntity(
    mode: 'test',
    currency: 'EGP',
    platformFeeBps: 1500,
    payoutHoldDays: 0,
    apiBaseUrl: 'https://accept.paymob.com',
    notificationUrlConfigured: true,
    redirectionUrlConfigured: true,
    testIntegrationIdsConfigured: true,
    secretKeyConfigured: true,
    hmacKeyConfigured: true,
  );
  AdminTaiyoBriefEntity taiyoBrief = const AdminTaiyoBriefEntity(
    requestType: 'admin_ops_brief',
    status: 'success',
    issueType: 'dashboard',
    statusSummary: 'Payments and payouts are stable.',
    riskLevel: 'low',
    recommendedAdminAction: '',
    actionLabel: '',
    reason: 'No urgent admin action is needed.',
    auditNotes: <String>['Sensitive data excluded.'],
    confidence: 'high',
  );
  int requestTaiyoAdminOpsBriefCalls = 0;
  String? lastTaiyoAdminRequestType;
  String? lastTaiyoAdminPaymentOrderId;
  String? lastTaiyoAdminSubscriptionId;
  String? lastTaiyoAdminPayoutId;
  int? lastTaiyoAdminLimit;
  Object? taiyoError;
  final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];

  @override
  Future<AdminUserEntity?> getCurrentAdmin() async => currentAdmin;

  @override
  Future<AdminDashboardSummaryEntity> getDashboardSummary() async =>
      dashboardSummary;

  @override
  Future<List<AdminPaymentOrderEntity>> listPaymentOrders({
    String? status,
    String? search,
    String? payoutStatus,
  }) async {
    return paymentOrders
        .where((payment) {
          final matchesStatus = status == null || payment.status == status;
          final text =
              '${payment.memberName} ${payment.coachName} '
                      '${payment.packageTitle} ${payment.specialReference ?? ''}'
                  .toLowerCase();
          final matchesSearch =
              search == null ||
              search.trim().isEmpty ||
              text.contains(search.toLowerCase());
          return matchesStatus && matchesSearch;
        })
        .toList(growable: false);
  }

  @override
  Future<AdminPaymentOrderEntity> getPaymentOrderDetails(
    String paymentOrderId,
  ) async {
    return paymentOrders.firstWhere((payment) => payment.id == paymentOrderId);
  }

  @override
  Future<List<AdminPayoutEntity>> listPayouts({
    String? status,
    String? search,
  }) async {
    return payouts
        .where((payout) => status == null || payout.status == status)
        .toList(growable: false);
  }

  @override
  Future<AdminPayoutEntity> getPayoutDetails(String payoutId) async {
    return payouts.firstWhere((payout) => payout.id == payoutId);
  }

  @override
  Future<List<AdminCoachBalanceEntity>> listCoachBalances({
    String? search,
  }) async {
    return coachBalances;
  }

  @override
  Future<List<AdminSubscriptionEntity>> listSubscriptions({
    String? status,
    String? search,
  }) async {
    return subscriptions;
  }

  @override
  Future<List<AdminAuditEventEntity>> listAuditEvents({
    String? action,
    String? targetType,
  }) async {
    return auditEvents;
  }

  @override
  Future<AdminSettingsEntity> getSettings() async => settings;

  @override
  Future<AdminTaiyoBriefEntity> requestTaiyoAdminOpsBrief({
    String requestType = 'admin_ops_brief',
    String? paymentOrderId,
    String? subscriptionId,
    String? payoutId,
    int? limit,
  }) async {
    requestTaiyoAdminOpsBriefCalls++;
    lastTaiyoAdminRequestType = requestType;
    lastTaiyoAdminPaymentOrderId = paymentOrderId;
    lastTaiyoAdminSubscriptionId = subscriptionId;
    lastTaiyoAdminPayoutId = payoutId;
    lastTaiyoAdminLimit = limit;
    if (taiyoError != null) throw taiyoError!;
    return taiyoBrief;
  }

  @override
  Future<void> markPayoutReady(String payoutId, {String? note}) async {
    calls.add({'action': 'mark_ready', 'payoutId': payoutId, 'note': note});
  }

  @override
  Future<void> holdPayout(String payoutId, {required String reason}) async {
    calls.add({'action': 'hold', 'payoutId': payoutId, 'reason': reason});
  }

  @override
  Future<void> releasePayout(String payoutId, {String? note}) async {
    calls.add({'action': 'release', 'payoutId': payoutId, 'note': note});
  }

  @override
  Future<void> markPayoutProcessing(String payoutId, {String? note}) async {
    calls.add({'action': 'processing', 'payoutId': payoutId, 'note': note});
  }

  @override
  Future<void> markPayoutPaid({
    required String payoutId,
    required String method,
    required String externalReference,
    String? adminNote,
  }) async {
    calls.add({
      'action': 'paid',
      'payoutId': payoutId,
      'method': method,
      'externalReference': externalReference,
      'adminNote': adminNote,
    });
  }

  @override
  Future<void> markPayoutFailed(
    String payoutId, {
    required String reason,
  }) async {
    calls.add({'action': 'failed', 'payoutId': payoutId, 'reason': reason});
  }

  @override
  Future<void> cancelPayout(String payoutId, {required String reason}) async {
    calls.add({'action': 'cancel', 'payoutId': payoutId, 'reason': reason});
  }

  @override
  Future<void> reconcilePaymentOrder(String paymentOrderId) async {
    calls.add({'action': 'reconcile', 'paymentOrderId': paymentOrderId});
  }

  @override
  Future<void> markPaymentNeedsReview(
    String paymentOrderId,
    String reason,
  ) async {
    calls.add({
      'action': 'needs_review',
      'paymentOrderId': paymentOrderId,
      'reason': reason,
    });
  }

  @override
  Future<void> cancelUnpaidCheckout(
    String paymentOrderId,
    String reason,
  ) async {
    calls.add({
      'action': 'cancel_checkout',
      'paymentOrderId': paymentOrderId,
      'reason': reason,
    });
  }

  @override
  Future<void> ensureSubscriptionThread(String subscriptionId) async {
    calls.add({'action': 'ensure_thread', 'subscriptionId': subscriptionId});
  }

  @override
  Future<void> verifyCoachPayoutAccount({
    required String coachId,
    required bool isVerified,
    String? note,
  }) async {
    calls.add({
      'action': 'verify_account',
      'coachId': coachId,
      'isVerified': isVerified,
      'note': note,
    });
  }
}

class FakeAuthCallbackIngress implements AuthCallbackIngress {
  Uri? pendingInitialUri;
  bool started = false;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> get uriStream => _controller.stream;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<Uri?> consumePendingInitialUri() async {
    final uri = pendingInitialUri;
    pendingInitialUri = null;
    return uri;
  }

  Future<void> emit(Uri uri) async {
    _controller.add(uri);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class FakeUserRepository implements UserRepository {
  UserEntity? currentUser;
  ProfileEntity? profile;
  AccountStatus accountStatus = AccountStatus.active;

  Object? profileError;
  Object? saveRoleError;
  Object? completeOnboardingError;

  AppRole? savedRole;
  int ensureUserCalls = 0;
  int completeOnboardingCalls = 0;

  @override
  Future<UserEntity?> getCurrentUser() async => currentUser;

  @override
  Future<AccountStatus> getAccountStatus({String? userId}) async =>
      accountStatus;

  @override
  Future<ProfileEntity?> getProfile() async {
    if (profileError != null) throw profileError!;
    return profile;
  }

  @override
  Future<void> ensureUserAndProfile({
    required String userId,
    required String email,
    String? fullName,
  }) async {
    ensureUserCalls++;
  }

  @override
  Future<void> saveRole(AppRole role) async {
    if (saveRoleError != null) throw saveRoleError!;
    savedRole = role;
  }

  @override
  Future<void> completeOnboarding() async {
    if (completeOnboardingError != null) throw completeOnboardingError!;
    completeOnboardingCalls++;
  }

  @override
  Future<void> updateProfileDetails({
    required String fullName,
    String? phone,
    String? country,
  }) async {}

  @override
  Future<String> uploadAvatar({
    required List<int> bytes,
    String extension = 'jpg',
  }) async {
    return 'avatar.$extension';
  }
}

class FakeCoachRepository implements CoachRepository {
  List<CoachEntity> coaches = const <CoachEntity>[];
  CoachWorkspaceEntity workspaceSummary = const CoachWorkspaceEntity();
  List<CoachActionItemEntity> actionItems = const <CoachActionItemEntity>[];
  List<CoachProgramTemplateEntity> programTemplates =
      const <CoachProgramTemplateEntity>[];
  List<CoachExerciseEntity> exercises = const <CoachExerciseEntity>[];
  List<CoachOnboardingTemplateEntity> onboardingTemplates =
      const <CoachOnboardingTemplateEntity>[];
  List<CoachSessionTypeEntity> sessionTypes = const <CoachSessionTypeEntity>[];
  List<CoachBookingEntity> bookings = const <CoachBookingEntity>[];
  List<CoachPaymentReceiptEntity> paymentQueue =
      const <CoachPaymentReceiptEntity>[];
  List<CoachPaymentAuditEntity> paymentAuditTrail =
      const <CoachPaymentAuditEntity>[];
  List<CoachResourceEntity> resources = const <CoachResourceEntity>[];
  List<CoachMessageEntity> coachMessages = const <CoachMessageEntity>[];
  Map<String, CoachClientWorkspaceEntity> clientWorkspaces =
      <String, CoachClientWorkspaceEntity>{};
  Object? upsertError;
  int upsertCoachProfileCalls = 0;
  int saveAvailabilitySlotCalls = 0;
  Map<String, dynamic>? lastUpsertCoachProfilePayload;
  Map<String, dynamic>? lastAvailabilitySlotPayload;
  List<CoachPackageEntity> packages = const <CoachPackageEntity>[];
  List<CoachAvailabilitySlotEntity> availability =
      const <CoachAvailabilitySlotEntity>[];
  List<CoachClientEntity> clients = const <CoachClientEntity>[];
  List<WorkoutPlanEntity> plans = const <WorkoutPlanEntity>[];
  List<SubscriptionEntity> subscriptions = const <SubscriptionEntity>[];
  List<CoachReviewEntity> reviews = const <CoachReviewEntity>[];
  SubscriptionEntity? lastRequestedSubscription;
  SubscriptionEntity? lastActivatedSubscription;
  Map<String, dynamic>? lastSavedPackagePayload;
  Map<String, dynamic>? lastSavedClientRecordPayload;
  Map<String, dynamic>? lastSavedSessionTypePayload;
  Map<String, dynamic>? lastCreatedBookingPayload;
  Map<String, dynamic>? lastUpdatedBookingPayload;
  Map<String, dynamic>? lastSavedOnboardingTemplatePayload;
  Map<String, dynamic>? lastAppliedOnboardingTemplatePayload;
  Map<String, dynamic>? lastSavedResourcePayload;
  Map<String, dynamic>? lastAssignedResourcePayload;
  Map<String, dynamic>? lastAssignedHabitsPayload;
  Map<String, dynamic>? lastAssignedProgramTemplatePayload;
  Map<String, dynamic>? lastCheckinFeedbackPayload;
  Map<String, dynamic>? lastSentCoachMessagePayload;
  Map<String, dynamic>? lastSavedProgramTemplatePayload;
  Map<String, dynamic>? lastSavedExercisePayload;

  @override
  Future<Paged<CoachEntity>> listCoaches({
    String? specialty,
    String? city,
    String? language,
    String? coachGender,
    double? maxBudget,
    String? cursor,
    int limit = 20,
  }) async {
    return Paged<CoachEntity>(items: coaches);
  }

  @override
  Future<CoachEntity?> getCoachDetails(String coachId) async {
    try {
      final coach = coaches.firstWhere((coach) => coach.id == coachId);
      final coachPackages = packages
          .where((package) => package.coachId == coachId)
          .toList(growable: false);
      if (coachPackages.isEmpty) {
        return coach;
      }
      final publishedPackages =
          coachPackages
              .where((package) => package.visibilityStatus == 'published')
              .toList(growable: true)
            ..sort((a, b) => a.price.compareTo(b.price));
      return CoachEntity(
        id: coach.id,
        name: coach.name,
        avatarPath: coach.avatarPath,
        bio: coach.bio,
        specialties: coach.specialties,
        yearsExperience: coach.yearsExperience,
        hourlyRate: coach.hourlyRate,
        pricingCurrency: coach.pricingCurrency,
        ratingAvg: coach.ratingAvg,
        ratingCount: coach.ratingCount,
        isVerified: coach.isVerified,
        city: coach.city,
        languages: coach.languages,
        coachGender: coach.coachGender,
        verificationStatus: coach.verificationStatus,
        responseSlaHours: coach.responseSlaHours,
        trialOfferEnabled: coach.trialOfferEnabled,
        trialPriceEgp: coach.trialPriceEgp,
        activeClientCount: coach.activeClientCount,
        remoteOnly: coach.remoteOnly,
        limitedSpots: coach.limitedSpots,
        testimonials: coach.testimonials,
        resultMedia: coach.resultMedia,
        headline: coach.headline,
        positioningStatement: coach.positioningStatement,
        certifications: coach.certifications,
        trustBadges: coach.trustBadges,
        faqItems: coach.faqItems,
        responseMetrics: coach.responseMetrics,
        deliveryMode: coach.deliveryMode,
        serviceSummary: coach.serviceSummary,
        startingPackagePrice: publishedPackages.isEmpty
            ? coach.startingPackagePrice
            : publishedPackages.first.price,
        startingPackageBillingCycle: publishedPackages.isEmpty
            ? coach.startingPackageBillingCycle
            : publishedPackages.first.billingCycle,
        activePackageCount: publishedPackages.isEmpty
            ? coach.activePackageCount
            : publishedPackages.length,
        packages: coachPackages,
        availability: coach.availability,
        reviews: coach.reviews,
      );
    } catch (_) {
      return null;
    }
  }

  @override
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
  }) async {
    upsertCoachProfileCalls++;
    lastUpsertCoachProfilePayload = <String, dynamic>{
      'bio': bio,
      'specialties': specialties,
      'yearsExperience': yearsExperience,
      'hourlyRate': hourlyRate,
      'deliveryMode': deliveryMode,
      'serviceSummary': serviceSummary,
      'city': city,
      'languages': languages,
      'coachGender': coachGender,
      'responseSlaHours': responseSlaHours,
      'trialOfferEnabled': trialOfferEnabled,
      'trialPriceEgp': trialPriceEgp,
      'remoteOnly': remoteOnly,
      'headline': headline,
      'positioningStatement': positioningStatement,
    };
    if (upsertError != null) throw upsertError!;
  }

  @override
  Future<List<CoachPackageEntity>> listCoachPackages({
    String? coachId,
    bool activeOnly = false,
  }) async {
    var results = packages;
    if (coachId != null) {
      results = results
          .where((package) => package.coachId == coachId)
          .toList(growable: false);
    }
    if (!activeOnly) {
      return results;
    }
    return results
        .where((package) => package.visibilityStatus == 'published')
        .toList(growable: false);
  }

  @override
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
  }) async {
    final resolvedVisibilityStatus =
        visibilityStatus ?? (isActive ? 'published' : 'draft');
    lastSavedPackagePayload = <String, dynamic>{
      'packageId': packageId,
      'title': title,
      'description': description,
      'billingCycle': billingCycle,
      'price': price,
      'subtitle': subtitle,
      'outcomeSummary': outcomeSummary,
      'idealFor': idealFor,
      'durationWeeks': durationWeeks,
      'sessionsPerWeek': sessionsPerWeek,
      'difficultyLevel': difficultyLevel,
      'equipmentTags': equipmentTags,
      'includedFeatures': includedFeatures,
      'checkInFrequency': checkInFrequency,
      'supportSummary': supportSummary,
      'faqItems': faqItems,
      'planPreviewJson': planPreviewJson,
      'visibilityStatus': resolvedVisibilityStatus,
      'isActive': resolvedVisibilityStatus == 'published' && isActive,
      'targetGoalTags': targetGoalTags,
      'locationMode': locationMode,
      'deliveryMode': deliveryMode,
      'weeklyCheckinType': weeklyCheckinType,
      'trialDays': trialDays,
      'depositAmountEgp': depositAmountEgp,
      'renewalPriceEgp': renewalPriceEgp,
      'maxSlots': maxSlots,
      'pauseAllowed': pauseAllowed,
      'paymentRails': paymentRails,
      'weeklyCheckinsIncluded': weeklyCheckinsIncluded,
      'feedbackSlaHours': feedbackSlaHours,
      'initialPlanSlaHours': initialPlanSlaHours,
      'workoutPlanIncluded': workoutPlanIncluded,
      'nutritionGuidanceIncluded': nutritionGuidanceIncluded,
      'habitsIncluded': habitsIncluded,
      'resourcesIncluded': resourcesIncluded,
      'sessionsIncluded': sessionsIncluded,
      'monthlyReviewIncluded': monthlyReviewIncluded,
      'sessionCountPerMonth': sessionCountPerMonth,
      'packageSummaryForMember': packageSummaryForMember,
    };

    final coachId = coaches.isNotEmpty ? coaches.first.id : 'coach-1';
    final savedPackage = CoachPackageEntity(
      id: packageId ?? 'package-${packages.length + 1}',
      coachId: coachId,
      title: title,
      description: description,
      billingCycle: billingCycle,
      price: price,
      subtitle: subtitle,
      outcomeSummary: outcomeSummary,
      idealFor: idealFor,
      durationWeeks: durationWeeks,
      sessionsPerWeek: sessionsPerWeek,
      difficultyLevel: difficultyLevel,
      equipmentTags: equipmentTags,
      includedFeatures: includedFeatures,
      checkInFrequency: checkInFrequency,
      supportSummary: supportSummary,
      faqItems: faqItems,
      planPreviewJson: planPreviewJson,
      visibilityStatus: resolvedVisibilityStatus,
      isActive: resolvedVisibilityStatus == 'published' && isActive,
      targetGoalTags: targetGoalTags,
      locationMode: locationMode,
      deliveryMode: deliveryMode,
      weeklyCheckinType: weeklyCheckinType,
      trialDays: trialDays,
      depositAmountEgp: depositAmountEgp,
      renewalPriceEgp: renewalPriceEgp,
      maxSlots: maxSlots,
      pauseAllowed: pauseAllowed,
      paymentRails: paymentRails,
      weeklyCheckinsIncluded: weeklyCheckinsIncluded,
      feedbackSlaHours: feedbackSlaHours,
      initialPlanSlaHours: initialPlanSlaHours,
      workoutPlanIncluded: workoutPlanIncluded,
      nutritionGuidanceIncluded: nutritionGuidanceIncluded,
      habitsIncluded: habitsIncluded,
      resourcesIncluded: resourcesIncluded,
      sessionsIncluded: sessionsIncluded,
      monthlyReviewIncluded: monthlyReviewIncluded,
      sessionCountPerMonth: sessionCountPerMonth,
      packageSummaryForMember: packageSummaryForMember,
    );

    packages = <CoachPackageEntity>[
      for (final package in packages)
        if (package.id != savedPackage.id) package,
      savedPackage,
    ];
  }

  @override
  Future<void> deleteCoachPackage(String packageId) async {
    packages = packages
        .map((package) {
          if (package.id != packageId) {
            return package;
          }
          return CoachPackageEntity(
            id: package.id,
            coachId: package.coachId,
            title: package.title,
            description: package.description,
            billingCycle: package.billingCycle,
            price: package.price,
            subtitle: package.subtitle,
            outcomeSummary: package.outcomeSummary,
            idealFor: package.idealFor,
            durationWeeks: package.durationWeeks,
            sessionsPerWeek: package.sessionsPerWeek,
            difficultyLevel: package.difficultyLevel,
            equipmentTags: package.equipmentTags,
            includedFeatures: package.includedFeatures,
            checkInFrequency: package.checkInFrequency,
            supportSummary: package.supportSummary,
            faqItems: package.faqItems,
            planPreviewJson: package.planPreviewJson,
            visibilityStatus: 'archived',
            isActive: false,
            createdAt: package.createdAt,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<CoachAvailabilitySlotEntity>> listAvailability({
    String? coachId,
  }) async {
    return availability;
  }

  @override
  Future<void> saveAvailabilitySlot({
    String? slotId,
    required int weekday,
    required String startTime,
    required String endTime,
    required String timezone,
    bool isActive = true,
  }) async {
    saveAvailabilitySlotCalls++;
    lastAvailabilitySlotPayload = <String, dynamic>{
      'slotId': slotId,
      'weekday': weekday,
      'startTime': startTime,
      'endTime': endTime,
      'timezone': timezone,
      'isActive': isActive,
    };
  }

  @override
  Future<void> deleteAvailabilitySlot(String slotId) async {}

  @override
  Future<CoachDashboardSummaryEntity> getDashboardSummary() async {
    return const CoachDashboardSummaryEntity(
      activeClients: 0,
      pendingRequests: 0,
      activePackages: 0,
      activePlans: 0,
      ratingAvg: 0,
      ratingCount: 0,
    );
  }

  @override
  Future<List<CoachClientEntity>> listClients() async => clients;

  @override
  Future<WorkoutPlanEntity> createWorkoutPlan({
    required String memberId,
    required String source,
    required String title,
    required Map<String, dynamic> planJson,
  }) async {
    return WorkoutPlanEntity(
      id: 'plan-1',
      memberId: memberId,
      coachId: 'coach-1',
      source: source,
      title: title,
      status: 'active',
      planJson: planJson,
    );
  }

  @override
  Future<List<WorkoutPlanEntity>> listWorkoutPlans({String? memberId}) async {
    return plans;
  }

  @override
  Future<void> updateWorkoutPlanStatus({
    required String planId,
    required String status,
  }) async {}

  @override
  Future<List<SubscriptionEntity>> listSubscriptions() async => subscriptions;

  @override
  Future<List<SubscriptionEntity>> listSubscriptionRequests() async =>
      subscriptions;

  @override
  Future<SubscriptionEntity> requestSubscription({
    required String packageId,
    CoachSubscriptionIntakeEntity intakeSnapshot =
        const CoachSubscriptionIntakeEntity(),
    String? note,
    String paymentRail = 'instapay',
  }) async {
    final packageTitle = packages
        .where((package) => package.id == packageId)
        .map((package) => package.title)
        .fold<String?>(
          null,
          (previousValue, element) => previousValue ?? element,
        );
    final created = SubscriptionEntity(
      id: 'subscription-1',
      memberId: 'member-1',
      coachId: 'coach-1',
      packageId: packageId,
      packageTitle: packageTitle,
      memberName: 'Member One',
      memberNote: note,
      intakeSnapshot: intakeSnapshot,
      planName: 'Starter',
      status: 'checkout_pending',
      checkoutStatus: 'checkout_pending',
      paymentMethod: paymentRail,
      amount: 100,
    );
    lastRequestedSubscription = created;
    subscriptions = <SubscriptionEntity>[created, ...subscriptions];
    return created;
  }

  @override
  Future<void> updateSubscriptionStatus({
    required String subscriptionId,
    required String newStatus,
    String? note,
  }) async {
    subscriptions = subscriptions
        .map((subscription) {
          if (subscription.id != subscriptionId) {
            return subscription;
          }
          return SubscriptionEntity(
            id: subscription.id,
            memberId: subscription.memberId,
            coachId: subscription.coachId,
            coachName: subscription.coachName,
            packageId: subscription.packageId,
            packageTitle: subscription.packageTitle,
            memberName: subscription.memberName,
            memberNote: subscription.memberNote,
            intakeSnapshot: subscription.intakeSnapshot,
            status: newStatus,
            amount: subscription.amount,
            planName: subscription.planName,
            billingCycle: subscription.billingCycle,
            paymentMethod: subscription.paymentMethod,
            startsAt: subscription.startsAt,
            endsAt: subscription.endsAt,
            activatedAt: subscription.activatedAt,
            cancelledAt: newStatus == 'cancelled' ? DateTime.now() : null,
            createdAt: subscription.createdAt,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<SubscriptionEntity> activateSubscriptionWithStarterPlan({
    required String subscriptionId,
    DateTime? startDate,
    String? reminderTime,
    String? note,
  }) async {
    final existing = subscriptions.firstWhere(
      (subscription) => subscription.id == subscriptionId,
      orElse: () => SubscriptionEntity(
        id: subscriptionId,
        memberId: 'member-1',
        coachId: 'coach-1',
        packageId: 'package-1',
        packageTitle: 'Starter',
        memberName: 'Member One',
        status: 'pending_payment',
        amount: 100,
        planName: 'Starter',
      ),
    );
    final activated = SubscriptionEntity(
      id: existing.id,
      memberId: existing.memberId,
      coachId: existing.coachId,
      coachName: existing.coachName,
      packageId: existing.packageId,
      packageTitle: existing.packageTitle,
      memberName: existing.memberName,
      memberNote: existing.memberNote,
      intakeSnapshot: existing.intakeSnapshot,
      status: 'active',
      amount: existing.amount,
      planName: existing.planName,
      billingCycle: existing.billingCycle,
      paymentMethod: existing.paymentMethod,
      startsAt: startDate,
      activatedAt: startDate ?? DateTime.now(),
      createdAt: existing.createdAt,
    );
    lastActivatedSubscription = activated;
    plans = <WorkoutPlanEntity>[
      WorkoutPlanEntity(
        id: 'plan-${plans.length + 1}',
        memberId: activated.memberId,
        coachId: activated.coachId,
        source: 'coach',
        title: activated.packageTitle ?? activated.planName,
        status: 'active',
        planJson: const <String, dynamic>{
          'title': 'Coach Starter Plan',
          'weekly_structure': <dynamic>[],
        },
      ),
      ...plans,
    ];
    subscriptions = <SubscriptionEntity>[
      activated,
      for (final subscription in subscriptions)
        if (subscription.id != subscriptionId) subscription,
    ];
    return activated;
  }

  @override
  Future<List<CoachReviewEntity>> listCoachReviews(String coachId) async =>
      reviews;

  @override
  Future<void> submitCoachReview({
    required String coachId,
    required String subscriptionId,
    required int rating,
    required String reviewText,
  }) async {}

  @override
  Future<CoachTaiyoClientBriefEntity> requestTaiyoCoachClientBrief({
    required String clientId,
    required String subscriptionId,
    String requestType = 'coach_client_brief',
  }) async {
    return CoachTaiyoClientBriefEntity(
      requestType: requestType,
      status: 'success',
      clientStatus: 'on_track',
      summary: 'Client is steady.',
      suggestedAction: 'Review the latest shared check-in.',
      riskLevel: 'low',
    );
  }

  @override
  Future<CoachWorkspaceEntity> getWorkspaceSummary() async {
    if (workspaceSummary.packagePerformance.isNotEmpty ||
        workspaceSummary.activeClients != 0 ||
        workspaceSummary.newLeads != 0 ||
        workspaceSummary.pendingPaymentVerifications != 0 ||
        workspaceSummary.atRiskClients != 0 ||
        workspaceSummary.overdueCheckins != 0 ||
        workspaceSummary.unreadMessages != 0 ||
        workspaceSummary.renewalsDueSoon != 0 ||
        workspaceSummary.todaySessions != 0 ||
        workspaceSummary.revenueMonth != 0) {
      return workspaceSummary;
    }
    return CoachWorkspaceEntity(
      activeClients: subscriptions
          .where((subscription) => subscription.status == 'active')
          .length,
      newLeads: subscriptions
          .where(
            (subscription) =>
                subscription.status == 'checkout_pending' ||
                subscription.status == 'pending_payment',
          )
          .length,
      pendingPaymentVerifications: subscriptions
          .where((subscription) => subscription.checkoutStatus == 'submitted')
          .length,
    );
  }

  @override
  Future<List<CoachActionItemEntity>> listActionItems() async {
    return actionItems;
  }

  @override
  Future<void> dismissAutomationEvent(String eventId) async {}

  @override
  Future<List<CoachClientPipelineEntry>> listClientPipeline(
    CoachClientPipelineFilter filter,
  ) async {
    return subscriptions
        .map((subscription) {
          final stage = switch (subscription.status) {
            'checkout_pending' || 'pending_payment' => 'pending_payment',
            'paused' => 'paused',
            'completed' || 'cancelled' => 'archived',
            _ => 'active',
          };
          return CoachClientPipelineEntry(
            subscriptionId: subscription.id,
            memberId: subscription.memberId,
            memberName: subscription.memberName ?? 'Member One',
            packageId: subscription.packageId,
            packageTitle: subscription.displayTitle,
            status: subscription.status,
            checkoutStatus: subscription.checkoutStatus,
            billingCycle: subscription.billingCycle,
            amount: subscription.amount,
            pipelineStage: stage,
            internalStatus: 'active',
            riskStatus: 'none',
            startedAt: subscription.startsAt ?? subscription.createdAt,
            nextRenewalAt: subscription.nextRenewalAt,
          );
        })
        .where((entry) {
          return filter.pipelineStage == null ||
              filter.pipelineStage == entry.pipelineStage;
        })
        .toList(growable: false);
  }

  @override
  Future<CoachClientWorkspaceEntity> getClientWorkspace(
    String subscriptionId,
  ) async {
    final direct = clientWorkspaces[subscriptionId];
    if (direct != null) {
      return direct;
    }
    final client = (await listClientPipeline(
      const CoachClientPipelineFilter(),
    )).firstWhere((entry) => entry.subscriptionId == subscriptionId);
    return CoachClientWorkspaceEntity(client: client);
  }

  @override
  Future<void> saveClientRecord({
    required String subscriptionId,
    String? pipelineStage,
    String? internalStatus,
    String? riskStatus,
    List<String>? tags,
    String? coachNotes,
    String? preferredLanguage,
    DateTime? followUpAt,
  }) async {
    lastSavedClientRecordPayload = <String, dynamic>{
      'subscriptionId': subscriptionId,
      'pipelineStage': pipelineStage,
      'internalStatus': internalStatus,
      'riskStatus': riskStatus,
      'tags': tags,
      'coachNotes': coachNotes,
      'preferredLanguage': preferredLanguage,
      'followUpAt': followUpAt,
    };
  }

  @override
  Future<CoachClientNoteEntity> addClientNote({
    required String subscriptionId,
    required String note,
    String noteType = 'general',
    bool isPinned = false,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    return CoachClientNoteEntity(
      id: 'note-1',
      subscriptionId: subscriptionId,
      memberId: 'member-1',
      note: note,
      noteType: noteType,
      isPinned: isPinned,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<CoachThreadEntity>> listCoachThreads() async {
    return const <CoachThreadEntity>[];
  }

  @override
  Future<List<CoachMessageEntity>> listCoachMessages(String threadId) async {
    return coachMessages
        .where((message) => message.threadId == threadId)
        .toList(growable: false);
  }

  @override
  Future<void> sendCoachMessage({
    required String threadId,
    required String content,
  }) async {
    lastSentCoachMessagePayload = <String, dynamic>{
      'threadId': threadId,
      'content': content,
    };
    coachMessages = <CoachMessageEntity>[
      ...coachMessages,
      CoachMessageEntity(
        id: 'coach-message-${coachMessages.length + 1}',
        threadId: threadId,
        senderUserId: 'coach-1',
        senderRole: 'coach',
        content: content,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<void> markThreadRead(String threadId) async {}

  @override
  Future<List<WeeklyCheckinEntity>> listCheckinInbox() async {
    return const <WeeklyCheckinEntity>[];
  }

  @override
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
  }) async {
    lastCheckinFeedbackPayload = <String, dynamic>{
      'checkinId': checkinId,
      'threadId': threadId,
      'feedback': feedback,
      'whatWentWell': whatWentWell,
      'whatNeedsAttention': whatNeedsAttention,
      'adjustmentForNextWeek': adjustmentForNextWeek,
      'onePriority': onePriority,
      'coachNote': coachNote,
      'planChangesSummary': planChangesSummary,
      'nextCheckinDate': nextCheckinDate,
    };
  }

  @override
  Future<List<CoachProgramTemplateEntity>> listProgramTemplates() async {
    return programTemplates;
  }

  @override
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
  }) async {
    final template = CoachProgramTemplateEntity(
      id: templateId ?? 'program-template-1',
      title: title,
      goalType: goalType,
      description: description,
      durationWeeks: durationWeeks,
      difficultyLevel: difficultyLevel,
      locationMode: locationMode,
      weeklyStructureJson: weeklyStructure,
      tags: tags,
    );
    lastSavedProgramTemplatePayload = <String, dynamic>{
      'templateId': templateId,
      'title': title,
      'goalType': goalType,
      'description': description,
      'durationWeeks': durationWeeks,
      'difficultyLevel': difficultyLevel,
      'locationMode': locationMode,
      'weeklyStructure': weeklyStructure,
      'tags': tags,
    };
    programTemplates = <CoachProgramTemplateEntity>[
      ...programTemplates,
      template,
    ];
    return template;
  }

  @override
  Future<void> assignProgramTemplate({
    required String subscriptionId,
    required String templateId,
    DateTime? startDate,
    String? defaultReminderTime,
  }) async {
    lastAssignedProgramTemplatePayload = <String, dynamic>{
      'subscriptionId': subscriptionId,
      'templateId': templateId,
      'startDate': startDate,
      'defaultReminderTime': defaultReminderTime,
    };
  }

  @override
  Future<List<CoachExerciseEntity>> listExercises() async {
    return exercises;
  }

  @override
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
  }) async {
    final exercise = CoachExerciseEntity(
      id: exerciseId ?? 'exercise-1',
      title: title,
      category: category,
      primaryMuscles: primaryMuscles,
      equipmentTags: equipmentTags,
      difficultyLevel: difficultyLevel,
      instructions: instructions,
      videoUrl: videoUrl,
      progressionRule: progressionRule,
      regressionRule: regressionRule,
      restGuidanceSeconds: restGuidanceSeconds,
    );
    lastSavedExercisePayload = <String, dynamic>{
      'exerciseId': exerciseId,
      'title': title,
      'category': category,
      'primaryMuscles': primaryMuscles,
      'equipmentTags': equipmentTags,
      'difficultyLevel': difficultyLevel,
      'instructions': instructions,
      'videoUrl': videoUrl,
      'substitutions': substitutions,
      'progressionRule': progressionRule,
      'regressionRule': regressionRule,
      'restGuidanceSeconds': restGuidanceSeconds,
      'cues': cues,
    };
    exercises = <CoachExerciseEntity>[...exercises, exercise];
    return exercise;
  }

  @override
  Future<List<CoachHabitAssignmentEntity>> assignHabits({
    required String subscriptionId,
    required List<Map<String, dynamic>> habits,
  }) async {
    lastAssignedHabitsPayload = <String, dynamic>{
      'subscriptionId': subscriptionId,
      'habits': habits,
    };
    return const <CoachHabitAssignmentEntity>[];
  }

  @override
  Future<List<CoachOnboardingTemplateEntity>> listOnboardingTemplates() async {
    return onboardingTemplates;
  }

  @override
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
  }) async {
    final template = CoachOnboardingTemplateEntity(
      id: templateId ?? 'onboarding-1',
      title: title,
      clientType: clientType,
      description: description,
      welcomeMessage: welcomeMessage,
      starterProgramTemplateId: starterProgramTemplateId,
      resourceIds: resourceIds,
      habitTemplates: habitTemplates,
    );
    lastSavedOnboardingTemplatePayload = <String, dynamic>{
      'templateId': templateId,
      'title': title,
      'clientType': clientType,
      'description': description,
      'welcomeMessage': welcomeMessage,
      'intakeForm': intakeForm,
      'goalsQuestionnaire': goalsQuestionnaire,
      'starterProgramTemplateId': starterProgramTemplateId,
      'habitTemplates': habitTemplates,
      'nutritionTasks': nutritionTasks,
      'checkinSchedule': checkinSchedule,
      'resourceIds': resourceIds,
    };
    onboardingTemplates = <CoachOnboardingTemplateEntity>[
      ...onboardingTemplates,
      template,
    ];
    return template;
  }

  @override
  Future<Map<String, dynamic>> applyOnboardingTemplate({
    required String subscriptionId,
    required String templateId,
  }) async {
    lastAppliedOnboardingTemplatePayload = <String, dynamic>{
      'subscription_id': subscriptionId,
      'template_id': templateId,
    };
    return lastAppliedOnboardingTemplatePayload!;
  }

  @override
  Future<List<CoachSessionTypeEntity>> listSessionTypes() async {
    return sessionTypes;
  }

  @override
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
  }) async {
    final sessionType = CoachSessionTypeEntity(
      id: sessionTypeId ?? 'session-type-1',
      title: title,
      sessionKind: sessionKind,
      durationMinutes: durationMinutes,
      deliveryMode: deliveryMode,
      isSelfBookable: isSelfBookable,
    );
    lastSavedSessionTypePayload = <String, dynamic>{
      'sessionTypeId': sessionTypeId,
      'title': title,
      'sessionKind': sessionKind,
      'durationMinutes': durationMinutes,
      'bufferBeforeMinutes': bufferBeforeMinutes,
      'bufferAfterMinutes': bufferAfterMinutes,
      'deliveryMode': deliveryMode,
      'locationNote': locationNote,
      'cancellationNoticeHours': cancellationNoticeHours,
      'rescheduleNoticeHours': rescheduleNoticeHours,
      'isSelfBookable': isSelfBookable,
    };
    sessionTypes = <CoachSessionTypeEntity>[...sessionTypes, sessionType];
    return sessionType;
  }

  @override
  Future<List<CoachBookingEntity>> listBookings({
    DateTime? from,
    DateTime? to,
    String? subscriptionId,
  }) async {
    return bookings;
  }

  @override
  Future<CoachBookingEntity> createBooking({
    required String subscriptionId,
    required String sessionTypeId,
    required DateTime startsAt,
    String timezone = 'UTC',
    String? note,
  }) async {
    lastCreatedBookingPayload = <String, dynamic>{
      'subscriptionId': subscriptionId,
      'sessionTypeId': sessionTypeId,
      'startsAt': startsAt,
      'timezone': timezone,
      'note': note,
    };
    final booking = CoachBookingEntity(
      id: 'booking-1',
      coachId: 'coach-1',
      memberId: 'member-1',
      subscriptionId: subscriptionId,
      sessionTypeId: sessionTypeId,
      title: 'Session',
      startsAt: startsAt,
      endsAt: startsAt.add(const Duration(minutes: 45)),
      timezone: timezone,
    );
    bookings = <CoachBookingEntity>[...bookings, booking];
    return booking;
  }

  @override
  Future<CoachBookingEntity> updateBookingStatus({
    required String bookingId,
    required String status,
    String? reason,
  }) async {
    lastUpdatedBookingPayload = <String, dynamic>{
      'bookingId': bookingId,
      'status': status,
      'reason': reason,
    };
    return CoachBookingEntity(
      id: bookingId,
      coachId: 'coach-1',
      memberId: 'member-1',
      title: 'Session',
      startsAt: DateTime.now(),
      endsAt: DateTime.now().add(const Duration(minutes: 45)),
      status: status,
    );
  }

  @override
  Future<List<CoachPaymentReceiptEntity>> listPaymentQueue() async {
    return paymentQueue;
  }

  @override
  Future<CoachPaymentReceiptEntity> verifyPayment({
    required String receiptId,
    String? note,
  }) async {
    return CoachPaymentReceiptEntity(
      id: receiptId,
      subscriptionId: 'subscription-1',
      memberId: 'member-1',
      status: 'activated',
      billingState: 'activated',
    );
  }

  @override
  Future<CoachPaymentReceiptEntity> failPayment({
    required String receiptId,
    required String reason,
  }) async {
    return CoachPaymentReceiptEntity(
      id: receiptId,
      subscriptionId: 'subscription-1',
      memberId: 'member-1',
      status: 'failed',
      billingState: 'failed_needs_follow_up',
      failureReason: reason,
    );
  }

  @override
  Future<List<CoachPaymentAuditEntity>> listPaymentAuditTrail(
    String subscriptionId,
  ) async {
    return paymentAuditTrail;
  }

  @override
  Future<String> uploadCoachResource({
    required List<int> bytes,
    required String fileName,
  }) async {
    return 'coach-1/$fileName';
  }

  @override
  Future<List<CoachResourceEntity>> listCoachResources() async {
    return resources;
  }

  @override
  Future<CoachResourceEntity> saveCoachResource({
    String? resourceId,
    required String title,
    String description = '',
    String resourceType = 'file',
    String? storagePath,
    String? externalUrl,
    List<String> tags = const <String>[],
  }) async {
    final resource = CoachResourceEntity(
      id: resourceId ?? 'resource-1',
      title: title,
      description: description,
      resourceType: resourceType,
      storagePath: storagePath,
      externalUrl: externalUrl,
      tags: tags,
    );
    lastSavedResourcePayload = <String, dynamic>{
      'resourceId': resourceId,
      'title': title,
      'description': description,
      'resourceType': resourceType,
      'storagePath': storagePath,
      'externalUrl': externalUrl,
      'tags': tags,
    };
    resources = <CoachResourceEntity>[...resources, resource];
    return resource;
  }

  @override
  Future<void> assignResourceToClient({
    required String subscriptionId,
    required String resourceId,
    String? note,
  }) async {
    lastAssignedResourcePayload = <String, dynamic>{
      'subscriptionId': subscriptionId,
      'resourceId': resourceId,
      'note': note,
    };
  }
}

class FakeMemberRepository implements MemberRepository {
  MemberProfileEntity? profile;
  UserPreferencesEntity preferences = const UserPreferencesEntity();
  List<WeightEntryEntity> weightEntries = const <WeightEntryEntity>[];
  List<BodyMeasurementEntity> measurements = const <BodyMeasurementEntity>[];
  List<WorkoutPlanEntity> workoutPlans = const <WorkoutPlanEntity>[];
  List<WorkoutSessionEntity> workoutSessions = const <WorkoutSessionEntity>[];
  List<SubscriptionEntity> subscriptions = const <SubscriptionEntity>[];
  List<WeeklyCheckinEntity> weeklyCheckins = const <WeeklyCheckinEntity>[];
  List<MemberCoachAgendaItemEntity> coachAgenda =
      const <MemberCoachAgendaItemEntity>[];
  List<MemberAssignedHabitEntity> assignedHabits =
      const <MemberAssignedHabitEntity>[];
  List<MemberAssignedResourceEntity> assignedResources =
      const <MemberAssignedResourceEntity>[];
  List<CoachSessionTypeEntity> bookableSessionTypes =
      const <CoachSessionTypeEntity>[];
  List<MemberBookableSlotEntity> bookableSlots =
      const <MemberBookableSlotEntity>[];
  List<CoachBookingEntity> coachBookings = const <CoachBookingEntity>[];
  List<CoachingMessageEntity> coachingMessages =
      const <CoachingMessageEntity>[];
  List<OrderEntity> orders = const <OrderEntity>[];
  MemberHomeSummaryEntity homeSummary = const MemberHomeSummaryEntity();
  Map<String, dynamic>? lastSentCoachingMessagePayload;

  Object? upsertError;
  Object? homeSummaryError;
  int homeSummaryRequests = 0;

  @override
  Future<MemberProfileEntity?> getMemberProfile() async => profile;

  @override
  Future<void> upsertMemberProfile({
    required String goal,
    required int age,
    required String gender,
    required double heightCm,
    required double currentWeightKg,
    required String trainingFrequency,
    required String experienceLevel,
    int? budgetEgp,
    String? city,
    String? coachingPreference,
    String? trainingPlace,
    String? preferredLanguage,
    String? preferredCoachGender,
  }) async {
    if (upsertError != null) {
      throw upsertError!;
    }

    profile = MemberProfileEntity(
      userId: 'member-1',
      goal: goal,
      age: age,
      gender: gender,
      heightCm: heightCm,
      currentWeightKg: currentWeightKg,
      trainingFrequency: trainingFrequency,
      experienceLevel: experienceLevel,
      budgetEgp: budgetEgp,
      city: city,
      coachingPreference: coachingPreference,
      trainingPlace: trainingPlace,
      preferredLanguage: preferredLanguage,
      preferredCoachGender: preferredCoachGender,
    );
  }

  @override
  Future<UserPreferencesEntity> getPreferences() async => preferences;

  @override
  Future<void> upsertPreferences(UserPreferencesEntity preferences) async {
    this.preferences = preferences;
  }

  @override
  Future<List<WeightEntryEntity>> listWeightEntries() async => weightEntries;

  @override
  Future<void> saveWeightEntry({
    String? entryId,
    required double weightKg,
    required DateTime recordedAt,
    String? note,
  }) async {}

  @override
  Future<void> deleteWeightEntry(String entryId) async {}

  @override
  Future<List<BodyMeasurementEntity>> listBodyMeasurements() async =>
      measurements;

  @override
  Future<void> saveBodyMeasurement({
    String? entryId,
    required DateTime recordedAt,
    double? waistCm,
    double? chestCm,
    double? hipsCm,
    double? armCm,
    double? thighCm,
    double? bodyFatPercent,
    String? note,
  }) async {}

  @override
  Future<void> deleteBodyMeasurement(String entryId) async {}

  @override
  Future<List<WorkoutPlanEntity>> listWorkoutPlans() async => workoutPlans;

  @override
  Future<List<WorkoutSessionEntity>> listWorkoutSessions() async =>
      workoutSessions;

  @override
  Future<void> saveWorkoutSession({
    String? sessionId,
    required String title,
    required DateTime performedAt,
    required int durationMinutes,
    String? workoutPlanId,
    String? coachId,
    String? note,
  }) async {}

  @override
  Future<void> deleteWorkoutSession(String sessionId) async {}

  @override
  Future<List<SubscriptionEntity>> listSubscriptions() async => subscriptions;

  @override
  Future<SubscriptionEntity> confirmCoachPayment({
    required String subscriptionId,
    String? paymentReference,
  }) async {
    final existing = subscriptions.firstWhere(
      (item) => item.id == subscriptionId,
    );
    final updated = existing.copyWith(
      status: 'active',
      checkoutStatus: 'paid',
      activatedAt: DateTime.now(),
      paymentMethod: existing.paymentMethod,
      threadId: existing.threadId ?? 'thread-1',
    );
    subscriptions = <SubscriptionEntity>[
      updated,
      for (final subscription in subscriptions)
        if (subscription.id != subscriptionId) subscription,
    ];
    return updated;
  }

  @override
  Future<String> uploadCoachPaymentReceipt({
    required String subscriptionId,
    required List<int> bytes,
    required String fileName,
  }) async {
    return 'member-1/$subscriptionId/$fileName';
  }

  @override
  Future<void> submitCoachPaymentReceipt({
    required String subscriptionId,
    String? paymentReference,
    String? receiptStoragePath,
    double? amount,
  }) async {
    final existing = subscriptions.firstWhere(
      (item) => item.id == subscriptionId,
    );
    final updated = existing.copyWith(checkoutStatus: 'submitted');
    subscriptions = <SubscriptionEntity>[
      updated,
      for (final subscription in subscriptions)
        if (subscription.id != subscriptionId) subscription,
    ];
  }

  @override
  Future<SubscriptionEntity> pauseSubscription({
    required String subscriptionId,
    bool pauseNow = true,
  }) async {
    final existing = subscriptions.firstWhere(
      (item) => item.id == subscriptionId,
    );
    final updated = existing.copyWith(
      status: pauseNow ? 'paused' : 'active',
      pausedAt: pauseNow ? DateTime.now() : null,
    );
    subscriptions = <SubscriptionEntity>[
      updated,
      for (final subscription in subscriptions)
        if (subscription.id != subscriptionId) subscription,
    ];
    return updated;
  }

  @override
  Future<List<CoachingThreadEntity>> listCoachingThreads() async {
    return subscriptions
        .where((subscription) => subscription.threadId != null)
        .map(
          (subscription) => CoachingThreadEntity(
            id: subscription.threadId!,
            subscriptionId: subscription.id,
            memberId: subscription.memberId,
            coachId: subscription.coachId,
            coachName: subscription.coachName,
            packageTitle: subscription.displayTitle,
            subscriptionStatus: subscription.status,
            lastMessagePreview: 'Your coaching thread is ready.',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CoachingMessageEntity>> listCoachingMessages(
    String threadId,
  ) async {
    final messages = coachingMessages
        .where((message) => message.threadId == threadId)
        .toList(growable: false);
    if (messages.isNotEmpty) {
      return messages;
    }
    return <CoachingMessageEntity>[
      CoachingMessageEntity(
        id: 'message-1',
        threadId: threadId,
        senderUserId: 'coach-1',
        senderRole: 'system',
        messageType: 'system',
        content: 'Your coaching thread is ready.',
        createdAt: DateTime(2026, 3, 18),
      ),
    ];
  }

  @override
  Future<void> sendCoachingMessage({
    required String threadId,
    required String content,
  }) async {
    lastSentCoachingMessagePayload = <String, dynamic>{
      'threadId': threadId,
      'content': content,
    };
    coachingMessages = <CoachingMessageEntity>[
      ...coachingMessages,
      CoachingMessageEntity(
        id: 'member-message-${coachingMessages.length + 1}',
        threadId: threadId,
        senderUserId: 'member-1',
        senderRole: 'member',
        content: content,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<WeeklyCheckinEntity>> listWeeklyCheckins({
    String? subscriptionId,
  }) async {
    if (subscriptionId == null || subscriptionId.isEmpty) {
      return weeklyCheckins;
    }
    return weeklyCheckins
        .where((checkin) => checkin.subscriptionId == subscriptionId)
        .toList(growable: false);
  }

  @override
  Future<WeeklyCheckinEntity> submitWeeklyCheckin({
    required String subscriptionId,
    required DateTime weekStart,
    double? weightKg,
    double? waistCm,
    int adherenceScore = 0,
    int? energyScore,
    int? sleepScore,
    String? wins,
    String? blockers,
    String? questions,
    List<Map<String, dynamic>> photos = const <Map<String, dynamic>>[],
    int? workoutsCompleted,
    int? missedWorkouts,
    String? missedWorkoutsReason,
    int? sorenessScore,
    int? fatigueScore,
    String? painWarning,
    int? nutritionAdherenceScore,
    int? habitAdherenceScore,
    String? biggestObstacle,
    String? supportNeeded,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    return WeeklyCheckinEntity(
      id: 'checkin-1',
      subscriptionId: subscriptionId,
      memberId: 'member-1',
      coachId: 'coach-1',
      weekStart: weekStart,
      weightKg: weightKg,
      waistCm: waistCm,
      adherenceScore: adherenceScore,
      wins: wins,
      blockers: blockers,
      questions: questions,
      workoutsCompleted: workoutsCompleted,
      missedWorkouts: missedWorkouts,
      missedWorkoutsReason: missedWorkoutsReason,
      sorenessScore: sorenessScore,
      fatigueScore: fatigueScore,
      painWarning: painWarning,
      nutritionAdherenceScore: nutritionAdherenceScore,
      habitAdherenceScore: habitAdherenceScore,
      biggestObstacle: biggestObstacle,
      supportNeeded: supportNeeded,
      checkinMetadata: metadata,
    );
  }

  @override
  Future<List<OrderEntity>> listOrders() async => orders;

  @override
  Future<MemberDailyStreakEntity> recordDailyActivity({
    DateTime? occurredAt,
    String source = 'app_open',
  }) async {
    if (homeSummaryError != null) {
      throw homeSummaryError!;
    }
    return homeSummary.dailyStreak;
  }

  @override
  Future<MemberHomeSummaryEntity> getHomeSummary() async {
    homeSummaryRequests += 1;
    if (homeSummaryError != null) {
      throw homeSummaryError!;
    }
    return homeSummary;
  }

  @override
  Future<MemberCoachHubEntity> getCoachHub({String? subscriptionId}) async {
    SubscriptionEntity? subscription;
    for (final item in subscriptions) {
      if (subscriptionId == null || item.id == subscriptionId) {
        subscription = item;
        break;
      }
    }
    if (subscription == null) {
      return const MemberCoachHubEntity();
    }
    return MemberCoachHubEntity(
      subscription: MemberCoachSubscriptionSummaryEntity(
        id: subscription.id,
        memberId: subscription.memberId,
        coachId: subscription.coachId,
        coachName: subscription.coachName ?? 'Coach',
        packageId: subscription.packageId,
        packageTitle: subscription.displayTitle,
        planName: subscription.planName,
        status: subscription.status,
        checkoutStatus: subscription.checkoutStatus,
        billingCycle: subscription.billingCycle,
        amount: subscription.amount,
        currency: subscription.currency,
        activatedAt: subscription.activatedAt,
        nextRenewalAt: subscription.nextRenewalAt,
        threadId: subscription.threadId,
      ),
      relationshipStage: subscription.status == 'active'
          ? 'in_weekly_coaching'
          : '${subscription.status}_readonly',
      todayAgenda: coachAgenda,
      weekAgenda: coachAgenda,
      habits: assignedHabits,
      resources: assignedResources,
      bookings: coachBookings,
    );
  }

  @override
  Future<List<MemberCoachAgendaItemEntity>> listCoachAgenda({
    required String subscriptionId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    return coachAgenda
        .where((item) => item.subscriptionId == subscriptionId)
        .toList(growable: false);
  }

  @override
  Future<MemberCoachKickoffEntity> submitCoachKickoff({
    required String subscriptionId,
    required String primaryGoal,
    required String trainingLevel,
    required List<String> preferredTrainingDays,
    required List<String> availableEquipment,
    required String injuriesLimitations,
    required String scheduleConstraints,
    required String nutritionSituation,
    required String sleepRecoveryNotes,
    required String biggestObstacle,
    required String coachExpectations,
    String memberNote = '',
    bool shareProgressSummary = true,
    bool shareNutritionSummary = false,
    bool shareAiSummary = false,
    bool shareWorkoutAdherence = true,
    bool shareProductContext = false,
  }) async {
    return MemberCoachKickoffEntity(
      id: 'kickoff-1',
      subscriptionId: subscriptionId,
      coachId: 'coach-1',
      memberId: 'member-1',
      primaryGoal: primaryGoal,
      trainingLevel: trainingLevel,
      preferredTrainingDays: preferredTrainingDays,
      availableEquipment: availableEquipment,
      injuriesLimitations: injuriesLimitations,
      scheduleConstraints: scheduleConstraints,
      nutritionSituation: nutritionSituation,
      sleepRecoveryNotes: sleepRecoveryNotes,
      biggestObstacle: biggestObstacle,
      coachExpectations: coachExpectations,
      memberNote: memberNote,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<List<MemberAssignedHabitEntity>> listAssignedHabits({
    String? subscriptionId,
    DateTime? date,
  }) async {
    return assignedHabits
        .where(
          (item) =>
              subscriptionId == null || item.subscriptionId == subscriptionId,
        )
        .toList(growable: false);
  }

  @override
  Future<MemberAssignedHabitEntity?> logAssignedHabit({
    required String assignmentId,
    required String completionStatus,
    DateTime? logDate,
    double? value,
    String? note,
  }) async {
    for (final item in assignedHabits) {
      if (item.id == assignmentId) return item;
    }
    return null;
  }

  @override
  Future<List<MemberAssignedResourceEntity>> listAssignedResources({
    String? subscriptionId,
  }) async {
    return assignedResources
        .where(
          (item) =>
              subscriptionId == null || item.subscriptionId == subscriptionId,
        )
        .toList(growable: false);
  }

  @override
  Future<MemberAssignedResourceEntity?> markResourceProgress({
    required String assignmentId,
    bool markViewed = true,
    bool markCompleted = false,
    String? memberNote,
  }) async {
    for (final item in assignedResources) {
      if (item.id == assignmentId) return item;
    }
    return null;
  }

  @override
  Future<String> createCoachResourceSignedUrl(String storagePath) async {
    return 'https://example.test/$storagePath';
  }

  @override
  Future<List<CoachSessionTypeEntity>> listBookableSessionTypes({
    required String subscriptionId,
  }) async {
    return bookableSessionTypes;
  }

  @override
  Future<List<MemberBookableSlotEntity>> listBookableSlots({
    required String coachId,
    required String sessionTypeId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    return bookableSlots;
  }

  @override
  Future<List<CoachBookingEntity>> listMemberBookings({
    required String subscriptionId,
    DateTime? from,
    DateTime? to,
  }) async {
    return coachBookings
        .where((item) => item.subscriptionId == subscriptionId)
        .toList(growable: false);
  }

  @override
  Future<CoachBookingEntity> createMemberBooking({
    required String subscriptionId,
    required String sessionTypeId,
    required DateTime startsAt,
    String timezone = 'UTC',
    String? note,
  }) async {
    final subscription = subscriptions.firstWhere(
      (item) => item.id == subscriptionId,
    );
    final booking = CoachBookingEntity(
      id: 'booking-${coachBookings.length + 1}',
      coachId: subscription.coachId,
      memberId: subscription.memberId,
      subscriptionId: subscription.id,
      sessionTypeId: sessionTypeId,
      title: 'Session',
      startsAt: startsAt,
      endsAt: startsAt.add(const Duration(minutes: 45)),
      timezone: timezone,
    );
    coachBookings = <CoachBookingEntity>[booking, ...coachBookings];
    return booking;
  }

  @override
  Future<CoachBookingEntity> updateMemberBookingStatus({
    required String bookingId,
    required String status,
    String? reason,
  }) async {
    return coachBookings.firstWhere((item) => item.id == bookingId);
  }
}

class FakeStoreRepository implements StoreRepository {
  List<ProductEntity> products = const <ProductEntity>[];
  List<OrderEntity> orders = const <OrderEntity>[];
  final Set<String> favoriteIds = <String>{};
  final Map<String, int> _cartQuantities = <String, int>{};
  final List<ShippingAddressEntity> _addresses = <ShippingAddressEntity>[];
  StoreRecommendationsEntity taiyoRecommendations =
      const StoreRecommendationsEntity(
        status: 'success',
        recommendationType: 'fitness_support',
        reason: 'TAIYO matched products to current context.',
        products: <StoreRecommendationProductEntity>[],
        disclaimer:
            'Recommendations are based on fitness context, not medical advice.',
      );
  int _addressCounter = 0;

  @override
  Future<Paged<ProductEntity>> listProducts({
    String? category,
    String? cursor,
    int limit = 20,
  }) async {
    final filtered = category == null || category == 'All'
        ? products
        : products
              .where((product) => product.category == category)
              .toList(growable: false);
    return Paged<ProductEntity>(items: filtered);
  }

  @override
  Future<ProductEntity?> getProductById(String productId) async {
    try {
      return products.firstWhere((product) => product.id == productId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CartEntity> getCart() async {
    final items = _cartQuantities.entries
        .map((entry) {
          final product = products.firstWhere(
            (candidate) => candidate.id == entry.key,
            orElse: () => ProductEntity(
              id: entry.key,
              sellerId: 'seller-1',
              name: 'Unavailable product',
              description: '',
              category: 'Unavailable',
              price: 0,
              stockQty: 0,
              isActive: false,
            ),
          );
          return CartItemEntity(
            id: 'cart-item-${entry.key}',
            cartId: 'cart-1',
            productId: entry.key,
            product: product,
            quantity: entry.value,
          );
        })
        .toList(growable: false);

    return CartEntity(id: 'cart-1', memberId: 'member-1', items: items);
  }

  @override
  Future<CartEntity> addToCart({
    required ProductEntity product,
    int quantity = 1,
  }) async {
    _cartQuantities.update(
      product.id,
      (value) => value + quantity,
      ifAbsent: () => quantity,
    );
    return getCart();
  }

  @override
  Future<CartEntity> updateCartQuantity({
    required String productId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      _cartQuantities.remove(productId);
    } else {
      _cartQuantities[productId] = quantity;
    }
    return getCart();
  }

  @override
  Future<CartEntity> removeCartItem(String productId) async {
    _cartQuantities.remove(productId);
    return getCart();
  }

  @override
  Future<CartEntity> clearInvalidCartItems() async {
    _cartQuantities.removeWhere((productId, quantity) {
      final product = products.firstWhere(
        (candidate) => candidate.id == productId,
        orElse: () => ProductEntity(
          id: productId,
          sellerId: 'seller-1',
          name: 'Unavailable product',
          description: '',
          category: 'Unavailable',
          price: 0,
          stockQty: 0,
          isActive: false,
        ),
      );
      if (!product.isAvailable) {
        return true;
      }
      if (quantity > product.stockQty) {
        _cartQuantities[productId] = product.stockQty;
      }
      return false;
    });
    return getCart();
  }

  @override
  Future<Set<String>> getFavoriteIds() async => favoriteIds;

  @override
  Future<List<ProductEntity>> getFavoriteProducts() async {
    return products
        .where((product) => favoriteIds.contains(product.id))
        .toList(growable: false);
  }

  @override
  Future<bool> toggleFavorite(ProductEntity product) async {
    if (favoriteIds.contains(product.id)) {
      favoriteIds.remove(product.id);
      return false;
    }
    favoriteIds.add(product.id);
    return true;
  }

  @override
  Future<List<ShippingAddressEntity>> listShippingAddresses() async {
    return List<ShippingAddressEntity>.from(_addresses);
  }

  @override
  Future<ShippingAddressEntity> saveShippingAddress(
    ShippingAddressEntity address,
  ) async {
    final shouldBeDefault = address.isDefault || _addresses.isEmpty;
    if (shouldBeDefault) {
      for (var index = 0; index < _addresses.length; index++) {
        _addresses[index] = _addresses[index].copyWith(isDefault: false);
      }
    }

    final saved = address.copyWith(
      id: address.id.isEmpty ? 'address-${++_addressCounter}' : address.id,
      userId: 'member-1',
      isDefault: shouldBeDefault,
    );

    final existingIndex = _addresses.indexWhere((item) => item.id == saved.id);
    if (existingIndex >= 0) {
      _addresses[existingIndex] = saved;
    } else {
      _addresses.add(saved);
    }

    return saved;
  }

  @override
  Future<void> deleteShippingAddress(String addressId) async {
    _addresses.removeWhere((address) => address.id == addressId);
  }

  @override
  Future<List<ShippingAddressEntity>> setDefaultShippingAddress(
    String addressId,
  ) async {
    for (var index = 0; index < _addresses.length; index++) {
      _addresses[index] = _addresses[index].copyWith(
        isDefault: _addresses[index].id == addressId,
      );
    }
    return listShippingAddresses();
  }

  @override
  Future<List<OrderEntity>> placeOrderFromCart({
    required String addressId,
    required String idempotencyKey,
  }) async {
    final cart = await getCart();
    final order = OrderEntity(
      id: 'order-${orders.length + 1}',
      memberId: 'member-1',
      sellerId: cart.items.isNotEmpty
          ? cart.items.first.product.sellerId
          : 'seller-1',
      status: 'pending',
      totalAmount: cart.subtotal,
      currency: cart.items.isNotEmpty
          ? cart.items.first.product.currency
          : 'USD',
      itemCount: cart.itemCount,
      shippingAddress: {'shipping_address_id': addressId},
      items: cart.items
          .map(
            (item) => OrderItemEntity(
              id: 'order-item-${item.productId}',
              orderId: 'order-${orders.length + 1}',
              productId: item.productId,
              sellerId: item.product.sellerId,
              productTitle: item.product.name,
              unitPrice: item.product.price,
              quantity: item.quantity,
              lineTotal: item.lineTotal,
            ),
          )
          .toList(growable: false),
    );
    orders = <OrderEntity>[order, ...orders];
    _cartQuantities.clear();
    return <OrderEntity>[order];
  }

  @override
  Future<List<OrderEntity>> listMyOrders() async {
    return orders;
  }

  @override
  Future<OrderEntity?> getMyOrderDetails(String orderId) async {
    try {
      return orders.firstWhere((order) => order.id == orderId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<StoreRecommendationsEntity> requestTaiyoStoreRecommendations({
    int limit = 3,
  }) async {
    return taiyoRecommendations;
  }
}

class FakeSellerRepository implements SellerRepository {
  SellerProfileEntity? profile;
  List<ProductEntity> products = const <ProductEntity>[];
  List<OrderEntity> orders = const <OrderEntity>[];
  Object? upsertError;

  @override
  Future<SellerProfileEntity?> getSellerProfile() async => profile;

  @override
  Future<void> upsertSellerProfile({
    required String storeName,
    required String storeDescription,
    required String primaryCategory,
    required String shippingScope,
    String? supportEmail,
  }) async {
    if (upsertError != null) {
      throw upsertError!;
    }

    profile = SellerProfileEntity(
      userId: 'seller-1',
      storeName: storeName,
      storeDescription: storeDescription,
      primaryCategory: primaryCategory,
      shippingScope: shippingScope,
      supportEmail: supportEmail,
    );
  }

  @override
  Future<SellerDashboardSummaryEntity> getDashboardSummary() async {
    final pendingOrders = orders
        .where((order) => order.status == 'pending')
        .length;
    final inProgressOrders = orders
        .where(
          (order) =>
              order.status == 'paid' ||
              order.status == 'processing' ||
              order.status == 'shipped',
        )
        .length;
    final deliveredOrders = orders
        .where((order) => order.status == 'delivered')
        .length;

    return SellerDashboardSummaryEntity(
      totalProducts: products.length,
      activeProducts: products.where((product) => product.isActive).length,
      lowStockProducts: products.where((product) => product.isLowStock).length,
      pendingOrders: pendingOrders,
      inProgressOrders: inProgressOrders,
      deliveredOrders: deliveredOrders,
      grossRevenue: orders.fold<double>(
        0,
        (sum, order) => sum + order.totalAmount,
      ),
    );
  }

  @override
  Future<List<ProductEntity>> listOwnProducts() async => products;

  @override
  Future<ProductEntity> saveProduct({
    String? productId,
    required String title,
    required String description,
    required String category,
    required double price,
    required int stockQty,
    required int lowStockThreshold,
    List<String> imagePaths = const <String>[],
    bool isActive = true,
  }) async {
    final product = ProductEntity(
      id: productId ?? 'product-${products.length + 1}',
      sellerId: 'seller-1',
      name: title,
      description: description,
      category: category,
      price: price,
      stockQty: stockQty,
      imagePaths: imagePaths,
      imageUrls: imagePaths,
      lowStockThreshold: lowStockThreshold,
      isActive: isActive,
    );

    final existingIndex = products.indexWhere((item) => item.id == product.id);
    if (existingIndex >= 0) {
      products = List<ProductEntity>.from(products)..[existingIndex] = product;
    } else {
      products = <ProductEntity>[product, ...products];
    }

    return product;
  }

  @override
  Future<String> uploadProductImage({
    required String productId,
    required List<int> bytes,
    String extension = 'jpg',
  }) async {
    return 'seller-1/$productId/mock.$extension';
  }

  @override
  Future<bool> deleteOrArchiveProduct(String productId) async {
    products = products.where((product) => product.id != productId).toList();
    return true;
  }

  @override
  Future<List<OrderEntity>> listOrders() async => orders;

  @override
  Future<OrderEntity?> getOrderDetails(String orderId) async {
    try {
      return orders.firstWhere((order) => order.id == orderId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? note,
  }) async {
    orders = orders
        .map(
          (order) => order.id == orderId
              ? OrderEntity(
                  id: order.id,
                  memberId: order.memberId,
                  sellerId: order.sellerId,
                  status: newStatus,
                  totalAmount: order.totalAmount,
                  currency: order.currency,
                  paymentMethod: order.paymentMethod,
                  memberName: order.memberName,
                  sellerName: order.sellerName,
                  itemCount: order.itemCount,
                  shippingAddress: order.shippingAddress,
                  items: order.items,
                  statusHistory: order.statusHistory,
                  createdAt: order.createdAt,
                  updatedAt: order.updatedAt,
                )
              : order,
        )
        .toList(growable: false);
  }

  @override
  Future<SellerTaiyoCopilotEntity> requestSellerCopilot({
    String requestType = 'seller_dashboard_brief',
    String? productId,
    String? orderId,
  }) async {
    return SellerTaiyoCopilotEntity(
      requestType: requestType,
      status: 'success',
      summary: 'Seller dashboard is steady.',
      priorityActions: const <String>['Review pending orders.'],
      riskLevel: 'low',
      confidence: 'medium',
    );
  }
}

class FakeNewsRepository implements NewsRepository {
  List<NewsArticleEntity> articles = const <NewsArticleEntity>[];
  final List<Map<String, dynamic>> trackedInteractions =
      <Map<String, dynamic>>[];
  final Set<String> savedArticleIds = <String>{};
  final Set<String> dismissedArticleIds = <String>{};

  Object? listError;
  Object? detailsError;
  Object? trackError;
  Object? saveError;
  Object? dismissError;

  @override
  Future<Paged<NewsArticleEntity>> listPersonalizedNews({
    String? cursor,
    int limit = 20,
  }) async {
    if (listError != null) throw listError!;
    final offset = int.tryParse(cursor ?? '') ?? 0;
    final items = articles
        .skip(offset)
        .take(limit)
        .map((article) {
          return article.copyWith(
            isSaved: savedArticleIds.contains(article.id),
          );
        })
        .toList(growable: false);
    final nextCursor = offset + items.length < articles.length
        ? (offset + items.length).toString()
        : null;
    return Paged<NewsArticleEntity>(items: items, nextCursor: nextCursor);
  }

  @override
  Future<NewsArticleEntity?> getArticleById(String articleId) async {
    if (detailsError != null) throw detailsError!;
    try {
      final article = articles.firstWhere((item) => item.id == articleId);
      return article.copyWith(isSaved: savedArticleIds.contains(article.id));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> trackInteraction(
    String articleId,
    NewsInteractionType interactionType, {
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    if (trackError != null) throw trackError!;
    trackedInteractions.add(<String, dynamic>{
      'articleId': articleId,
      'interactionType': interactionType.wireValue,
      'metadata': metadata,
    });
  }

  @override
  Future<bool> saveArticle(String articleId) async {
    if (saveError != null) throw saveError!;
    return savedArticleIds.add(articleId);
  }

  @override
  Future<void> removeSavedArticle(String articleId) async {
    if (saveError != null) throw saveError!;
    savedArticleIds.remove(articleId);
  }

  @override
  Future<void> dismissArticle(String articleId) async {
    if (dismissError != null) throw dismissError!;
    dismissedArticleIds.add(articleId);
    articles = articles.where((article) => article.id != articleId).toList();
  }
}

class FakeChatRepository implements ChatRepository {
  final List<ChatSessionEntity> sessions = <ChatSessionEntity>[];
  final Map<String, List<ChatMessageEntity>> _messages =
      <String, List<ChatMessageEntity>>{};
  final Map<String, StreamController<List<ChatMessageEntity>>> _controllers =
      <String, StreamController<List<ChatMessageEntity>>>{};

  Object? createSessionError;
  Object? sendMessageError;
  Duration createSessionDelay = Duration.zero;
  Duration sendMessageDelay = Duration.zero;
  Duration regeneratePlanDelay = Duration.zero;
  int createSessionCalls = 0;
  int sendMessageCalls = 0;
  int regeneratePlanCalls = 0;
  String? lastSentMessage;
  PlannerTurnResult? nextSendMessageResult;
  int _counter = 0;

  @override
  Future<List<ChatSessionEntity>> listSessions() async => sessions;

  @override
  Future<ChatSessionEntity> createSession({
    String? title,
    ChatSessionType type = ChatSessionType.general,
  }) async {
    createSessionCalls++;
    if (createSessionError != null) throw createSessionError!;
    if (createSessionDelay > Duration.zero) {
      await Future<void>.delayed(createSessionDelay);
    }
    _counter++;
    final session = ChatSessionEntity(
      id: 'session-$_counter',
      userId: 'user-1',
      title:
          title ??
          (type == ChatSessionType.planner
              ? 'TAIYO Planner'
              : 'New TAIYO chat'),
      updatedAt: DateTime(2026, 3, 8),
      type: type,
      plannerStatus: type == ChatSessionType.planner
          ? 'collecting_info'
          : 'idle',
    );
    sessions.add(session);
    _messages.putIfAbsent(session.id, () => <ChatMessageEntity>[]);
    _controllerFor(session.id).add(_messages[session.id]!);
    return session;
  }

  @override
  Stream<List<ChatMessageEntity>> watchMessages(String sessionId) {
    final controller = _controllerFor(sessionId);
    return Stream<List<ChatMessageEntity>>.multi((streamController) {
      streamController.add(
        sortChatMessages(_messages[sessionId] ?? const <ChatMessageEntity>[]),
      );
      final sub = controller.stream.listen(
        (messages) => streamController.add(sortChatMessages(messages)),
        onError: streamController.addError,
        onDone: streamController.close,
      );
      streamController.onCancel = () => sub.cancel();
    });
  }

  @override
  Future<PlannerTurnResult> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    sendMessageCalls++;
    lastSentMessage = message;
    if (sendMessageError != null) throw sendMessageError!;
    if (sendMessageDelay > Duration.zero) {
      await Future<void>.delayed(sendMessageDelay);
    }
    final list = _messages.putIfAbsent(sessionId, () => <ChatMessageEntity>[]);
    final session = sessions.firstWhere(
      (value) => value.id == sessionId,
      orElse: () => ChatSessionEntity(
        id: sessionId,
        userId: 'user-1',
        title: 'New TAIYO chat',
        updatedAt: DateTime(2026, 3, 8),
      ),
    );
    list.add(
      ChatMessageEntity(
        id: 'user-${list.length}',
        sessionId: sessionId,
        sender: 'user',
        content: message,
        createdAt: DateTime(2026, 3, 8, 12, 0),
      ),
    );
    final isPlanner = session.isPlanner;
    final draftId = isPlanner ? 'draft-$_counter-${list.length}' : null;
    final overriddenResult = nextSendMessageResult;
    final response = ChatMessageEntity(
      id: 'assistant-${list.length}',
      sessionId: sessionId,
      sender: 'assistant',
      content:
          overriddenResult?.assistantMessage ??
          (isPlanner
              ? 'Handled planner request: $message'
              : 'Handled: $message'),
      createdAt: DateTime(2026, 3, 8, 12, 1),
      metadata: isPlanner
          ? <String, dynamic>{
              'planner_status': overriddenResult?.status ?? 'needs_more_info',
              'draft_id': overriddenResult?.draftId ?? draftId,
              'missing_fields':
                  overriddenResult?.missingFields ??
                  const <String>['days_per_week', 'session_minutes'],
            }
          : const <String, dynamic>{},
    );
    list.add(response);
    _controllerFor(sessionId).add(List<ChatMessageEntity>.from(list));
    if (overriddenResult != null) {
      nextSendMessageResult = null;
      return overriddenResult;
    }
    return PlannerTurnResult(
      assistantMessage: response.content,
      status: isPlanner ? 'needs_more_info' : 'general_response',
      draftId: draftId,
      missingFields: isPlanner
          ? const <String>['days_per_week', 'session_minutes']
          : const <String>[],
    );
  }

  @override
  Future<PlannerTurnResult> regeneratePlan({
    required String sessionId,
    required String draftId,
  }) async {
    regeneratePlanCalls++;
    if (sendMessageError != null) throw sendMessageError!;
    if (regeneratePlanDelay > Duration.zero) {
      await Future<void>.delayed(regeneratePlanDelay);
    }
    final list = _messages.putIfAbsent(sessionId, () => <ChatMessageEntity>[]);
    final response = ChatMessageEntity(
      id: 'assistant-regenerated-${list.length}',
      sessionId: sessionId,
      sender: 'assistant',
      content: 'The planner refreshed your draft.',
      createdAt: DateTime(2026, 3, 8, 12, 2),
      metadata: <String, dynamic>{
        'planner_status': 'plan_updated',
        'draft_id': draftId,
      },
    );
    list.add(response);
    _controllerFor(sessionId).add(List<ChatMessageEntity>.from(list));
    return const PlannerTurnResult(
      assistantMessage: 'The planner refreshed your draft.',
      status: 'plan_updated',
    );
  }

  List<ChatMessageEntity> messagesFor(String sessionId) {
    return sortChatMessages(
      _messages[sessionId] ?? const <ChatMessageEntity>[],
    );
  }

  void replaceMessages(String sessionId, List<ChatMessageEntity> messages) {
    _messages[sessionId] = List<ChatMessageEntity>.from(messages);
    _controllerFor(sessionId).add(sortChatMessages(messages));
  }

  StreamController<List<ChatMessageEntity>> _controllerFor(String sessionId) {
    return _controllers.putIfAbsent(
      sessionId,
      () => StreamController<List<ChatMessageEntity>>.broadcast(),
    );
  }
}

class FakePlannerRepository implements PlannerRepository {
  PlannerDraftEntity? latestDraft;
  final Map<String, PlannerDraftEntity> drafts = <String, PlannerDraftEntity>{};
  final Map<String, PlanDetailEntity> plans = <String, PlanDetailEntity>{};
  List<PlanTaskEntity> todayAgenda = const <PlanTaskEntity>[];
  PlannerTurnResult? nextTaiyoPlanResult;
  int requestTaiyoWorkoutPlanDraftCalls = 0;
  Map<String, dynamic>? lastTaiyoPlannerAnswers;
  String? lastTaiyoPlannerSessionId;
  String? lastTaiyoPlannerDraftId;
  String? lastTaiyoPlannerRequestType;

  @override
  Future<PlanActivationResultEntity> activateDraft({
    required String draftId,
    required DateTime startDate,
    String? reminderTime,
  }) async {
    final planId = drafts[draftId]?.id ?? 'plan-1';
    return PlanActivationResultEntity(planId: planId, created: true);
  }

  @override
  Future<PlannerDraftEntity?> getDraft(String draftId) async => drafts[draftId];

  @override
  Future<PlannerDraftEntity?> getLatestDraft(String sessionId) async {
    return latestDraft;
  }

  @override
  Future<PlannerTurnResult> requestTaiyoWorkoutPlanDraft({
    required Map<String, dynamic> plannerAnswers,
    String? sessionId,
    String? draftId,
    String requestType = 'workout_plan_draft',
  }) async {
    requestTaiyoWorkoutPlanDraftCalls++;
    lastTaiyoPlannerAnswers = Map<String, dynamic>.from(plannerAnswers);
    lastTaiyoPlannerSessionId = sessionId;
    lastTaiyoPlannerDraftId = draftId;
    lastTaiyoPlannerRequestType = requestType;
    if (nextTaiyoPlanResult != null) {
      final result = nextTaiyoPlanResult!;
      nextTaiyoPlanResult = null;
      return result;
    }
    return PlannerTurnResult(
      assistantMessage: 'TAIYO prepared your workout plan draft.',
      status: requestType == 'plan_review' ? 'plan_updated' : 'plan_ready',
      draftId: draftId ?? 'draft-taiyo',
    );
  }

  @override
  Future<PlanDetailEntity?> getPlanDetail({String? planId}) async {
    if (planId == null) {
      return plans.values.isEmpty ? null : plans.values.first;
    }
    return plans[planId];
  }

  @override
  Future<List<PlanTaskEntity>> listPlanAgenda({
    String? planId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    return todayAgenda;
  }

  @override
  Future<List<PlanTaskEntity>> listTodayAgenda() async => todayAgenda;

  @override
  Future<int> syncReminders({required String timeZone, int limit = 50}) async {
    return todayAgenda.length;
  }

  @override
  Future<int> updateReminderTime({
    required String planId,
    required String reminderTime,
    required String timeZone,
  }) async {
    return 1;
  }

  @override
  Future<PlanTaskEntity> updateTaskStatus({
    required String taskId,
    required TaskCompletionStatus status,
    int? completionPercent,
    String? note,
    int? durationMinutes,
  }) async {
    final index = todayAgenda.indexWhere((task) => task.taskId == taskId);
    if (index < 0) {
      throw StateError('Task not found');
    }
    final updated = todayAgenda[index].copyWith(
      completionStatus: status,
      completionPercent: completionPercent,
    );
    todayAgenda = List<PlanTaskEntity>.from(todayAgenda)..[index] = updated;
    return updated;
  }
}

class FakeCoachMemberInsightsRepository
    implements CoachMemberInsightsRepository {
  List<InsightSummaryEntity> summaries = const <InsightSummaryEntity>[];
  MemberInsightEntity? memberInsight;
  VisibilitySettingsEntity? visibilitySettings;
  List<VisibilityAuditEntity> auditEntries = const <VisibilityAuditEntity>[];

  Object? summariesError;
  Object? insightError;
  Object? visibilityError;
  Object? upsertError;

  @override
  Future<List<InsightSummaryEntity>> listClientInsightSummaries() async {
    if (summariesError != null) throw summariesError!;
    return summaries;
  }

  @override
  Future<MemberInsightEntity?> getMemberInsight({
    required String memberId,
    required String subscriptionId,
  }) async {
    if (insightError != null) throw insightError!;
    return memberInsight;
  }

  @override
  Future<VisibilitySettingsEntity?> getVisibilitySettings({
    required String subscriptionId,
  }) async {
    if (visibilityError != null) throw visibilityError!;
    return visibilitySettings;
  }

  @override
  Future<VisibilitySettingsEntity> upsertVisibilitySettings({
    required String subscriptionId,
    required String coachId,
    required bool shareAiPlanSummary,
    required bool shareWorkoutAdherence,
    required bool shareProgressMetrics,
    required bool shareNutritionSummary,
    required bool shareProductRecommendations,
    required bool shareRelevantPurchases,
  }) async {
    if (upsertError != null) throw upsertError!;
    final updated = VisibilitySettingsEntity(
      id: visibilitySettings?.id ?? 'vis-1',
      memberId: visibilitySettings?.memberId ?? 'member-1',
      coachId: coachId,
      subscriptionId: subscriptionId,
      shareAiPlanSummary: shareAiPlanSummary,
      shareWorkoutAdherence: shareWorkoutAdherence,
      shareProgressMetrics: shareProgressMetrics,
      shareNutritionSummary: shareNutritionSummary,
      shareProductRecommendations: shareProductRecommendations,
      shareRelevantPurchases: shareRelevantPurchases,
    );
    visibilitySettings = updated;
    return updated;
  }

  @override
  Future<List<VisibilityAuditEntity>> listVisibilityAudit({
    required String subscriptionId,
  }) async {
    return auditEntries;
  }
}

class FakeAiCoachRepository implements AiCoachRepository {
  AiDailyBriefEntity? dailyBrief;
  AiReadinessLogEntity? readinessLog;
  List<AiNudgeEntity> nudges = const <AiNudgeEntity>[];
  ActiveWorkoutSessionEntity? activeWorkoutSession;
  AiWeeklySummaryEntity? weeklySummary;
  Map<String, dynamic> workoutPrompt = const <String, dynamic>{
    'message': 'Stay steady and keep the next block clean.',
  };

  int accountabilityScanCalls = 0;
  int maintainMemoryCalls = 0;
  Object? error;

  @override
  Future<AiPlanAdaptationEntity> applyAdjustment({
    required String adjustmentType,
    DateTime? briefDate,
    String? taskId,
  }) async {
    if (error != null) throw error!;
    return AiPlanAdaptationEntity(
      id: 'adapt-1',
      adaptationType: adjustmentType,
      status: 'applied',
      whyShort: 'TAIYO adjusted today to reduce friction.',
      before: const <String, dynamic>{},
      after: <String, dynamic>{'task_id': taskId},
      confidence: 0.85,
    );
  }

  @override
  Future<AiWeeklySummaryEntity> refreshWeeklySummary(DateTime weekStart) async {
    if (error != null) throw error!;
    weeklySummary ??= AiWeeklySummaryEntity(
      id: 'summary-1',
      weekStart: weekStart,
      adherenceScore: 76,
      summaryText: 'TAIYO weekly summary ready.',
      nextFocus: 'Keep the plan simple and finishable.',
      whyShort: 'Based on adherence and recovery.',
      confidence: 0.85,
      shareStatus: 'private',
    );
    return weeklySummary!;
  }

  @override
  Future<AiDailyBriefEntity> refreshDailyBrief(DateTime date) async {
    if (error != null) throw error!;
    dailyBrief ??= AiDailyBriefEntity(
      id: 'brief-1',
      briefDate: date,
      planId: 'plan-1',
      dayId: 'day-1',
      primaryTaskId: 'task-1',
      readinessScore: 62,
      intensityBand: 'yellow',
      coachMode: false,
      recommendedWorkout: const <String, dynamic>{
        'title': 'Upper strength',
        'duration_minutes': 35,
      },
      habitFocus: const <String, dynamic>{
        'title': 'Show up on time',
        'body': 'Protect the start of the session.',
      },
      nutritionPriority: const <String, dynamic>{
        'title': 'Protein after training',
        'body': 'Keep recovery simple.',
      },
      whyShort: 'TAIYO picked a finishable session for today.',
      confidence: 0.85,
    );
    return dailyBrief!;
  }

  @override
  Future<ActiveWorkoutSessionEntity?> getActiveWorkoutSession(
    String sessionId,
  ) async {
    if (error != null) throw error!;
    return activeWorkoutSession;
  }

  @override
  Future<AiDailyBriefEntity?> getDailyBrief(DateTime date) async => dailyBrief;

  @override
  Future<List<AiNudgeEntity>> listNudges() async {
    if (error != null) throw error!;
    return nudges;
  }

  @override
  Future<void> maintainMemory() async {
    if (error != null) throw error!;
    maintainMemoryCalls++;
  }

  @override
  Future<void> recordActiveWorkoutEvent({
    required String sessionId,
    required String eventType,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    if (error != null) throw error!;
  }

  @override
  Future<void> runAccountabilityScan() async {
    if (error != null) throw error!;
    accountabilityScanCalls++;
  }

  @override
  Future<void> shareWeeklySummary(DateTime weekStart) async {
    if (error != null) throw error!;
    final current = await refreshWeeklySummary(weekStart);
    weeklySummary = AiWeeklySummaryEntity(
      id: current.id,
      weekStart: current.weekStart,
      adherenceScore: current.adherenceScore,
      summaryText: current.summaryText,
      wins: current.wins,
      blockers: current.blockers,
      nextFocus: current.nextFocus,
      workoutSummary: current.workoutSummary,
      nutritionSummary: current.nutritionSummary,
      whyShort: current.whyShort,
      signalsUsed: current.signalsUsed,
      confidence: current.confidence,
      shareStatus: 'shared',
    );
  }

  @override
  Future<ActiveWorkoutSessionEntity> startActiveWorkout({
    required String planId,
    String? dayId,
    DateTime? targetDate,
  }) async {
    if (error != null) throw error!;
    activeWorkoutSession = ActiveWorkoutSessionEntity(
      id: 'session-1',
      planId: planId,
      dayId: dayId,
      status: 'active',
      startedAt: DateTime.now(),
      plannedMinutes: 35,
      whyShort: 'TAIYO started the guided session.',
      confidence: 0.9,
      summary: const <String, dynamic>{
        'tasks': [
          {
            'task_id': 'task-1',
            'title': 'Bench Press',
            'task_type': 'workout',
            'instructions': '3 x 8',
            'sort_order': 1,
          },
        ],
        'completed_task_ids': [],
        'partial_task_ids': [],
        'skipped_task_ids': [],
      },
      wasShortened: false,
      wasSwapped: false,
    );
    return activeWorkoutSession!;
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
    if (error != null) throw error!;
    readinessLog = AiReadinessLogEntity(
      id: 'readiness-1',
      logDate: logDate ?? DateTime.now(),
      energyLevel: energyLevel,
      sorenessLevel: sorenessLevel,
      stressLevel: stressLevel,
      availableMinutes: availableMinutes,
      locationMode: locationMode,
      equipmentOverride: equipmentOverride,
      readinessScore: 61,
      intensityBand: 'yellow',
      source: source,
      note: note,
    );
    return readinessLog!;
  }

  @override
  Future<AiWeeklySummaryEntity?> getWeeklySummary(DateTime weekStart) async =>
      weeklySummary;

  @override
  Future<Map<String, dynamic>> getWorkoutPrompt({
    required String sessionId,
    String promptKind = 'mid_session',
  }) async {
    if (error != null) throw error!;
    return workoutPrompt;
  }

  @override
  Future<ActiveWorkoutSessionEntity> completeActiveWorkout({
    required String sessionId,
    int? difficultyScore,
    Map<String, dynamic> summary = const <String, dynamic>{},
  }) async {
    if (error != null) throw error!;
    activeWorkoutSession = ActiveWorkoutSessionEntity(
      id: sessionId,
      planId: activeWorkoutSession?.planId,
      dayId: activeWorkoutSession?.dayId,
      status: 'completed',
      startedAt: activeWorkoutSession?.startedAt ?? DateTime.now(),
      endedAt: DateTime.now(),
      plannedMinutes: activeWorkoutSession?.plannedMinutes ?? 35,
      difficultyScore: difficultyScore,
      whyShort: 'Workout complete.',
      confidence: 0.9,
      summary: summary,
      wasShortened: summary['was_shortened'] as bool? ?? false,
      wasSwapped: summary['was_swapped'] as bool? ?? false,
    );
    return activeWorkoutSession!;
  }
}
