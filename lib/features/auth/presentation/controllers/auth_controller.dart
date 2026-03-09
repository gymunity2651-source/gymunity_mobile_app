import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/otp_flow.dart';

class AuthControllerState {
  const AuthControllerState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  AuthControllerState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthControllerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthControllerState> {
  AuthController(this._ref) : super(const AuthControllerState());

  final Ref _ref;

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final session = await authRepo.login(email: email, password: password);
      await _bootstrapUserProfile(session);
      state = state.copyWith(isLoading: false, clearError: true);
      return session.isAuthenticated;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromError(e),
      );
      return false;
    }
  }

  Future<AuthSession?> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final session = await authRepo.register(
        email: email,
        password: password,
        fullName: fullName,
      );
      await _bootstrapUserProfile(session, fallbackFullName: fullName);
      state = state.copyWith(isLoading: false, clearError: true);
      return session;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromError(e),
      );
      return null;
    }
  }

  Future<bool> sendOtp({
    required String email,
    required OtpFlowMode mode,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.sendOtp(email: email, mode: mode);
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

  Future<bool> requestPasswordReset({required String email}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.requestPasswordReset(email: email);
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

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final launched = await authRepo.signInWithGoogle();
      state = state.copyWith(isLoading: false, clearError: true);
      return launched;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromError(e),
      );
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String token,
    required OtpFlowMode mode,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      final session = await authRepo.verifyOtp(
        email: email,
        token: token,
        mode: mode,
      );
      await _bootstrapUserProfile(session);
      state = state.copyWith(isLoading: false, clearError: true);
      return session.isAuthenticated;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromError(e),
      );
      return false;
    }
  }

  Future<bool> completeAuthenticatedSession(
    AuthSession session, {
    String? fallbackFullName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _bootstrapUserProfile(session, fallbackFullName: fallbackFullName);
      state = state.copyWith(isLoading: false, clearError: true);
      return session.isAuthenticated;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromError(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.logout();
      _ref.invalidate(currentUserProfileProvider);
      state = state.copyWith(isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFromError(e),
      );
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
    if (raw.startsWith('Bad state: ')) {
      return raw.replaceFirst('Bad state: ', '');
    }
    return raw;
  }

  Future<void> _bootstrapUserProfile(
    AuthSession session, {
    String? fallbackFullName,
  }) async {
    if (session.userId != null && session.email != null) {
      await _ref
          .read(userRepositoryProvider)
          .ensureUserAndProfile(
            userId: session.userId!,
            email: session.email!,
            fullName: session.fullName ?? fallbackFullName,
          );
    }
    _ref.invalidate(currentUserProfileProvider);
  }
}
