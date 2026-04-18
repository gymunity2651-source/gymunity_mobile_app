import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

enum ButtonVariant { primary, outlined, text }

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.height,
    this.borderRadius,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double? height;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppSizes.radiusMd;
    final h = height ?? AppSizes.buttonHeight;
    final foreground = foregroundColor ?? AppColors.white;

    switch (variant) {
      case ButtonVariant.primary:
        return SizedBox(
          width: double.infinity,
          height: h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor ?? AppColors.limeGreen,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.10),
              ),
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.transparent,
                foregroundColor: foreground,
                disabledBackgroundColor: AppColors.transparent,
                disabledForegroundColor: AppColors.textMuted,
                shadowColor: AppColors.transparent,
                surfaceTintColor: AppColors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              child: _buildChild(foreground),
            ),
          ),
        );

      case ButtonVariant.outlined:
        return SizedBox(
          width: double.infinity,
          height: h,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surface.withValues(alpha: 0.05),
              foregroundColor: foregroundColor ?? AppColors.textPrimary,
              side: BorderSide(
                color: borderColor ?? AppColors.borderLight,
                width: 1.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            child: _buildChild(foregroundColor ?? AppColors.textPrimary),
          ),
        );

      case ButtonVariant.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildChild(foregroundColor ?? AppColors.limeGreen),
        );
    }
  }

  Widget _buildChild(Color color) {
    if (isLoading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }
    return Text(
      label,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}
