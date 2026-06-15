import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../../../core/localization/app_localization_extension.dart';
import '../widgets/google_only_auth_screen.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GoogleOnlyAuthScreen(
      title: l10n.forgotPasswordTitle,
      subtitle: l10n.forgotPasswordSubtitle,
      helperText: l10n.forgotPasswordHelper,
      secondaryActionLabel: l10n.backToSignIn,
      secondaryActionRoute: AppRoutes.login,
    );
  }
}
