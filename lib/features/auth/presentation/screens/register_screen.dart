import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../widgets/google_only_auth_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GoogleOnlyAuthScreen(
      title: 'Create your account with Google',
      subtitle:
          'Manual sign-up with name, email, and password has been removed from GymUnity.',
      helperText:
          'Your account is now created automatically after Google sign-in, then GymUnity will continue with role selection and onboarding.',
      secondaryActionLabel: 'Back to sign in',
      secondaryActionRoute: AppRoutes.login,
    );
  }
}
