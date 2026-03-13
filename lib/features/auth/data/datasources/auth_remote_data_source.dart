import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/auth_constants.dart';
import '../../domain/entities/auth_provider_type.dart';
import '../../domain/entities/otp_flow.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final SupabaseClient _client;
  User? get currentAuthUser => _client.auth.currentUser;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: <String, dynamic>{'full_name': fullName},
    );
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<bool> signInWithOAuth({
    required OAuthProvider provider,
    required String redirectTo,
    LaunchMode authScreenLaunchMode = LaunchMode.platformDefault,
  }) {
    return _client.auth.signInWithOAuth(
      provider,
      redirectTo: redirectTo,
      authScreenLaunchMode: authScreenLaunchMode,
    );
  }

  Future<void> sendOtp({
    required String email,
    required OtpFlowMode mode,
  }) async {
    switch (mode) {
      case OtpFlowMode.signup:
        await _client.auth.resend(type: OtpType.signup, email: email);
        break;
      case OtpFlowMode.recovery:
        await _client.auth.resetPasswordForEmail(
          email,
          redirectTo: AppAuthConstants.oauthRedirect,
        );
        break;
    }
  }

  Future<void> requestPasswordReset({required String email}) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: AppAuthConstants.oauthRedirect,
    );
  }

  Future<UserResponse> updatePassword({required String newPassword}) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<AuthResponse> reauthenticateWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<FunctionResponse> invokeDeleteAccount({String? currentPassword}) {
    return _client.functions.invoke(
      'delete-account',
      body: <String, dynamic>{
        if (currentPassword != null && currentPassword.trim().isNotEmpty)
          'current_password': currentPassword.trim(),
      },
    );
  }

  AuthProviderType? getCurrentProvider() {
    final identities = currentAuthUser?.identities ?? const <UserIdentity>[];
    final identityProvider = identities.isNotEmpty
        ? identities.first.provider
        : null;
    final providerId =
        currentAuthUser?.appMetadata['provider'] as String? ?? identityProvider;
    if (providerId == null || providerId.trim().isEmpty) {
      return null;
    }
    return AuthProviderType.fromProviderId(providerId);
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    required OtpFlowMode mode,
  }) {
    return _client.auth.verifyOTP(
      email: email,
      token: token,
      type: mode.otpType,
    );
  }

  Stream<AuthState> onAuthStateChange() {
    return _client.auth.onAuthStateChange;
  }

  Future<void> signOut() => _client.auth.signOut();
}
