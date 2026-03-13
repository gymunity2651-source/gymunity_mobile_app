import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/custom_button.dart';
import '../controllers/app_bootstrap_controller.dart';
import '../controllers/google_oauth_controller.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    final bootstrapState = ref.watch(appBootstrapControllerProvider);
    final hasValidConfig = AppConfig.current.validationErrorMessage == null;
    final authFlowState = hasValidConfig
        ? ref.watch(authFlowControllerProvider)
        : const AuthFlowState();

    _scheduleResolvedNavigation(bootstrapState, authFlowState);

    ref.listen<AppBootstrapState>(appBootstrapControllerProvider, (
      previous,
      next,
    ) {
      _handleBootstrapState(next);
    });
    if (hasValidConfig) {
      ref.listen<AuthFlowState>(authFlowControllerProvider, (previous, next) {
        if (!mounted || _hasNavigated) {
          return;
        }

        if (next.status == AuthFlowStatus.success &&
            next.resolvedRoute != null &&
            next.resolvedRoute != previous?.resolvedRoute) {
          ref.read(authFlowControllerProvider.notifier).clearOutcome();
          _navigateTo(next.resolvedRoute!);
        }
      });
    }

    final message = switch (bootstrapState.status) {
      AppBootstrapStatus.loading => 'Preparing your release environment...',
      AppBootstrapStatus.authenticated => 'Restoring your account...',
      AppBootstrapStatus.unauthenticated => 'Opening GymUnity...',
      AppBootstrapStatus.configError =>
        bootstrapState.message ??
            'GymUnity is missing required release configuration.',
      AppBootstrapStatus.backendError =>
        bootstrapState.message ?? 'GymUnity could not reach the backend.',
      AppBootstrapStatus.deletedAccount =>
        bootstrapState.message ?? 'This account is no longer available.',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'GU',
                style: GoogleFonts.inter(
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                  color: AppColors.limeGreen,
                  height: 1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.appName,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.tagline,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _headlineFor(bootstrapState, authFlowState),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (bootstrapState.status == AppBootstrapStatus.loading ||
                        authFlowState.isBusy)
                      const LinearProgressIndicator(
                        color: AppColors.limeGreen,
                        backgroundColor: AppColors.border,
                        minHeight: 4,
                      )
                    else ...[
                      if (bootstrapState.status ==
                              AppBootstrapStatus.deletedAccount &&
                          _canContactSupport)
                        CustomButton(
                          label: 'CONTACT SUPPORT',
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.helpSupport);
                          },
                        ),
                      if (bootstrapState.status ==
                              AppBootstrapStatus.backendError ||
                          bootstrapState.status ==
                              AppBootstrapStatus.configError)
                        CustomButton(
                          label: 'RETRY',
                          onPressed: () {
                            ref
                                .read(appBootstrapControllerProvider.notifier)
                                .load();
                          },
                        ),
                      if (authFlowState.status == AuthFlowStatus.failure)
                        CustomButton(
                          label: 'BACK TO LOGIN',
                          onPressed: () {
                            ref
                                .read(authFlowControllerProvider.notifier)
                                .clearOutcome();
                            _navigateTo(AppRoutes.login);
                          },
                        ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Environment: ${AppConfig.current.environment.value.toUpperCase()}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canContactSupport {
    final config = AppConfig.current;
    return config.supportUrl.trim().isNotEmpty ||
        config.supportEmail.trim().isNotEmpty;
  }

  String _headlineFor(
    AppBootstrapState bootstrapState,
    AuthFlowState authFlowState,
  ) {
    if (authFlowState.status == AuthFlowStatus.failure) {
      return authFlowState.activeProvider == null
          ? 'Password Recovery'
          : '${authFlowState.activeProvider!.label} Sign-In';
    }

    switch (bootstrapState.status) {
      case AppBootstrapStatus.loading:
        return 'Starting up';
      case AppBootstrapStatus.authenticated:
        return 'Restoring your session';
      case AppBootstrapStatus.unauthenticated:
        return 'Opening GymUnity';
      case AppBootstrapStatus.configError:
        return 'Configuration required';
      case AppBootstrapStatus.backendError:
        return 'Unable to finish startup';
      case AppBootstrapStatus.deletedAccount:
        return 'Account unavailable';
    }
  }

  void _handleBootstrapState(AppBootstrapState next) {
    if (!mounted || _hasNavigated) {
      return;
    }

    final routeName = next.routeName;
    if (routeName == null) {
      return;
    }

    if (next.status == AppBootstrapStatus.authenticated ||
        next.status == AppBootstrapStatus.unauthenticated) {
      _navigateTo(routeName);
    }
  }

  void _scheduleResolvedNavigation(
    AppBootstrapState bootstrapState,
    AuthFlowState authFlowState,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasNavigated) {
        return;
      }

      if (authFlowState.status == AuthFlowStatus.success &&
          authFlowState.resolvedRoute != null) {
        ref.read(authFlowControllerProvider.notifier).clearOutcome();
        _navigateTo(authFlowState.resolvedRoute!);
        return;
      }

      _handleBootstrapState(bootstrapState);
    });
  }

  void _navigateTo(String routeName) {
    if (!mounted || _hasNavigated) {
      return;
    }
    _hasNavigated = true;
    Navigator.pushReplacementNamed(context, routeName);
  }
}
