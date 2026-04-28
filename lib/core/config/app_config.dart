enum AppEnvironment {
  dev('dev'),
  staging('staging'),
  production('prod');

  const AppEnvironment(this.value);

  final String value;

  static AppEnvironment fromValue(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.production;
      case 'staging':
        return AppEnvironment.staging;
      case 'dev':
      case 'development':
      default:
        return AppEnvironment.dev;
    }
  }
}

class AppConfig {
  AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.authRedirectScheme,
    required this.authRedirectHost,
    required this.privacyPolicyUrl,
    required this.termsUrl,
    required this.supportUrl,
    required this.supportEmail,
    required this.supportEmailSubject,
    required this.reviewerLoginHelpUrl,
    required this.enableCoachRole,
    required this.enableSellerRole,
    required this.enableAppleSignIn,
    required this.enableStorePurchases,
    required this.enableCoachSubscriptions,
    this.enableCoachPaymobPayments = false,
    this.enableCoachManualPaymentProofs = true,
    this.enableAiPremium = false,
    this.appleAiPremiumMonthlyProductId = '',
    this.appleAiPremiumAnnualProductId = '',
    this.googleAiPremiumSubscriptionId = '',
    this.googleAiPremiumMonthlyBasePlanId = '',
    this.googleAiPremiumAnnualBasePlanId = '',
  });

  factory AppConfig.fromEnvironment() {
    final environment = AppEnvironment.fromValue(
      const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
    );

    String read(String key, {String? defaultValue}) {
      final value = switch (key) {
        'APP_ENV' => const String.fromEnvironment('APP_ENV', defaultValue: ''),
        'SUPABASE_URL' => const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: '',
        ),
        'SUPABASE_ANON_KEY' => const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue: '',
        ),
        'AUTH_REDIRECT_SCHEME' => const String.fromEnvironment(
          'AUTH_REDIRECT_SCHEME',
          defaultValue: '',
        ),
        'AUTH_REDIRECT_HOST' => const String.fromEnvironment(
          'AUTH_REDIRECT_HOST',
          defaultValue: '',
        ),
        'PRIVACY_POLICY_URL' => const String.fromEnvironment(
          'PRIVACY_POLICY_URL',
          defaultValue: '',
        ),
        'TERMS_OF_SERVICE_URL' => const String.fromEnvironment(
          'TERMS_OF_SERVICE_URL',
          defaultValue: '',
        ),
        'SUPPORT_URL' => const String.fromEnvironment(
          'SUPPORT_URL',
          defaultValue: '',
        ),
        'SUPPORT_EMAIL' => const String.fromEnvironment(
          'SUPPORT_EMAIL',
          defaultValue: '',
        ),
        'SUPPORT_EMAIL_SUBJECT' => const String.fromEnvironment(
          'SUPPORT_EMAIL_SUBJECT',
          defaultValue: '',
        ),
        'REVIEWER_LOGIN_HELP_URL' => const String.fromEnvironment(
          'REVIEWER_LOGIN_HELP_URL',
          defaultValue: '',
        ),
        'ENABLE_COACH_ROLE' => const String.fromEnvironment(
          'ENABLE_COACH_ROLE',
          defaultValue: '',
        ),
        'ENABLE_SELLER_ROLE' => const String.fromEnvironment(
          'ENABLE_SELLER_ROLE',
          defaultValue: '',
        ),
        'ENABLE_APPLE_SIGN_IN' => const String.fromEnvironment(
          'ENABLE_APPLE_SIGN_IN',
          defaultValue: '',
        ),
        'ENABLE_STORE_PURCHASES' => const String.fromEnvironment(
          'ENABLE_STORE_PURCHASES',
          defaultValue: '',
        ),
        'ENABLE_COACH_SUBSCRIPTIONS' => const String.fromEnvironment(
          'ENABLE_COACH_SUBSCRIPTIONS',
          defaultValue: '',
        ),
        'ENABLE_COACH_PAYMOB_PAYMENTS' => const String.fromEnvironment(
          'ENABLE_COACH_PAYMOB_PAYMENTS',
          defaultValue: '',
        ),
        'ENABLE_COACH_MANUAL_PAYMENT_PROOFS' => const String.fromEnvironment(
          'ENABLE_COACH_MANUAL_PAYMENT_PROOFS',
          defaultValue: '',
        ),
        'ENABLE_AI_PREMIUM' => const String.fromEnvironment(
          'ENABLE_AI_PREMIUM',
          defaultValue: '',
        ),
        'APPLE_AI_PREMIUM_MONTHLY_PRODUCT_ID' => const String.fromEnvironment(
          'APPLE_AI_PREMIUM_MONTHLY_PRODUCT_ID',
          defaultValue: '',
        ),
        'APPLE_AI_PREMIUM_ANNUAL_PRODUCT_ID' => const String.fromEnvironment(
          'APPLE_AI_PREMIUM_ANNUAL_PRODUCT_ID',
          defaultValue: '',
        ),
        'GOOGLE_AI_PREMIUM_SUBSCRIPTION_ID' => const String.fromEnvironment(
          'GOOGLE_AI_PREMIUM_SUBSCRIPTION_ID',
          defaultValue: '',
        ),
        'GOOGLE_AI_PREMIUM_MONTHLY_BASE_PLAN_ID' =>
          const String.fromEnvironment(
            'GOOGLE_AI_PREMIUM_MONTHLY_BASE_PLAN_ID',
            defaultValue: '',
          ),
        'GOOGLE_AI_PREMIUM_ANNUAL_BASE_PLAN_ID' => const String.fromEnvironment(
          'GOOGLE_AI_PREMIUM_ANNUAL_BASE_PLAN_ID',
          defaultValue: '',
        ),
        _ => '',
      };

      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
      return defaultValue ?? '';
    }

    bool readBool(String key, {required bool defaultValue}) {
      final raw = read(key).trim();
      if (raw.isEmpty) {
        return defaultValue;
      }
      return raw.toLowerCase() == 'true';
    }

    final defaultScheme = switch (environment) {
      AppEnvironment.dev => 'gymunity',
      AppEnvironment.staging => 'gymunity-staging',
      AppEnvironment.production => 'gymunity',
    };

    return AppConfig(
      environment: environment,
      supabaseUrl: read('SUPABASE_URL'),
      supabaseAnonKey: read('SUPABASE_ANON_KEY'),
      authRedirectScheme: read(
        'AUTH_REDIRECT_SCHEME',
        defaultValue: defaultScheme,
      ),
      authRedirectHost: read(
        'AUTH_REDIRECT_HOST',
        defaultValue: 'auth-callback',
      ),
      privacyPolicyUrl: read('PRIVACY_POLICY_URL'),
      termsUrl: read('TERMS_OF_SERVICE_URL'),
      supportUrl: read('SUPPORT_URL'),
      supportEmail: read('SUPPORT_EMAIL'),
      supportEmailSubject: read(
        'SUPPORT_EMAIL_SUBJECT',
        defaultValue: 'GymUnity support request',
      ),
      reviewerLoginHelpUrl: read('REVIEWER_LOGIN_HELP_URL'),
      enableCoachRole: readBool('ENABLE_COACH_ROLE', defaultValue: true),
      enableSellerRole: readBool('ENABLE_SELLER_ROLE', defaultValue: true),
      enableAppleSignIn: readBool('ENABLE_APPLE_SIGN_IN', defaultValue: true),
      enableStorePurchases: readBool(
        'ENABLE_STORE_PURCHASES',
        defaultValue: true,
      ),
      enableCoachSubscriptions: readBool(
        'ENABLE_COACH_SUBSCRIPTIONS',
        defaultValue: true,
      ),
      enableCoachPaymobPayments: readBool(
        'ENABLE_COACH_PAYMOB_PAYMENTS',
        defaultValue: false,
      ),
      enableCoachManualPaymentProofs: readBool(
        'ENABLE_COACH_MANUAL_PAYMENT_PROOFS',
        defaultValue: true,
      ),
      enableAiPremium: readBool('ENABLE_AI_PREMIUM', defaultValue: false),
      appleAiPremiumMonthlyProductId: read(
        'APPLE_AI_PREMIUM_MONTHLY_PRODUCT_ID',
      ),
      appleAiPremiumAnnualProductId: read('APPLE_AI_PREMIUM_ANNUAL_PRODUCT_ID'),
      googleAiPremiumSubscriptionId: read('GOOGLE_AI_PREMIUM_SUBSCRIPTION_ID'),
      googleAiPremiumMonthlyBasePlanId: read(
        'GOOGLE_AI_PREMIUM_MONTHLY_BASE_PLAN_ID',
      ),
      googleAiPremiumAnnualBasePlanId: read(
        'GOOGLE_AI_PREMIUM_ANNUAL_BASE_PLAN_ID',
      ),
    );
  }

  factory AppConfig.fromMap(Map<String, String> values) {
    return AppConfig._build(
      read: (key, {defaultValue}) {
        final value = values[key]?.trim() ?? '';
        if (value.isNotEmpty) {
          return value;
        }
        return defaultValue ?? '';
      },
    );
  }

  static AppConfig? _debugOverride;
  static AppConfig get current => _debugOverride ?? AppConfig.fromEnvironment();

  static void debugOverrideForTests(AppConfig config) {
    _debugOverride = config;
  }

  static void clearDebugOverride() {
    _debugOverride = null;
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String authRedirectScheme;
  final String authRedirectHost;
  final String privacyPolicyUrl;
  final String termsUrl;
  final String supportUrl;
  final String supportEmail;
  final String supportEmailSubject;
  final String reviewerLoginHelpUrl;
  final bool enableCoachRole;
  final bool enableSellerRole;
  final bool enableAppleSignIn;
  final bool enableStorePurchases;
  final bool enableCoachSubscriptions;
  final bool enableCoachPaymobPayments;
  final bool enableCoachManualPaymentProofs;
  final bool enableAiPremium;
  final String appleAiPremiumMonthlyProductId;
  final String appleAiPremiumAnnualProductId;
  final String googleAiPremiumSubscriptionId;
  final String googleAiPremiumMonthlyBasePlanId;
  final String googleAiPremiumAnnualBasePlanId;

  bool get isProduction => environment == AppEnvironment.production;
  bool get isStaging => environment == AppEnvironment.staging;
  bool get isDevelopment => environment == AppEnvironment.dev;
  bool get supportsReviewerHelpUrl => reviewerLoginHelpUrl.trim().isNotEmpty;

  String get authRedirectUri => '$authRedirectScheme://$authRedirectHost';
  List<String> get acceptedAuthRedirectSchemes {
    final schemes = <String>{authRedirectScheme.trim()};
    if (isDevelopment) {
      schemes.add('gymunity');
      schemes.add('gymunity-dev');
    }
    schemes.removeWhere((scheme) => scheme.isEmpty);
    return schemes.toList(growable: false);
  }

  List<String> validationErrors() {
    final errors = <String>[];

    if (supabaseUrl.trim().isEmpty) {
      errors.add('SUPABASE_URL is missing.');
    } else if (!_isValidUrl(supabaseUrl)) {
      errors.add('SUPABASE_URL must be a valid absolute URL.');
    }

    if (supabaseAnonKey.trim().isEmpty) {
      errors.add('SUPABASE_ANON_KEY is missing.');
    }

    if (authRedirectScheme.trim().isEmpty) {
      errors.add('AUTH_REDIRECT_SCHEME is missing.');
    }

    if (authRedirectHost.trim().isEmpty) {
      errors.add('AUTH_REDIRECT_HOST is missing.');
    }

    if (reviewerLoginHelpUrl.trim().isNotEmpty &&
        !_isValidUrl(reviewerLoginHelpUrl)) {
      errors.add('REVIEWER_LOGIN_HELP_URL must be a valid absolute URL.');
    }

    if (supportUrl.trim().isNotEmpty && !_isValidUrl(supportUrl)) {
      errors.add('SUPPORT_URL must be a valid absolute URL.');
    }

    if (privacyPolicyUrl.trim().isNotEmpty && !_isValidUrl(privacyPolicyUrl)) {
      errors.add('PRIVACY_POLICY_URL must be a valid absolute URL.');
    }

    if (termsUrl.trim().isNotEmpty && !_isValidUrl(termsUrl)) {
      errors.add('TERMS_OF_SERVICE_URL must be a valid absolute URL.');
    }

    if (supportEmail.trim().isNotEmpty && !supportEmail.contains('@')) {
      errors.add('SUPPORT_EMAIL must be a valid email address.');
    }

    if (isProduction) {
      if (privacyPolicyUrl.trim().isEmpty) {
        errors.add('PRIVACY_POLICY_URL is required for production.');
      }
      if (supportUrl.trim().isEmpty && supportEmail.trim().isEmpty) {
        errors.add(
          'At least one support contact is required in production: SUPPORT_URL or SUPPORT_EMAIL.',
        );
      }
    }

    if (enableAiPremium) {
      if (appleAiPremiumMonthlyProductId.trim().isEmpty) {
        errors.add(
          'APPLE_AI_PREMIUM_MONTHLY_PRODUCT_ID is required when ENABLE_AI_PREMIUM is true.',
        );
      }
      if (appleAiPremiumAnnualProductId.trim().isEmpty) {
        errors.add(
          'APPLE_AI_PREMIUM_ANNUAL_PRODUCT_ID is required when ENABLE_AI_PREMIUM is true.',
        );
      }
      if (googleAiPremiumSubscriptionId.trim().isEmpty) {
        errors.add(
          'GOOGLE_AI_PREMIUM_SUBSCRIPTION_ID is required when ENABLE_AI_PREMIUM is true.',
        );
      }
      if (googleAiPremiumMonthlyBasePlanId.trim().isEmpty) {
        errors.add(
          'GOOGLE_AI_PREMIUM_MONTHLY_BASE_PLAN_ID is required when ENABLE_AI_PREMIUM is true.',
        );
      }
      if (googleAiPremiumAnnualBasePlanId.trim().isEmpty) {
        errors.add(
          'GOOGLE_AI_PREMIUM_ANNUAL_BASE_PLAN_ID is required when ENABLE_AI_PREMIUM is true.',
        );
      }
    }

    return errors;
  }

  String? get validationErrorMessage {
    final errors = validationErrors();
    if (errors.isEmpty) {
      return null;
    }
    return errors.join('\n');
  }

  static AppConfig _build({
    required String Function(String key, {String? defaultValue}) read,
  }) {
    bool readBool(String key, {required bool defaultValue}) {
      final raw = read(key).trim();
      if (raw.isEmpty) {
        return defaultValue;
      }
      return raw.toLowerCase() == 'true';
    }

    final environment = AppEnvironment.fromValue(
      read('APP_ENV', defaultValue: 'dev'),
    );

    final defaultScheme = switch (environment) {
      AppEnvironment.dev => 'gymunity',
      AppEnvironment.staging => 'gymunity-staging',
      AppEnvironment.production => 'gymunity',
    };

    return AppConfig(
      environment: environment,
      supabaseUrl: read('SUPABASE_URL'),
      supabaseAnonKey: read('SUPABASE_ANON_KEY'),
      authRedirectScheme: read(
        'AUTH_REDIRECT_SCHEME',
        defaultValue: defaultScheme,
      ),
      authRedirectHost: read(
        'AUTH_REDIRECT_HOST',
        defaultValue: 'auth-callback',
      ),
      privacyPolicyUrl: read('PRIVACY_POLICY_URL'),
      termsUrl: read('TERMS_OF_SERVICE_URL'),
      supportUrl: read('SUPPORT_URL'),
      supportEmail: read('SUPPORT_EMAIL'),
      supportEmailSubject: read(
        'SUPPORT_EMAIL_SUBJECT',
        defaultValue: 'GymUnity support request',
      ),
      reviewerLoginHelpUrl: read('REVIEWER_LOGIN_HELP_URL'),
      enableCoachRole: readBool('ENABLE_COACH_ROLE', defaultValue: true),
      enableSellerRole: readBool('ENABLE_SELLER_ROLE', defaultValue: true),
      enableAppleSignIn: readBool('ENABLE_APPLE_SIGN_IN', defaultValue: true),
      enableStorePurchases: readBool(
        'ENABLE_STORE_PURCHASES',
        defaultValue: true,
      ),
      enableCoachSubscriptions: readBool(
        'ENABLE_COACH_SUBSCRIPTIONS',
        defaultValue: true,
      ),
      enableCoachPaymobPayments: readBool(
        'ENABLE_COACH_PAYMOB_PAYMENTS',
        defaultValue: false,
      ),
      enableCoachManualPaymentProofs: readBool(
        'ENABLE_COACH_MANUAL_PAYMENT_PROOFS',
        defaultValue: true,
      ),
      enableAiPremium: readBool('ENABLE_AI_PREMIUM', defaultValue: false),
      appleAiPremiumMonthlyProductId: read(
        'APPLE_AI_PREMIUM_MONTHLY_PRODUCT_ID',
      ),
      appleAiPremiumAnnualProductId: read('APPLE_AI_PREMIUM_ANNUAL_PRODUCT_ID'),
      googleAiPremiumSubscriptionId: read('GOOGLE_AI_PREMIUM_SUBSCRIPTION_ID'),
      googleAiPremiumMonthlyBasePlanId: read(
        'GOOGLE_AI_PREMIUM_MONTHLY_BASE_PLAN_ID',
      ),
      googleAiPremiumAnnualBasePlanId: read(
        'GOOGLE_AI_PREMIUM_ANNUAL_BASE_PLAN_ID',
      ),
    );
  }

  static bool _isValidUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}
