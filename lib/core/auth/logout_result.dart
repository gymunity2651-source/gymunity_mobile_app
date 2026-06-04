enum LogoutReason {
  userRequested,
  sessionExpired,
  accountDeleted,
  securityReset,
  userSwitch,
}

class LogoutResult {
  const LogoutResult.success() : message = null;

  const LogoutResult.failure(this.message);

  final String? message;

  bool get isSuccess => message == null;
}
