import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../../../core/localization/app_localization_extension.dart';
import '../widgets/google_only_auth_screen.dart';

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GoogleOnlyAuthScreen(
      title: l10n.resetPasswordTitle,
      subtitle: l10n.resetPasswordSubtitle,
      helperText: l10n.resetPasswordHelper,
      secondaryActionLabel: l10n.backToSignIn,
      secondaryActionRoute: AppRoutes.login,
    );
  }
}
