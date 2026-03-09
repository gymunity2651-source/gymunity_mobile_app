import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/error/app_failure.dart';
import '../../../coach/domain/repositories/coach_repository.dart';
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

  Future<bool> completeMemberOnboarding() async {
    return _completeBaseOnboarding();
  }

  Future<bool> completeSellerOnboarding() async {
    return _completeBaseOnboarding();
  }

  Future<bool> completeCoachOnboarding({
    required String bio,
    required List<String> specialties,
    required int yearsExperience,
    required double hourlyRate,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _coachRepo.upsertCoachProfile(
        bio: bio,
        specialties: specialties,
        yearsExperience: yearsExperience,
        hourlyRate: hourlyRate,
      );
      await _userRepo.completeOnboarding();
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

  Future<bool> _completeBaseOnboarding() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _userRepo.completeOnboarding();
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
