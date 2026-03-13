import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/auth_constants.dart';
import '../../../../core/error/app_failure.dart';
import '../../domain/entities/auth_provider_type.dart';
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
  Future<bool> signInWithOAuth({required AuthProviderType provider}) async {
    try {
      if (kDebugMode) {
        debugPrint(
          'Starting ${provider.label} OAuth with redirectTo=${AppAuthConstants.oauthRedirect}',
        );
      }
      final launchMode = _resolveAuthLaunchMode(provider);
      final launched = await _remoteDataSource.signInWithOAuth(
        provider: _mapProvider(provider),
        redirectTo: AppAuthConstants.oauthRedirect,
        authScreenLaunchMode: launchMode,
      );
      if (!launched) {
        throw AuthFailure(
          message:
              'Unable to open ${provider.label} sign-in. Check browser availability and try again.',
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
        message: 'Network error while starting ${provider.label} sign-in.',
        cause: e,
        stackTrace: st,
      );
    } on PlatformException catch (e, st) {
      throw AuthFailure(
        message:
            e.message?.trim().isNotEmpty == true
                ? e.message!.trim()
                : 'Unable to open ${provider.label} sign-in on this device.',
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      final raw = e.toString().trim();
      final resolvedMessage = raw.startsWith('Exception: ')
          ? raw.replaceFirst('Exception: ', '')
          : raw;
      throw AuthFailure(
        message: resolvedMessage.isNotEmpty
            ? resolvedMessage
            : 'Unable to start ${provider.label} sign-in right now.',
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
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _remoteDataSource.updatePassword(newPassword: newPassword);
    } on AuthException catch (e, st) {
      throw AuthFailure(
        message: e.message,
        code: e.statusCode?.toString(),
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AuthFailure(
        message: 'Unable to update your password right now.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<AuthProviderType?> getCurrentAuthProvider() async {
    return _remoteDataSource.getCurrentProvider();
  }

  @override
  Future<void> deleteAccount({String? currentPassword}) async {
    try {
      final provider = _remoteDataSource.getCurrentProvider();
      final currentUser = _remoteDataSource.currentAuthUser;
      if (currentUser == null) {
        throw const AuthFailure(message: 'No authenticated user found.');
      }

      if (provider == AuthProviderType.emailPassword) {
        final email = currentUser.email?.trim() ?? '';
        final password = currentPassword?.trim() ?? '';
        if (email.isEmpty || password.isEmpty) {
          throw const AuthFailure(
            message: 'Enter your current password to delete this account.',
          );
        }
        await _remoteDataSource.reauthenticateWithPassword(
          email: email,
          password: password,
        );
      }

      final response = await _remoteDataSource.invokeDeleteAccount(
        currentPassword: currentPassword,
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final errorMessage = data['error'] as String?;
        if (errorMessage != null && errorMessage.trim().isNotEmpty) {
          throw AuthFailure(message: errorMessage);
        }
      }
      await _remoteDataSource.signOut();
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e, st) {
      throw AuthFailure(
        message: e.message,
        code: e.statusCode?.toString(),
        cause: e,
        stackTrace: st,
      );
    } on FunctionException catch (e, st) {
      throw AuthFailure(
        message: e.details?.toString() ?? 'Unable to delete your account.',
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw AuthFailure(
        message: 'Unable to delete your account right now.',
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

  OAuthProvider _mapProvider(AuthProviderType provider) {
    switch (provider) {
      case AuthProviderType.google:
        return OAuthProvider.google;
      case AuthProviderType.apple:
        return OAuthProvider.apple;
      case AuthProviderType.emailPassword:
        throw const AuthFailure(
          message: 'Email/password sign-in is not an OAuth flow.',
        );
    }
  }

  LaunchMode _resolveAuthLaunchMode(AuthProviderType provider) {
    if (!kIsWeb && Platform.isIOS && provider == AuthProviderType.google) {
      return LaunchMode.inAppBrowserView;
    }
    return LaunchMode.platformDefault;
  }
}
