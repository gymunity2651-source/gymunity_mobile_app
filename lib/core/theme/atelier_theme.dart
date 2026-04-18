import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/atelier_colors.dart';

/// A scoped light [ThemeData] that implements the "Ethereal Atelier"
/// editorial wellness design system. Apply via `Theme(data: …)` around the
/// member home shell – the rest of the app continues to use the global dark
/// theme.
class AtelierTheme {
  AtelierTheme._();

  static ThemeData get light {
    // ── Color scheme ──
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AtelierColors.primary,
      onPrimary: AtelierColors.onPrimary,
      primaryContainer: AtelierColors.primaryContainer,
      onPrimaryContainer: AtelierColors.onPrimary,
      secondary: AtelierColors.primary,
      onSecondary: AtelierColors.onPrimary,
      surface: AtelierColors.surface,
      onSurface: AtelierColors.onSurface,
      error: AtelierColors.error,
      onError: AtelierColors.white,
      outline: AtelierColors.outlineVariant,
      outlineVariant: AtelierColors.ghostBorder,
      shadow: AtelierColors.navShadow,
    );

    // ── Typography ──
    final textTheme = TextTheme(
      // Display — luxury serif
      displayLarge: GoogleFonts.notoSerif(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -1.2,
        color: AtelierColors.onSurface,
      ),
      displayMedium: GoogleFonts.notoSerif(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: -0.6,
        color: AtelierColors.onSurface,
      ),
      displaySmall: GoogleFonts.notoSerif(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.12,
        color: AtelierColors.onSurface,
      ),

      // Headlines — editorial serif
      headlineLarge: GoogleFonts.notoSerif(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.14,
        color: AtelierColors.onSurface,
      ),
      headlineMedium: GoogleFonts.notoSerif(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.16,
        color: AtelierColors.onSurface,
      ),
      headlineSmall: GoogleFonts.notoSerif(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AtelierColors.onSurface,
      ),

      // Title — clean sans
      titleLarge: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AtelierColors.onSurface,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AtelierColors.onSurface,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AtelierColors.onSurface,
      ),

      // Body — readable sans
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AtelierColors.onSurface,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AtelierColors.onSurfaceVariant,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AtelierColors.textMuted,
      ),

      // Labels — uppercase captions
      labelLarge: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: AtelierColors.primary,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AtelierColors.onSurfaceVariant,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AtelierColors.textMuted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AtelierColors.surface,
      canvasColor: AtelierColors.surface,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: AtelierColors.surfaceContainerLowest,
        elevation: 0,
        shadowColor: AtelierColors.transparent,
        surfaceTintColor: AtelierColors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AtelierColors.onSurfaceVariant,
        size: 22,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AtelierColors.transparent,
        foregroundColor: AtelierColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: AtelierColors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
    );
  }
}
