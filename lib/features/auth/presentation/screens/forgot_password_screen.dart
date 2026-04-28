import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../widgets/google_only_auth_screen.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GoogleOnlyAuthScreen(
      title: 'Password reset is no longer used',
      subtitle:
          'GymUnity no longer signs users in with email codes or password reset links.',
      helperText:
          'Continue with the Google account linked to your GymUnity profile instead.',
      secondaryActionLabel: 'Back to sign in',
      secondaryActionRoute: AppRoutes.login,
    );
  }
}
