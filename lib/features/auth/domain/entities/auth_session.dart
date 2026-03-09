class AuthSession {
  const AuthSession({
    this.userId,
    this.email,
    this.fullName,
    required this.isAuthenticated,
    this.requiresOtpVerification = false,
  });

  final String? userId;
  final String? email;
  final String? fullName;
  final bool isAuthenticated;
  final bool requiresOtpVerification;

  const AuthSession.unauthenticated()
    : userId = null,
      email = null,
      fullName = null,
      isAuthenticated = false,
      requiresOtpVerification = false;
}
