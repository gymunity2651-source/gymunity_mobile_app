import 'package:flutter/material.dart';

/// Design-system color tokens for the "Ethereal Atelier" light editorial
/// palette. Used exclusively in the member home screen via a scoped
/// [Theme] override – the rest of the app keeps the dark theme.
class AtelierColors {
  AtelierColors._();

  // ── Surfaces (layered ivory paper) ──
  static const Color surface = Color(0xFFFAF9F6);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color warmBackground = Color(0xFFF0D2C0);
  static const Color surfaceContainerLow = Color(0xFFF4F3F1);
  static const Color surfaceContainer = Color(0xFFEEEDEB);
  static const Color surfaceDim = Color(0xFFE5E4E2);
  static const Color darkCard = Color(0xFF3A3633);

  // ── Primary accent (coral → apricot) ──
  static const Color primary = Color(0xFFA43C12);
  static const Color primaryContainer = Color(0xFFFF7F50);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Text ──
  static const Color onSurface = Color(0xFF1A1C1A);
  static const Color onSurfaceVariant = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF999999);

  // ── Outlines ──
  static const Color outlineVariant = Color(0xFFD4D4D4);
  static const Color ghostBorder = Color(0x26D4D4D4); // ~15 % opacity

  // ── Status ──
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF5350);

  // ── Glass / overlay ──
  static const Color glass = Color(0xCCFAF9F6); // surface @ 80 %
  static const Color warmGlass = Color(0xCCF0D2C0); // warmBackground @ 80 %
  static const Color navShadow = Color(0x0D1A1C1A); // onSurface @ 5 %

  // ── Misc ──
  static const Color white = Color(0xFFFFFFFF);
  static const Color transparent = Color(0x00000000);

  // ── Gradient helpers ──
  static List<Color> get primaryGradient => const [primary, primaryContainer];
}
