import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/social_button.dart';
import '../controllers/google_oauth_controller.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(googleOAuthControllerProvider.notifier).handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final googleOAuthState = ref.watch(googleOAuthControllerProvider);
    ref.listen<GoogleOAuthState>(googleOAuthControllerProvider, (
      previous,
      next,
    ) {
      _handleGoogleOAuthState(previous, next);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.xxl,
                        vertical: AppSizes.xxxl,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.cardDark, AppColors.surfaceRaised],
                        ),
                        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
                        border: Border.all(
                          color: AppColors.borderLight,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.28),
                            blurRadius: 30,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: AppColors.textPrimary,
                                  size: 24,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                AppStrings.appName.toUpperCase(),
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.orange,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(width: 24),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.glass,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Text(
                              'Secure member access',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            AppStrings.welcomeBack,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.loginSubtitle,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          CustomTextField(
                            label: AppStrings.emailAddress,
                            hint: AppStrings.emailHint,
                            controller: _emailController,
                            prefixIcon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppStrings.password,
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.forgotPassword,
                                  );
                                },
                                child: Text(
                                  AppStrings.forgot,
                                  style: GoogleFonts.inter(
                                    color: AppColors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.sm),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: '........',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          CustomButton(
                            label: AppStrings.loginToDashboard,
                            isLoading: authState.isLoading,
                            onPressed: _login,
                          ),
                          const SizedBox(height: 28),
                          _buildOrDivider(),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: SocialButton(
                              label: AppStrings.continueWithGoogle,
                              icon: Icons.g_mobiledata,
                              expand: false,
                              onPressed: googleOAuthState.isBusy
                                  ? null
                                  : _signInWithGoogle,
                            ),
                          ),
                          if (googleOAuthState.isBusy) ...[
                            const SizedBox(height: 12),
                            Text(
                              AppStrings.completingGoogleSignIn,
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SocialButton(
                              label: AppStrings.apple,
                              icon: Icons.apple,
                              expand: false,
                              onPressed: () {
                                showAppFeedback(
                                  context,
                                  'Apple sign-in will be enabled after OAuth setup is connected.',
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppStrings.noAccount,
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.register,
                                  );
                                },
                                child: Text(
                                  AppStrings.createAccount,
                                  style: GoogleFonts.inter(
                                    color: AppColors.orange,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            AppStrings.orContinueWith,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Email and password are required.');
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .login(email: email, password: password);
    if (!mounted) return;

    if (!success) {
      final error =
          ref.read(authControllerProvider).errorMessage ??
          'Unable to login right now.';
      _showMessage(error);
      return;
    }

    final route = await ref.read(authRouteResolverProvider).resolveAfterAuth();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(googleOAuthControllerProvider.notifier).startGoogleOAuth();
  }

  void _handleGoogleOAuthState(
    GoogleOAuthState? previous,
    GoogleOAuthState next,
  ) {
    if (!mounted) return;

    if (next.status == GoogleOAuthStatus.success &&
        next.resolvedRoute != null &&
        next.resolvedRoute != previous?.resolvedRoute) {
      ref.read(googleOAuthControllerProvider.notifier).clearOutcome();
      Navigator.pushNamedAndRemoveUntil(
        context,
        next.resolvedRoute!,
        (route) => false,
      );
      return;
    }

    if (next.status == GoogleOAuthStatus.failure &&
        next.errorMessage != null &&
        next.errorMessage != previous?.errorMessage) {
      _showMessage(next.errorMessage!);
      ref.read(googleOAuthControllerProvider.notifier).clearOutcome();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background,
                  Color(0xFF0D1620),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -50,
          child: _GlowOrb(
            size: 220,
            color: AppColors.limeGreen.withValues(alpha: 0.10),
          ),
        ),
        Positioned(
          bottom: 20,
          left: -70,
          child: _GlowOrb(
            size: 240,
            color: AppColors.electricBlue.withValues(alpha: 0.10),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, AppColors.transparent]),
      ),
    );
  }
}
