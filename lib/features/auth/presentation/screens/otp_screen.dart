import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../domain/entities/otp_flow.dart';
import '../widgets/google_only_auth_screen.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({
    super.key,
    required this.email,
    this.mode = OtpFlowMode.signup,
  });

  final String email;
  final OtpFlowMode mode;

  @override
  Widget build(BuildContext context) {
    final emailLabel = email.isEmpty ? 'your email address' : email;
    final flowLabel = mode == OtpFlowMode.signup ? 'sign-up' : 'login';
    return GoogleOnlyAuthScreen(
      title: 'Verification codes are no longer used',
      subtitle:
          'GymUnity no longer completes sign-up or login with email OTP codes.',
      helperText:
          'The previous $flowLabel verification target was $emailLabel. Continue with Google instead.',
      secondaryActionLabel: 'Back to sign in',
      secondaryActionRoute: AppRoutes.login,
    );
  }
}
