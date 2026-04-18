import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/atelier_colors.dart';
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
  static const Duration _minimumSplashDuration = Duration(milliseconds: 900);

  bool _hasNavigated = false;
  late final Future<void> _minimumDisplayFuture;
  ProviderSubscription<AppBootstrapState>? _bootstrapSubscription;
  ProviderSubscription<AuthFlowState>? _authFlowSubscription;

  @override
  void initState() {
    super.initState();
    _minimumDisplayFuture = Future<void>.delayed(_minimumSplashDuration);

    _bootstrapSubscription = ref.listenManual<AppBootstrapState>(
      appBootstrapControllerProvider,
      (previous, next) {
        _handleBootstrapState(next);
      },
      fireImmediately: true,
    );

    if (AppConfig.current.validationErrorMessage == null) {
      _authFlowSubscription = ref.listenManual<AuthFlowState>(
        authFlowControllerProvider,
        (previous, next) {
          _handleAuthFlowState(previous, next);
        },
        fireImmediately: true,
      );
    }
  }

  @override
  void dispose() {
    _bootstrapSubscription?.close();
    _authFlowSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapState = ref.watch(appBootstrapControllerProvider);
    final hasValidConfig = AppConfig.current.validationErrorMessage == null;
    final authFlowState = hasValidConfig
        ? ref.watch(authFlowControllerProvider)
        : const AuthFlowState();

    final showProgress =
        !_hasNavigated &&
        (bootstrapState.status == AppBootstrapStatus.loading ||
            bootstrapState.status == AppBootstrapStatus.authenticated ||
            bootstrapState.status == AppBootstrapStatus.unauthenticated ||
            authFlowState.isBusy);

    return Scaffold(
      backgroundColor: AtelierColors.surfaceContainerLowest,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              // GU Logo
              Text(
                'GU',
                style: GoogleFonts.notoSerif(
                  fontSize: 110,
                  fontWeight: FontWeight.w400,
                  color: AtelierColors.primary,
                  height: 1,
                  letterSpacing: -4,
                ),
              ),
              const Spacer(flex: 2),
              
              // Refining the Art of Self
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.notoSerif(
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    color: AtelierColors.onSurface,
                    height: 1.25,
                  ),
                  children: [
                    const TextSpan(text: 'Refining the '),
                    TextSpan(
                      text: 'Art',
                      style: GoogleFonts.notoSerif(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const TextSpan(text: ' of\nSelf'),
                  ],
                ),
              ),
              const SizedBox(height: 38),
              
              // Categories
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'FITNESS',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      color: AtelierColors.onSurfaceVariant,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '•',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AtelierColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    'TAIYO',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      color: AtelierColors.onSurfaceVariant,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '•',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AtelierColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    'COMMUNITY',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      color: AtelierColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Progress bar or Error Handling
              if (showProgress)
                Column(
                  children: [
                    SizedBox(
                      width: 240,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          color: AtelierColors.primary,
                          backgroundColor: AtelierColors.surfaceContainer,
                          minHeight: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'SYNCHRONIZING SANCTUARY',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                        color: AtelierColors.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                )
              else ...[
                if (bootstrapState.status == AppBootstrapStatus.deletedAccount && _canContactSupport)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: CustomButton(
                      label: 'CONTACT SUPPORT',
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.helpSupport);
                      },
                    ),
                  ),
                if (bootstrapState.status == AppBootstrapStatus.backendError ||
                    bootstrapState.status == AppBootstrapStatus.configError)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: CustomButton(
                      label: 'RETRY',
                      onPressed: () {
                        ref.read(appBootstrapControllerProvider.notifier).load();
                      },
                    ),
                  ),
                if (authFlowState.status == AuthFlowStatus.failure)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: CustomButton(
                      label: 'BACK TO LOGIN',
                      onPressed: () {
                        ref.read(authFlowControllerProvider.notifier).clearOutcome();
                        _navigateTo(AppRoutes.login);
                      },
                    ),
                  ),
              ],
              
              const Spacer(flex: 3),
              
              // Quote
              Text(
                '"Harmony is the highest form of discipline."',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSerif(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  color: AtelierColors.onSurfaceVariant.withValues(alpha: 0.7),
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

  void _handleAuthFlowState(
    AuthFlowState? previous,
    AuthFlowState next,
  ) {
    if (!mounted || _hasNavigated) {
      return;
    }

    if (next.status == AuthFlowStatus.success &&
        next.resolvedRoute != null &&
        next.resolvedRoute != previous?.resolvedRoute) {
      ref.read(authFlowControllerProvider.notifier).clearOutcome();
      _navigateTo(next.resolvedRoute!);
    }
  }

  void _navigateTo(String routeName) {
    if (!mounted || _hasNavigated) {
      return;
    }
    _hasNavigated = true;
    unawaited(_navigateAfterMinimumDisplay(routeName));
  }

  Future<void> _navigateAfterMinimumDisplay(String routeName) async {
    await _minimumDisplayFuture;
    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.pushReplacementNamed(context, routeName);
    });
  }
}
