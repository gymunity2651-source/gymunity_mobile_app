import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../widgets/google_only_auth_screen.dart';
import '../widgets/pre_auth_scene.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GoogleOnlyAuthScreen(
      title: 'Build Your Fitness Empire.',
      subtitle:
          'Sell products, coach others, and grow your fitness brand with ease. The tools that move with you.',
      helperText: '',
      sceneSpec: preAuthEmpireSpec.copyWith(
        ctaLabel: AppStrings.continueWithGoogle,
      ),
      showHeader: false,
    );
  }
}
