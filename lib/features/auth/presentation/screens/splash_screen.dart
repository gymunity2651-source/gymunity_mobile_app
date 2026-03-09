import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/providers.dart';
import '../controllers/google_oauth_controller.dart';
import '../providers/auth_providers.dart';

/// Splash screen — ref: assets/images/splash_screen.png
///
/// Black background, centered neon-green "GU" logo text,
/// app title + tagline, animated progress bar, bottom icons + powered-by line.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  Timer? _navigationTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();

    _navigationTimer = Timer(const Duration(seconds: 3), _resolveAndNavigate);
  }

  Future<void> _resolveAndNavigate() async {
    if (!mounted || _hasNavigated) return;

    final googleOAuthState = ref.read(googleOAuthControllerProvider);
    if (googleOAuthState.isBusy) {
      await ref.read(googleOAuthControllerProvider.notifier).handleAppResumed();
      return;
    }

    String routeName = AppRoutes.welcome;
    try {
      routeName = await ref
          .read(authRouteResolverProvider)
          .resolveInitialRoute();
    } catch (_) {
      routeName = AppRoutes.welcome;
    }
    _navigateTo(routeName);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GoogleOAuthState>(googleOAuthControllerProvider, (
      previous,
      next,
    ) {
      if (!mounted || _hasNavigated) return;

      if (next.status == GoogleOAuthStatus.success &&
          next.resolvedRoute != null &&
          next.resolvedRoute != previous?.resolvedRoute) {
        ref.read(googleOAuthControllerProvider.notifier).clearOutcome();
        _navigateTo(next.resolvedRoute!);
        return;
      }

      if (next.status == GoogleOAuthStatus.failure &&
          next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ref.read(googleOAuthControllerProvider.notifier).clearOutcome();
        _navigateTo(AppRoutes.login);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),

            // ── Logo "GU" ──
            Text(
              'GU',
              style: GoogleFonts.inter(
                fontSize: 100,
                fontWeight: FontWeight.w900,
                color: AppColors.limeGreen,
                height: 1,
              ),
            ),
            const SizedBox(height: 16),

            // ── App name ──
            Text(
              AppStrings.appName,
              style: GoogleFonts.inter(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // ── Tagline ──
            Text(
              AppStrings.tagline,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 40),

            // ── Progress bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progressController.value,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.limeGreen,
                      ),
                      minHeight: 4,
                    ),
                  );
                },
              ),
            ),

            const Spacer(flex: 3),

            // ── Bottom icons ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.bolt, color: AppColors.textMuted, size: 20),
                SizedBox(width: 24),
                Icon(
                  Icons.settings_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                SizedBox(width: 24),
                Icon(
                  Icons.group_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Powered by ──
            Text(
              AppStrings.poweredBy,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _navigateTo(String routeName) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    Navigator.pushReplacementNamed(context, routeName);
  }
}
