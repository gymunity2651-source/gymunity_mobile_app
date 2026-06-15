import 'package:flutter/material.dart';

import '../../../../core/localization/app_localization_extension.dart';
import '../widgets/google_only_auth_screen.dart';
import '../widgets/pre_auth_scene.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GoogleOnlyAuthScreen(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      helperText: '',
      sceneSpec: localizedPreAuthEmpireSpec(
        context,
      ).copyWith(ctaLabel: l10n.continueWithGoogle),
      showHeader: false,
    );
  }
}
