import 'package:flutter/material.dart';

import 'atelier_colors.dart';

/// Legacy AppColors mapped directly to the new Ethereal Atelier DNA.
/// This ensures the entire app inherits the Ivory/Sand & Rust aesthetic instantly!
class AppColors {
  AppColors._();

  // Primary backgrounds (Now Ivory/Sand instead of Dark/Black)
  static const Color backgroundTop = AtelierColors.surfaceContainerLowest; // #FFFFFF
  static const Color background = AtelierColors.surfaceContainerLowest; // #FFFFFF
  static const Color backgroundBottom = AtelierColors.surfaceContainerLowest; // #FFFFFF
  static const Color surface = AtelierColors.surfaceContainerLowest; // #FFFFFF
  static const Color cardDark = AtelierColors.surfaceContainerLow; // #F4F3F1
  static const Color cardSoft = AtelierColors.surfaceContainer; // #EEEDEB
  static const Color surfaceRaised = AtelierColors.surfaceContainer; // #EEEDEB
  static const Color surfacePanel = AtelierColors.surfaceContainerLow; // #F4F3F1
  static const Color fieldFill = AtelierColors.white;
  static const Color glass = AtelierColors.glass; // Ivory @ 80%

  // Accent (Neon Green -> Atelier Rust Primary)
  static const Color limeGreen = AtelierColors.primary;
  static const Color limeGreenSoft = AtelierColors.primaryContainer;
  static const Color orange = AtelierColors.primary;
  static const Color orangeLight = AtelierColors.primaryContainer;
  static const Color electricBlue = AtelierColors.primary; // Re-mapping generic colors to brand
  static const Color aqua = AtelierColors.primary;
  static const Color glowBlue = AtelierColors.transparent; // Remove neon glows
  static const Color glowLime = AtelierColors.transparent;
  static const Color glowOrange = AtelierColors.transparent;

  // Text (Inverted logic: White Text -> Dark Text)
  static const Color textPrimary = AtelierColors.onSurface; // #1A1C1A
  static const Color textSecondary = AtelierColors.onSurfaceVariant; // #6B6B6B
  static const Color textMuted = AtelierColors.textMuted; // #999999
  static const Color textDark = AtelierColors.onSurface;

  // Borders
  static const Color border = AtelierColors.outlineVariant;
  static const Color borderLight = AtelierColors.ghostBorder;
  static const Color borderSoft = AtelierColors.outlineVariant;

  // Status
  static const Color success = AtelierColors.success;
  static const Color error = AtelierColors.error;
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Misc
  static const Color shimmer = AtelierColors.surfaceDim;
  static const Color overlay = Color(0x33000000); // Lighter overlay for light mode
  static const Color white = AtelierColors.white;
  static const Color black = AtelierColors.onSurface;
  static const Color transparent = AtelierColors.transparent;

  // Light theme variants (Already matching main flow now)
  static const Color lightBackground = AtelierColors.surfaceContainerLowest;
  static const Color lightSurface = AtelierColors.surfaceContainerLowest;
  static const Color lightCard = AtelierColors.surfaceContainerLow;
}
