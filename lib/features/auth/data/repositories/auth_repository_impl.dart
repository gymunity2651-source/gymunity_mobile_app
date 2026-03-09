import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/auth_constants.dart';
import '../../../../core/error/app_failure.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/otp_flow.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _remoteDataSource.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      final session = response.session;
      return AuthSession(
        userId: user?.id,
        email: user?.email,
        fullName: _extractFullName(user),
        isAuthenticated: session != null,
      );
    } on AuthException catch (e, st) {
      throw AuthFailure(
        message: e.message,
        code: e.statusCode?.toString(),
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AuthFailure(
        message: 'Unable to complete login.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _remoteDataSource.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      final user = response.user;
      final session = response.session;
      return AuthSession(
        userId: user?.id,
        email: user?.email,
        fullName: _extractFullName(user),
        isAuthenticated: session != null,
        requiresOtpVerification: session == null,
      );
    } on AuthException catch (e, st) {
      throw AuthFailure(
        message: e.message,
        code: e.statusCode?.toString(),
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AuthFailure(
        message: 'Unable to complete registration.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    try {
      final launched = await _remoteDataSource.signInWithGoogle(
        redirectTo: AppAuthConstants.googleOAuthRedirect,
      );
      if (!launched) {
        throw const AuthFailure(
          message:
              'Unable to open Google sign-in. Check browser availability and try again.',
        );
      }
      return true;
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e, st) {
      throw AuthFailure(
        message: e.message,
        code: e.statusCode?.toString(),
        cause: e,
        stackTrace: st,
      );
    } on SocketException catch (e, st) {
      throw AuthFailure(
        message: 'Network error while starting Google sign-in.',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AuthFailure(
        message: 'Unable to start Google sign-in right now.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> sendOtp({
    required String email,
    required OtpFlowMode mode,
  }) async {
    try {
      await _remoteDataSource.sendOtp(email: email, mode: mode);
    } on AuthException catch (e, st) {
      throw AuthFailure(
        message: e.message,
        code: e.statusCode?.toString(),
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AuthFailure(
        message: 'Unable to send OTP code.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _remoteDataSource.requestPasswordReset(email: email);
    } on AuthException catch (e, st) {
      throw AuthFailure(
        message: e.message,
        code: e.statusCode?.toString(),
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AuthFailure(
        message: 'Unable to send password reset email.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<AuthSession> verifyOtp({
    required String email,
    required String token,
    required OtpFlowMode mode,
  }) async {
    try {
      final response = await _remoteDataSource.verifyOtp(
        email: email,
        token: token,
        mode: mode,
      );
      final user = response.user;
      final session = response.session;
      return AuthSession(
        userId: user?.id,
        email: user?.email,
        fullName: _extractFullName(user),
        isAuthenticated: session != null,
      );
    } on AuthException catch (e, st) {
      throw AuthFailure(
        message: e.message,
        code: e.statusCode?.toString(),
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AuthFailure(
        message: 'Invalid or expired OTP code.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Stream<AuthSession?> watchSession() {
    return _remoteDataSource.onAuthStateChange().map((state) {
      final session = state.session;
      if (session == null) return null;
      return AuthSession(
        userId: session.user.id,
        email: session.user.email,
        fullName: _extractFullName(session.user),
        isAuthenticated: true,
      );
    });
  }

  @override
  Future<void> logout() async {
    await _remoteDataSource.signOut();
  }

  String? _extractFullName(User? user) {
    final metadata = user?.userMetadata;
    final fullName = metadata?['full_name'];
    if (fullName is String && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    final name = metadata?['name'];
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
    return null;
  }
}
