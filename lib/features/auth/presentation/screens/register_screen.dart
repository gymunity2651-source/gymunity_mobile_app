import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../../../core/localization/app_localization_extension.dart';
import '../widgets/google_only_auth_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GoogleOnlyAuthScreen(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      helperText: l10n.registerHelper,
      secondaryActionLabel: l10n.backToSignIn,
      secondaryActionRoute: AppRoutes.login,
    );
  }
}
