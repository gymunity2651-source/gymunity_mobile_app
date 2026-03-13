enum AuthProviderType {
  emailPassword('email', 'Email'),
  google('google', 'Google'),
  apple('apple', 'Apple');

  const AuthProviderType(this.value, this.label);

  final String value;
  final String label;

  static AuthProviderType fromProviderId(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'google':
        return AuthProviderType.google;
      case 'apple':
        return AuthProviderType.apple;
      case 'email':
      default:
        return AuthProviderType.emailPassword;
    }
  }
}
