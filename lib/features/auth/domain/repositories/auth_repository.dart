import '../entities/auth_session.dart';
import '../entities/otp_flow.dart';

abstract class AuthRepository {
  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
  });

  Future<AuthSession> login({required String email, required String password});

  Future<bool> signInWithGoogle();

  Future<void> sendOtp({required String email, required OtpFlowMode mode});

  Future<void> requestPasswordReset({required String email});

  Future<AuthSession> verifyOtp({
    required String email,
    required String token,
    required OtpFlowMode mode,
  });

  Stream<AuthSession?> watchSession();

  Future<void> logout();
}
