import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppShellBackground extends StatelessWidget {
  const AppShellBackground({
    super.key,
    required this.child,
    this.topGlowColor = AppColors.glowBlue,
    this.bottomGlowColor = AppColors.glowLime,
    this.showTexture = true,
  });

  final Widget child;
  final Color topGlowColor;
  final Color bottomGlowColor;
  final bool showTexture;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundTop,
            AppColors.background,
            AppColors.backgroundBottom,
          ],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -70,
            child: _GlowOrb(size: 280, color: topGlowColor),
          ),
          Positioned(
            top: 190,
            left: -120,
            child: _GlowOrb(size: 260, color: AppColors.glowOrange),
          ),
          Positioned(
            bottom: -110,
            left: 12,
            child: _GlowOrb(size: 240, color: bottomGlowColor),
          ),
          if (showTexture)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.white.withValues(alpha: 0.02),
                        AppColors.transparent,
                        AppColors.black.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.18),
              AppColors.transparent,
            ],
            stops: const [0, 0.42, 1],
          ),
        ),
      ),
    );
  }
}
