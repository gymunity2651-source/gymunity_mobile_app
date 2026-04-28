import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

enum OnboardingVisualStyle { legacyDark, curatedSanctuary }

const Color _curatedSurface = Color(0xFFFAF9F6);
const Color _curatedSurfaceLow = Color(0xFFF4F3F1);
const Color _curatedSurfaceHighest = Color(0xFFFFFFFF);
const Color _curatedPrimary = Color(0xFF822700);
const Color _curatedSecondary = Color(0xFFFE7E4F);
const Color _curatedText = Color(0xFF1A1C1A);
const Color _curatedTextSoft = Color(0xFF6B6B6B);
const Color _curatedGhostBorder = Color(0x26D4D4D4);
const Color _curatedGlass = Color(0xCCFAF9F6);
const Color _curatedShadow = Color(0x0D1A1C1A);

class OnboardingScreenFrame extends StatelessWidget {
  const OnboardingScreenFrame({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.content,
    required this.primaryLabel,
    required this.onPrimaryAction,
    required this.onBack,
    required this.footerText,
    this.isLoading = false,
    this.visualStyle = OnboardingVisualStyle.legacyDark,
    this.showFooterText = true,
  });

  final int currentStep;
  final int totalSteps;
  final Widget content;
  final String primaryLabel;
  final VoidCallback onPrimaryAction;
  final VoidCallback onBack;
  final String footerText;
  final bool isLoading;
  final OnboardingVisualStyle visualStyle;
  final bool showFooterText;

  bool get _isCurated => visualStyle == OnboardingVisualStyle.curatedSanctuary;

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;

    return Scaffold(
      backgroundColor: _isCurated ? _curatedSurface : AppColors.background,
      body: Stack(
        children: [
          OnboardingBackdrop(visualStyle: visualStyle),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _isCurated ? 18 : AppSizes.screenPadding,
                    _isCurated ? 12 : AppSizes.xl,
                    _isCurated ? 18 : AppSizes.screenPadding,
                    _isCurated ? 18 : AppSizes.lg,
                  ),
                  child: _buildHeader(progress),
                ),
                Expanded(child: content),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _isCurated ? 14 : AppSizes.screenPadding,
                    _isCurated ? 8 : AppSizes.md,
                    _isCurated ? 14 : AppSizes.screenPadding,
                    _isCurated ? 18 : AppSizes.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OnboardingPrimaryActionButton(
                        label: primaryLabel,
                        onTap: onPrimaryAction,
                        isLoading: isLoading,
                        visualStyle: visualStyle,
                      ),
                      if (showFooterText && footerText.trim().isNotEmpty) ...[
                        SizedBox(height: _isCurated ? 14 : 18),
                        Text(
                          footerText,
                          textAlign: _isCurated
                              ? TextAlign.left
                              : TextAlign.center,
                          style: _isCurated
                              ? GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: _curatedTextSoft,
                                  height: 1.65,
                                )
                              : GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                  height: 1.5,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double progress) {
    if (_isCurated) {
      return Row(
        children: [
          OnboardingBackChip(onTap: onBack, visualStyle: visualStyle),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: OnboardingStepProgress(
                step: currentStep + 1,
                totalSteps: totalSteps,
                progress: progress,
                visualStyle: visualStyle,
              ),
            ),
          ),
          const SizedBox(width: 48, height: 48),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OnboardingBackChip(onTap: onBack),
        const Spacer(),
        OnboardingStepProgress(
          step: currentStep + 1,
          totalSteps: totalSteps,
          progress: progress,
        ),
      ],
    );
  }
}

class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({
    super.key,
    this.visualStyle = OnboardingVisualStyle.legacyDark,
  });

  final OnboardingVisualStyle visualStyle;

  bool get _isCurated => visualStyle == OnboardingVisualStyle.curatedSanctuary;

  @override
  Widget build(BuildContext context) {
    if (_isCurated) {
      return Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _curatedSurface,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFFFDFBF8),
                    _curatedSurface,
                    Color(0xFFF7F2ED),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -40,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[Color(0x22FE7E4F), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[Color(0x14A43C12), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[Color(0x12FE7E4F), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF040608),
                  Color(0xFF06090D),
                  Color(0xFF040608),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -90,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.orange.withValues(alpha: 0.12),
                  AppColors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -160,
          right: -60,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.limeGreen.withValues(alpha: 0.09),
                  AppColors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingBackChip extends StatelessWidget {
  const OnboardingBackChip({
    super.key,
    required this.onTap,
    this.visualStyle = OnboardingVisualStyle.legacyDark,
  });

  final VoidCallback onTap;
  final OnboardingVisualStyle visualStyle;

  bool get _isCurated => visualStyle == OnboardingVisualStyle.curatedSanctuary;

  @override
  Widget build(BuildContext context) {
    if (_isCurated) {
      return GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: _curatedGlass,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _curatedShadow,
                    blurRadius: 30,
                    spreadRadius: -6,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _curatedText,
                size: 22,
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Icon(Icons.arrow_back, color: AppColors.white, size: 26),
      ),
    );
  }
}

class OnboardingStepProgress extends StatelessWidget {
  const OnboardingStepProgress({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.progress,
    this.visualStyle = OnboardingVisualStyle.legacyDark,
  });

  final int step;
  final int totalSteps;
  final double progress;
  final OnboardingVisualStyle visualStyle;

  bool get _isCurated => visualStyle == OnboardingVisualStyle.curatedSanctuary;

  @override
  Widget build(BuildContext context) {
    if (_isCurated) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'STEP $step OF $totalSteps',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.8,
              color: _curatedTextSoft,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 136,
            child: Row(
              children: List<Widget>.generate(totalSteps, (index) {
                final isReached = index < step;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                      right: index == totalSteps - 1 ? 0 : 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      color: isReached
                          ? _curatedPrimary
                          : _curatedText.withValues(alpha: 0.08),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'STEP $step OF $totalSteps',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 124,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.white.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingStepHeading extends StatelessWidget {
  const OnboardingStepHeading({
    super.key,
    required this.title,
    required this.accent,
    required this.subtitle,
    this.visualStyle = OnboardingVisualStyle.legacyDark,
  });

  final String title;
  final String accent;
  final String subtitle;
  final OnboardingVisualStyle visualStyle;

  bool get _isCurated => visualStyle == OnboardingVisualStyle.curatedSanctuary;

  @override
  Widget build(BuildContext context) {
    if (_isCurated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title\n',
                    style: GoogleFonts.notoSerif(
                      fontSize: 40,
                      fontWeight: FontWeight.w500,
                      height: 1.18,
                      letterSpacing: -1.2,
                      color: _curatedText,
                    ),
                  ),
                  TextSpan(
                    text: accent,
                    style: GoogleFonts.notoSerif(
                      fontSize: 40,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      height: 1.18,
                      letterSpacing: -1.2,
                      color: _curatedPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 292),
            child: Text(
              subtitle,
              style: GoogleFonts.manrope(
                fontSize: 15,
                height: 1.75,
                color: _curatedTextSoft,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$title\n',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.08,
                  letterSpacing: -0.7,
                  color: AppColors.textPrimary,
                ),
              ),
              TextSpan(
                text: accent,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.08,
                  letterSpacing: -0.7,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.65,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.visualStyle = OnboardingVisualStyle.legacyDark,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final OnboardingVisualStyle visualStyle;

  bool get _isCurated => visualStyle == OnboardingVisualStyle.curatedSanctuary;

  @override
  Widget build(BuildContext context) {
    if (_isCurated) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          decoration: BoxDecoration(
            color: selected ? _curatedSurfaceHighest : _curatedSurfaceLow,
            borderRadius: BorderRadius.circular(34),
            border: selected
                ? Border.all(color: _curatedPrimary.withValues(alpha: 0.88))
                : null,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _curatedShadow,
                blurRadius: 40,
                spreadRadius: -6,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? _curatedPrimary.withValues(alpha: 0.08)
                          : _curatedSurfaceHighest.withValues(alpha: 0.86),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 26, color: _curatedPrimary),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? _curatedPrimary : Colors.transparent,
                      border: selected
                          ? null
                          : Border.all(color: _curatedGhostBorder),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            size: 14,
                            color: _curatedSurfaceHighest,
                          )
                        : null,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.notoSerif(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                  color: _curatedText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  height: 1.65,
                  color: _curatedTextSoft,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1016),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          border: Border.all(
            color: selected ? AppColors.limeGreen : AppColors.border,
            width: selected ? 2.2 : 1.1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.limeGreen.withValues(alpha: 0.22),
                    blurRadius: 26,
                    spreadRadius: 2,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F3210),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: AppColors.limeGreen, size: 30),
                ),
                const Spacer(),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.55,
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.limeGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppColors.black,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class OnboardingSelectablePanel extends StatelessWidget {
  const OnboardingSelectablePanel({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.helper,
    this.compact = false,
    this.visualStyle = OnboardingVisualStyle.legacyDark,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? helper;
  final bool compact;
  final OnboardingVisualStyle visualStyle;

  bool get _isCurated => visualStyle == OnboardingVisualStyle.curatedSanctuary;

  @override
  Widget build(BuildContext context) {
    if (_isCurated) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 22,
            vertical: compact ? 16 : 18,
          ),
          decoration: BoxDecoration(
            color: selected ? _curatedSurfaceHighest : _curatedSurfaceLow,
            borderRadius: BorderRadius.circular(28),
            border: selected
                ? Border.all(color: _curatedPrimary.withValues(alpha: 0.72))
                : null,
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: _curatedShadow,
                blurRadius: 32,
                spreadRadius: -6,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.notoSerif(
                        fontSize: compact ? 18 : 20,
                        fontWeight: FontWeight.w500,
                        color: _curatedText,
                        height: 1.12,
                      ),
                    ),
                    if ((helper?.isNotEmpty ?? false) && !compact) ...[
                      const SizedBox(height: 10),
                      Text(
                        helper!,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          height: 1.65,
                          color: _curatedTextSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? _curatedPrimary : Colors.transparent,
                  border: selected
                      ? null
                      : Border.all(color: _curatedGhostBorder),
                ),
                child: selected
                    ? const Icon(
                        Icons.check,
                        color: _curatedSurfaceHighest,
                        size: 14,
                      )
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: compact ? 16 : 18,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceRaised : const Color(0xFF0B1016),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: compact ? 15 : 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if ((helper?.isNotEmpty ?? false) && !compact) ...[
                    const SizedBox(height: 8),
                    Text(
                      helper!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? AppColors.orange : AppColors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.orange : AppColors.borderLight,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: AppColors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingTextField extends StatelessWidget {
  const OnboardingTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.suffix,
    this.maxLines = 1,
    this.keyboardType,
    this.visualStyle = OnboardingVisualStyle.legacyDark,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? suffix;
  final int maxLines;
  final TextInputType? keyboardType;
  final OnboardingVisualStyle visualStyle;

  bool get _isCurated => visualStyle == OnboardingVisualStyle.curatedSanctuary;

  @override
  Widget build(BuildContext context) {
    if (_isCurated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _curatedTextSoft,
              letterSpacing: 0.35,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            cursorColor: _curatedPrimary,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: _curatedText,
              height: 1.35,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.manrope(
                color: _curatedTextSoft.withValues(alpha: 0.72),
                fontSize: 15,
              ),
              filled: true,
              fillColor: _curatedSurfaceLow,
              suffixText: suffix,
              suffixStyle: GoogleFonts.manrope(
                color: _curatedTextSoft,
                fontWeight: FontWeight.w700,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 22,
                vertical: maxLines > 1 ? 20 : 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.fieldFill,
            suffixText: suffix,
            suffixStyle: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingPrimaryActionButton extends StatelessWidget {
  const OnboardingPrimaryActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.visualStyle = OnboardingVisualStyle.legacyDark,
  });

  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final OnboardingVisualStyle visualStyle;

  bool get _isCurated => visualStyle == OnboardingVisualStyle.curatedSanctuary;

  @override
  Widget build(BuildContext context) {
    if (_isCurated) {
      return SizedBox(
        width: double.infinity,
        height: 62,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[_curatedPrimary, _curatedSecondary],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: _curatedShadow,
                blurRadius: 40,
                spreadRadius: -5,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _curatedSurfaceHighest,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: _curatedSurfaceHighest,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: _curatedSurfaceHighest,
                        size: 22,
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 74,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFF97A18), Color(0xFFF13A1C)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.34),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.transparent,
            disabledBackgroundColor: AppColors.transparent,
            shadowColor: AppColors.transparent,
            surfaceTintColor: AppColors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: AppColors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
