import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/custom_button.dart';
import '../controllers/google_oauth_controller.dart';
import '../providers/auth_providers.dart';

class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({super.key, this.routeName});

  final String? routeName;

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(authFlowControllerProvider.notifier)
          .handleCallbackRoute(widget.routeName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authFlowState = ref.watch(authFlowControllerProvider);
    ref.listen<AuthFlowState>(authFlowControllerProvider, (previous, next) {
      if (!mounted) return;

      if (next.status == AuthFlowStatus.success &&
          next.resolvedRoute != null &&
          next.resolvedRoute != previous?.resolvedRoute) {
        ref.read(authFlowControllerProvider.notifier).clearOutcome();
        Navigator.pushNamedAndRemoveUntil(
          context,
          next.resolvedRoute!,
          (route) => false,
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.xxxl),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      authFlowState.status == AuthFlowStatus.failure
                          ? Icons.error_outline
                          : Icons.shield_outlined,
                      color: AppColors.orange,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    authFlowState.status == AuthFlowStatus.failure
                        ? (authFlowState.activeProvider == null
                              ? 'Password Recovery'
                              : '${authFlowState.activeProvider!.label} Sign-In')
                        : (authFlowState.activeProvider == null
                              ? AppStrings.completingPasswordRecovery
                              : AppStrings.completingGoogleSignIn),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    authFlowState.status == AuthFlowStatus.failure
                        ? (authFlowState.errorMessage ??
                              AppStrings.googleSignInDidNotComplete)
                        : (authFlowState.activeProvider == null
                              ? 'Please wait while GymUnity verifies your password recovery request.'
                              : 'Please wait while GymUnity links your account and restores your session.'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (authFlowState.status == AuthFlowStatus.failure)
                    CustomButton(
                      label: AppStrings.backToLogin.toUpperCase(),
                      onPressed: () {
                        ref
                            .read(authFlowControllerProvider.notifier)
                            .clearOutcome();
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (route) => false,
                        );
                      },
                    )
                  else
                    const CircularProgressIndicator(color: AppColors.limeGreen),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
