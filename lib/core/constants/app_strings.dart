class AppStrings {
  AppStrings._();

  // ── App ──
  static const String appName = 'GymUnity';
  static const String tagline = 'FITNESS. AI. COMMUNITY.';
  static const String poweredBy = 'POWERED BY NEURALFIT ENGINE';

  // ── Welcome ──
  static const String welcomeHeadline = 'Your Fitness,\nUnified.';
  static const String welcomeSubtitle =
      'The all-in-one ecosystem for members,\ncoaches, and sellers powered by AI.';
  static const String getStarted = 'Get Started';
  static const String login = 'Login';
  static const String revolutionizing = 'REVOLUTIONIZING THE FITNESS INDUSTRY';

  // ── Login ──
  static const String welcomeBack = 'Welcome Back';
  static const String loginSubtitle = 'Elite fitness starts with a single step';
  static const String emailAddress = 'Email Address';
  static const String emailHint = 'name@example.com';
  static const String password = 'Password';
  static const String forgot = 'FORGOT?';
  static const String loginToDashboard = 'LOGIN TO DASHBOARD';
  static const String orContinueWith = 'OR CONTINUE WITH';
  static const String google = 'Google';
  static const String continueWithGoogle = 'Continue with Google';
  static const String apple = 'Apple';
  static const String noAccount = "Don't have an account?";
  static const String createAccount = 'Create Account';
  static const String googleSignInCancelled =
      'Google sign-in was cancelled before the account was linked.';
  static const String completingGoogleSignIn = 'Completing Google sign-in...';
  static const String googleSignInDidNotComplete =
      'Google sign-in did not complete. Check Google provider / redirect configuration and try again.';
  static const String googleSignInSetupHint =
      'Enable Google in Supabase and add the configured GymUnity redirect URI to the allowed redirect URLs.';
  static const String appleSignInSetupHint =
      'Enable Apple in Supabase and add the configured GymUnity redirect URI to the allowed redirect URLs.';
  static const String completingPasswordRecovery =
      'Completing password recovery...';
  static const String passwordRecoveryDidNotComplete =
      'Password recovery did not complete. Open the latest reset email and try the link again.';

  // ── Register ──
  static const String createYourAccount = 'Create Your Account';
  static const String registerSubtitle = 'Join the fitness revolution today';
  static const String fullName = 'Full Name';
  static const String fullNameHint = 'John Doe';
  static const String confirmPassword = 'Confirm Password';
  static const String register = 'CREATE ACCOUNT';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String loginNow = 'Log in';

  // ── Forgot password ──
  static const String forgotPassword = 'Forgot Password';
  static const String forgotSubtitle =
      'Enter your email and we\'ll send you\na password reset link';
  static const String sendResetCode = 'SEND RESET LINK';
  static const String backToLogin = 'Back to Login';
  static const String setNewPassword = 'Set New Password';
  static const String setNewPasswordSubtitle =
      'Choose a new password for your GymUnity account.';
  static const String updatePassword = 'UPDATE PASSWORD';

  // ── OTP ──
  static const String verification = 'Verification';
  static const String otpSubtitle = 'Enter the 6-digit code sent to';
  static const String verify = 'VERIFY CODE';
  static const String didntReceive = "Didn't receive code?";
  static const String resend = 'Resend';

  // ── Role selection ──
  static const String roleHeadline = 'Join the Movement as a...';
  static const String roleSubtitle =
      'Choose your role to start your fitness journey';
  static const String member = 'Member';
  static const String memberDesc =
      'Access personalized workouts, shop the store, and connect with elite coaches.';
  static const String memberCta = 'Get Started Today';
  static const String popular = 'POPULAR';
  static const String seller = 'Seller';
  static const String sellerDesc =
      'Sell your fitness products, manage inventory, and grow your brand globally.';
  static const String sellerCta = 'Grow Business';
  static const String coach = 'Coach';
  static const String coachDesc =
      'Manage your clients, sell professional training plans, and track progress.';
  static const String coachCta = 'Empower Others';
  static const String select = 'Select';
  static const String alreadyHaveAccountRole = 'Already have an account?';
  static const String logIn = 'Log in';

  static String oauthSignInDidNotComplete(String providerLabel) {
    return '$providerLabel sign-in did not complete. Check provider configuration and try again.';
  }
}
