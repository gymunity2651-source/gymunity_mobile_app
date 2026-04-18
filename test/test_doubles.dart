import 'dart:async';

import 'package:my_app/core/supabase/auth_callback_ingress.dart';
import 'package:my_app/core/result/paged.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_message_entity.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_session_entity.dart';
import 'package:my_app/features/ai_chat/domain/entities/planner_turn_result.dart';
import 'package:my_app/features/ai_chat/domain/repositories/chat_repository.dart';
import 'package:my_app/features/auth/domain/entities/auth_session.dart';
import 'package:my_app/features/auth/domain/entities/auth_provider_type.dart';
import 'package:my_app/features/auth/domain/entities/otp_flow.dart';
import 'package:my_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_app/features/coach/domain/entities/coach_entity.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/coach/domain/entities/workout_plan_entity.dart';
import 'package:my_app/features/coach/domain/repositories/coach_repository.dart';
import 'package:my_app/features/member/domain/entities/member_home_summary_entity.dart';
import 'package:my_app/features/member/domain/entities/coaching_engagement_entity.dart';
import 'package:my_app/features/member/domain/entities/member_profile_entity.dart';
import 'package:my_app/features/member/domain/entities/member_progress_entity.dart';
import 'package:my_app/features/member/domain/repositories/member_repository.dart';
import 'package:my_app/features/news/domain/entities/news_article.dart';
import 'package:my_app/features/news/domain/repositories/news_repository.dart';
import 'package:my_app/features/planner/domain/entities/planner_entities.dart';
import 'package:my_app/features/planner/domain/repositories/planner_repository.dart';
import 'package:my_app/features/seller/domain/entities/seller_profile_entity.dart';
import 'package:my_app/features/seller/domain/repositories/seller_repository.dart';
import 'package:my_app/features/store/domain/entities/cart_entity.dart';
import 'package:my_app/features/store/domain/entities/order_entity.dart';
import 'package:my_app/features/store/domain/entities/product_entity.dart';
import 'package:my_app/features/store/domain/entities/shipping_address_entity.dart';
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
  Future<void> logout() async {}
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
  Object? upsertError;
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
  }) async {
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
  }) async {}

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
}

class FakeMemberRepository implements MemberRepository {
  MemberProfileEntity? profile;
  UserPreferencesEntity preferences = const UserPreferencesEntity();
  List<WeightEntryEntity> weightEntries = const <WeightEntryEntity>[];
  List<BodyMeasurementEntity> measurements = const <BodyMeasurementEntity>[];
  List<WorkoutPlanEntity> workoutPlans = const <WorkoutPlanEntity>[];
  List<WorkoutSessionEntity> workoutSessions = const <WorkoutSessionEntity>[];
  List<SubscriptionEntity> subscriptions = const <SubscriptionEntity>[];
  List<OrderEntity> orders = const <OrderEntity>[];
  MemberHomeSummaryEntity homeSummary = const MemberHomeSummaryEntity();

  Object? upsertError;

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
            lastMessagePreview: 'Your coaching thread is ready.',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CoachingMessageEntity>> listCoachingMessages(
    String threadId,
  ) async {
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
  }) async {}

  @override
  Future<List<WeeklyCheckinEntity>> listWeeklyCheckins({
    String? subscriptionId,
  }) async {
    return const <WeeklyCheckinEntity>[];
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
    );
  }

  @override
  Future<List<OrderEntity>> listOrders() async => orders;

  @override
  Future<MemberHomeSummaryEntity> getHomeSummary() async => homeSummary;
}

class FakeStoreRepository implements StoreRepository {
  List<ProductEntity> products = const <ProductEntity>[];
  List<OrderEntity> orders = const <OrderEntity>[];
  final Set<String> favoriteIds = <String>{};
  final Map<String, int> _cartQuantities = <String, int>{};
  final List<ShippingAddressEntity> _addresses = <ShippingAddressEntity>[];
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
