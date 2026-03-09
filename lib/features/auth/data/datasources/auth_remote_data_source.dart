import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/otp_flow.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

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

  // External setup required before this flow will work:
  // Supabase Dashboard -> Authentication -> Providers -> Google
  // Then add the same redirect URL to Supabase URL Configuration.
  Future<bool> signInWithGoogle({required String redirectTo}) {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
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
        await _client.auth.resetPasswordForEmail(email);
        break;
    }
  }

  Future<void> requestPasswordReset({required String email}) {
    return _client.auth.resetPasswordForEmail(email);
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
