import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../widgets/google_only_auth_screen.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GoogleOnlyAuthScreen(
      title: 'Password login is disabled',
      subtitle:
          'GymUnity now uses Google sign-in only, so reset-password links are no longer part of the app flow.',
      helperText:
          'Go back to Google sign-in and continue with the Google account linked to GymUnity.',
      secondaryActionLabel: 'Back to sign in',
      secondaryActionRoute: AppRoutes.login,
    );
  }
}
