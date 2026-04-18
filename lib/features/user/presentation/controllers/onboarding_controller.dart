import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/app_failure.dart';
import '../../../coach/domain/offer_preview_factory.dart';
import '../../../coach/domain/repositories/coach_repository.dart';
import '../../../member/domain/repositories/member_repository.dart';
import '../../../seller/domain/repositories/seller_repository.dart';
import '../../domain/entities/app_role.dart';
import '../../domain/repositories/user_repository.dart';

class OnboardingControllerState {
  const OnboardingControllerState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  OnboardingControllerState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OnboardingControllerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingControllerState> {
  OnboardingController(this._ref) : super(const OnboardingControllerState());

  final Ref _ref;

  UserRepository get _userRepo => _ref.read(userRepositoryProvider);
  CoachRepository get _coachRepo => _ref.read(coachRepositoryProvider);
  MemberRepository get _memberRepo => _ref.read(memberRepositoryProvider);
  SellerRepository get _sellerRepo => _ref.read(sellerRepositoryProvider);

  Future<bool> saveRole(AppRole role) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _userRepo.saveRole(role);
      _ref.invalidate(currentUserProfileProvider);
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromError(e),
      );
      return false;
    }
  }

  Future<bool> completeMemberOnboarding({
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
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _memberRepo.upsertMemberProfile(
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
      _ref.invalidate(currentUserProfileProvider);
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromError(e),
      );
      return false;
    }
  }

  Future<bool> completeSellerOnboarding({
    required String storeName,
    required String storeDescription,
    required String primaryCategory,
    required String shippingScope,
    String? supportEmail,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _sellerRepo.upsertSellerProfile(
        storeName: storeName,
        storeDescription: storeDescription,
        primaryCategory: primaryCategory,
        shippingScope: shippingScope,
        supportEmail: supportEmail,
      );
      _ref.invalidate(currentUserProfileProvider);
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromError(e),
      );
      return false;
    }
  }

  Future<bool> completeCoachOnboarding({
    required String bio,
    required List<String> specialties,
    required int yearsExperience,
    required double hourlyRate,
    required String deliveryMode,
    required String serviceSummary,
    required String packageTitle,
    required String packageDescription,
    required String billingCycle,
    required double packagePrice,
    required int availabilityWeekday,
    required String availabilityStartTime,
    required String availabilityEndTime,
    required String availabilityTimezone,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _coachRepo.upsertCoachProfile(
        bio: bio,
        specialties: specialties,
        yearsExperience: yearsExperience,
        hourlyRate: hourlyRate,
        deliveryMode: deliveryMode,
        serviceSummary: serviceSummary,
      );
      await _coachRepo.saveCoachPackage(
        title: packageTitle,
        description: packageDescription,
        billingCycle: billingCycle,
        price: packagePrice,
        subtitle: 'Starter coaching offer',
        outcomeSummary: serviceSummary,
        idealFor: specialties,
        durationWeeks: 4,
        sessionsPerWeek: 3,
        difficultyLevel: 'beginner',
        includedFeatures: const <String>[
          'Personalized training structure',
          'Recurring coach check-ins',
          'Progress support',
        ],
        checkInFrequency: 'Weekly',
        supportSummary: serviceSummary,
        planPreviewJson: buildCoachOfferPlanPreview(
          title: packageTitle,
          summary: serviceSummary,
          durationWeeks: 4,
          sessionsPerWeek: 3,
          difficultyLevel: 'beginner',
        ),
        visibilityStatus: 'draft',
        isActive: false,
      );
      await _coachRepo.saveAvailabilitySlot(
        weekday: availabilityWeekday,
        startTime: availabilityStartTime,
        endTime: availabilityEndTime,
        timezone: availabilityTimezone,
      );
      _ref.invalidate(currentUserProfileProvider);
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromError(e),
      );
      return false;
    }
  }

  String _messageFromError(Object error) {
    if (error is AppFailure) {
      return error.message;
    }
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    return raw;
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingControllerState>((
      ref,
    ) {
      return OnboardingController(ref);
    });
