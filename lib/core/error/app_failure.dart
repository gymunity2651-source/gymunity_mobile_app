class AppFailure implements Exception {
  const AppFailure({
    required this.message,
    this.code,
    this.cause,
    this.stackTrace,
  });

  final String message;
  final String? code;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppFailure(code: $code, message: $message)';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

class AuthFailure extends AppFailure {
  const AuthFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

class StorageFailure extends AppFailure {
  const StorageFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

class ConflictFailure extends AppFailure {
  const ConflictFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

class PaymentFailure extends AppFailure {
  const PaymentFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

class ConfigFailure extends AppFailure {
  const ConfigFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

class AccountDeletedFailure extends AppFailure {
  const AccountDeletedFailure({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}
