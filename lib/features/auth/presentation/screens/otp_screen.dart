import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../domain/entities/otp_flow.dart';
import '../providers/auth_providers.dart';

/// OTP verification screen â€” dark-card style, 6-digit input boxes, timer.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.email,
    this.mode = OtpFlowMode.signup,
  });

  final String email;
  final OtpFlowMode mode;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const int _otpLength = 6;

  final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  int _secondsRemaining = 60;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final boxSize = MediaQuery.of(context).size.width > 420 ? 46.0 : 40.0;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      // â”€â”€ Back + Brand â”€â”€
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
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.orange,
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 24),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // â”€â”€ Icon â”€â”€
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.limeGreen.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_outlined,
                          color: AppColors.limeGreen,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // â”€â”€ Heading â”€â”€
                      Text(
                        AppStrings.verification,
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.otpSubtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.email.isNotEmpty ? widget.email : 'your email',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.limeGreen,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // â”€â”€ OTP Boxes â”€â”€
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_otpLength, (index) {
                          return SizedBox(
                            width: boxSize,
                            height: AppSizes.otpBoxSize,
                            child: TextFormField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMd,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusMd,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.limeGreen,
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: AppColors.fieldFill,
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty &&
                                    index < _otpLength - 1) {
                                  _focusNodes[index + 1].requestFocus();
                                }
                                if (value.isEmpty && index > 0) {
                                  _focusNodes[index - 1].requestFocus();
                                }
                              },
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),

                      // â”€â”€ Timer â”€â”€
                      Text(
                        _secondsRemaining > 0
                            ? '00:${_secondsRemaining.toString().padLeft(2, '0')}'
                            : '',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // â”€â”€ CTA â”€â”€
                      CustomButton(
                        label: AppStrings.verify,
                        isLoading: authState.isLoading,
                        onPressed: () {
                          _verifyOtp();
                        },
                      ),
                      const SizedBox(height: 24),

                      // â”€â”€ Resend â”€â”€
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppStrings.didntReceive,
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _secondsRemaining == 0
                                ? () {
                                    setState(() => _secondsRemaining = 60);
                                    _startTimer();
                                    _resendCode();
                                  }
                                : null,
                            child: Text(
                              AppStrings.resend,
                              style: GoogleFonts.inter(
                                color: _secondsRemaining == 0
                                    ? AppColors.limeGreen
                                    : AppColors.textMuted,
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
    );
  }

  Future<void> _verifyOtp() async {
    final token = _controllers.map((c) => c.text).join().trim();
    if (token.length != _otpLength) {
      _showMessage('Enter the 6-digit verification code.');
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(email: widget.email, token: token, mode: widget.mode);
    if (!mounted) return;

    if (!success) {
      final error =
          ref.read(authControllerProvider).errorMessage ??
          'Invalid verification code.';
      _showMessage(error);
      return;
    }

    try {
      final route = await ref
          .read(authRouteResolverProvider)
          .resolveAfterAuth();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Unable to load your account state right now. Please try again.',
      );
    }
  }

  Future<void> _resendCode() async {
    final sent = await ref
        .read(authControllerProvider.notifier)
        .sendOtp(email: widget.email, mode: widget.mode);
    if (!mounted || sent) return;
    final error =
        ref.read(authControllerProvider).errorMessage ??
        'Unable to resend code.';
    _showMessage(error);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
