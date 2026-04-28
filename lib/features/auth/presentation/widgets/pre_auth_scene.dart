import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/ai_branding.dart';

enum PreAuthOverlayStyle { unified, shopMask, workouts, empire }

enum PreAuthCtaType { next, google, none }

enum PreAuthFooterStyle { text, pill, none }

enum PreAuthContentAlignment { bottomStart, centerStart }

class PreAuthHeadlineSpan {
  const PreAuthHeadlineSpan(
    this.text, {
    this.color,
    this.italic = false,
    this.weight = FontWeight.w700,
  });

  final String text;
  final Color? color;
  final bool italic;
  final FontWeight weight;
}

class PreAuthHeadlineLine {
  const PreAuthHeadlineLine(this.spans);

  final List<PreAuthHeadlineSpan> spans;
}

class PreAuthFooter {
  const PreAuthFooter({required this.label, required this.style});

  final String label;
  final PreAuthFooterStyle style;
}

class PreAuthSlideSpec {
  const PreAuthSlideSpec({
    required this.backgroundAsset,
    required this.overlayStyle,
    required this.headlineLines,
    required this.bodyCopy,
    required this.ctaType,
    required this.footer,
    required this.systemUiOverlayStyle,
    this.supportingCopy,
    this.eyebrow,
    this.showSkip = false,
    this.showBrandWordmark = false,
    this.showAccentLine = false,
    this.contentAlignment = PreAuthContentAlignment.bottomStart,
    this.headlineBaseColor = Colors.white,
    this.bodyColor = Colors.white,
    this.supportingColor = const Color(0xFFE8E1DA),
    this.ctaLabel,
  });

  final String backgroundAsset;
  final PreAuthOverlayStyle overlayStyle;
  final List<PreAuthHeadlineLine> headlineLines;
  final String bodyCopy;
  final String? supportingCopy;
  final String? eyebrow;
  final PreAuthCtaType ctaType;
  final String? ctaLabel;
  final PreAuthFooter footer;
  final bool showSkip;
  final bool showBrandWordmark;
  final bool showAccentLine;
  final PreAuthContentAlignment contentAlignment;
  final Color headlineBaseColor;
  final Color bodyColor;
  final Color supportingColor;
  final SystemUiOverlayStyle systemUiOverlayStyle;

  PreAuthSlideSpec copyWith({
    String? backgroundAsset,
    PreAuthOverlayStyle? overlayStyle,
    List<PreAuthHeadlineLine>? headlineLines,
    String? bodyCopy,
    String? supportingCopy,
    bool clearSupportingCopy = false,
    String? eyebrow,
    bool clearEyebrow = false,
    PreAuthCtaType? ctaType,
    String? ctaLabel,
    bool clearCtaLabel = false,
    PreAuthFooter? footer,
    bool? showSkip,
    bool? showBrandWordmark,
    bool? showAccentLine,
    PreAuthContentAlignment? contentAlignment,
    Color? headlineBaseColor,
    Color? bodyColor,
    Color? supportingColor,
    SystemUiOverlayStyle? systemUiOverlayStyle,
  }) {
    return PreAuthSlideSpec(
      backgroundAsset: backgroundAsset ?? this.backgroundAsset,
      overlayStyle: overlayStyle ?? this.overlayStyle,
      headlineLines: headlineLines ?? this.headlineLines,
      bodyCopy: bodyCopy ?? this.bodyCopy,
      supportingCopy: clearSupportingCopy
          ? null
          : supportingCopy ?? this.supportingCopy,
      eyebrow: clearEyebrow ? null : eyebrow ?? this.eyebrow,
      ctaType: ctaType ?? this.ctaType,
      ctaLabel: clearCtaLabel ? null : ctaLabel ?? this.ctaLabel,
      footer: footer ?? this.footer,
      showSkip: showSkip ?? this.showSkip,
      showBrandWordmark: showBrandWordmark ?? this.showBrandWordmark,
      showAccentLine: showAccentLine ?? this.showAccentLine,
      contentAlignment: contentAlignment ?? this.contentAlignment,
      headlineBaseColor: headlineBaseColor ?? this.headlineBaseColor,
      bodyColor: bodyColor ?? this.bodyColor,
      supportingColor: supportingColor ?? this.supportingColor,
      systemUiOverlayStyle: systemUiOverlayStyle ?? this.systemUiOverlayStyle,
    );
  }
}

const PreAuthSlideSpec preAuthUnifiedSpec = PreAuthSlideSpec(
  backgroundAsset: 'backgrounds/Onboarding - Your Fitness Unified.png',
  overlayStyle: PreAuthOverlayStyle.unified,
  headlineLines: <PreAuthHeadlineLine>[
    PreAuthHeadlineLine(<PreAuthHeadlineSpan>[PreAuthHeadlineSpan('Your')]),
    PreAuthHeadlineLine(<PreAuthHeadlineSpan>[PreAuthHeadlineSpan('Fitness,')]),
    PreAuthHeadlineLine(<PreAuthHeadlineSpan>[
      PreAuthHeadlineSpan('Unified.', color: Color(0xFF8B2F07), italic: true),
    ]),
  ],
  bodyCopy:
      'The all-in-one ecosystem for members, coaches, and sellers powered by TAIYO.',
  eyebrow: 'WELCOME',
  ctaType: PreAuthCtaType.next,
  ctaLabel: 'NEXT',
  footer: PreAuthFooter(
    label: AiBranding.poweredByLabel,
    style: PreAuthFooterStyle.pill,
  ),
  showSkip: true,
  showBrandWordmark: true,
  showAccentLine: true,
  headlineBaseColor: Color(0xFF1D1A17),
  bodyColor: Color(0xFF5C5148),
  supportingColor: Color(0xFF756A62),
  systemUiOverlayStyle: SystemUiOverlayStyle.dark,
);

const PreAuthSlideSpec preAuthShopSpec = PreAuthSlideSpec(
  backgroundAsset: 'backgrounds/Onboarding - Shop & Train (v2).png',
  overlayStyle: PreAuthOverlayStyle.shopMask,
  headlineLines: <PreAuthHeadlineLine>[
    PreAuthHeadlineLine(<PreAuthHeadlineSpan>[PreAuthHeadlineSpan('Shop &')]),
    PreAuthHeadlineLine(<PreAuthHeadlineSpan>[PreAuthHeadlineSpan('Train')]),
    PreAuthHeadlineLine(<PreAuthHeadlineSpan>[
      PreAuthHeadlineSpan('Together.', color: Color(0xFFF0A38B), italic: true),
    ]),
  ],
  bodyCopy:
      'Browse fitness products, find coaches, and track your progress in one place. A community built on mutual growth.',
  ctaType: PreAuthCtaType.next,
  ctaLabel: 'NEXT',
  footer: PreAuthFooter(
    label: AiBranding.poweredByLabel,
    style: PreAuthFooterStyle.text,
  ),
  showSkip: true,
  headlineBaseColor: Colors.white,
  bodyColor: Color(0xFFF2E8E0),
  supportingColor: Color(0xFFD7C9BE),
  systemUiOverlayStyle: SystemUiOverlayStyle.light,
);

const PreAuthSlideSpec preAuthWorkoutsSpec = PreAuthSlideSpec(
  backgroundAsset: 'backgrounds/High-tech gym setup.png',
  overlayStyle: PreAuthOverlayStyle.workouts,
  headlineLines: <PreAuthHeadlineLine>[
    PreAuthHeadlineLine(<PreAuthHeadlineSpan>[
      PreAuthHeadlineSpan('AI-Powered'),
    ]),
    PreAuthHeadlineLine(<PreAuthHeadlineSpan>[
      PreAuthHeadlineSpan('Workouts.'),
    ]),
  ],
  bodyCopy:
      'Get personalized workout plans generated by our smart AI engine. Designed to adapt to your body\'s rhythm and elevate your sanctuary.',
  ctaType: PreAuthCtaType.next,
  ctaLabel: 'NEXT',
  footer: PreAuthFooter(
    label: AiBranding.poweredByLabel,
    style: PreAuthFooterStyle.text,
  ),
  showSkip: true,
  headlineBaseColor: Colors.white,
  bodyColor: Color(0xFFEDE9E3),
  supportingColor: Color(0xFFD3CEC7),
  systemUiOverlayStyle: SystemUiOverlayStyle.light,
);

const PreAuthSlideSpec preAuthEmpireSpec = PreAuthSlideSpec(
  backgroundAsset: 'backgrounds/Fitness landscape.png',
  overlayStyle: PreAuthOverlayStyle.empire,
  headlineLines: <PreAuthHeadlineLine>[
    PreAuthHeadlineLine(<PreAuthHeadlineSpan>[
      PreAuthHeadlineSpan('Build Your'),
    ]),
    PreAuthHeadlineLine(<PreAuthHeadlineSpan>[PreAuthHeadlineSpan('Fitness')]),
    PreAuthHeadlineLine(<PreAuthHeadlineSpan>[PreAuthHeadlineSpan('Empire.')]),
  ],
  bodyCopy:
      'Sell products, coach others, and grow your fitness brand with ease. The tools that move with you.',
  ctaType: PreAuthCtaType.google,
  footer: PreAuthFooter(
    label: AiBranding.poweredByLabel,
    style: PreAuthFooterStyle.text,
  ),
  showAccentLine: true,
  headlineBaseColor: Colors.white,
  bodyColor: Color(0xFFECE7E0),
  supportingColor: Color(0xFFD5CCC4),
  systemUiOverlayStyle: SystemUiOverlayStyle.light,
);

class PreAuthScaffold extends StatelessWidget {
  const PreAuthScaffold({
    super.key,
    required this.backgroundAsset,
    required this.overlayStyle,
    required this.systemUiOverlayStyle,
    required this.child,
  });

  final String backgroundAsset;
  final PreAuthOverlayStyle overlayStyle;
  final SystemUiOverlayStyle systemUiOverlayStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(backgroundAsset, fit: BoxFit.cover),
            Positioned.fill(child: _PreAuthOverlay(style: overlayStyle)),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

class PreAuthScene extends StatelessWidget {
  const PreAuthScene({
    super.key,
    required this.spec,
    this.onPrimaryAction,
    this.onSkip,
    this.isBusy = false,
    this.statusText,
    this.headerLeading,
    this.headerCenter,
    this.headerTrailing,
    this.bottomOverride,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final PreAuthSlideSpec spec;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSkip;
  final bool isBusy;
  final String? statusText;
  final Widget? headerLeading;
  final Widget? headerCenter;
  final Widget? headerTrailing;
  final Widget? bottomOverride;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return PreAuthScaffold(
      backgroundAsset: spec.backgroundAsset,
      overlayStyle: spec.overlayStyle,
      systemUiOverlayStyle: spec.systemUiOverlayStyle,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PreAuthHeader(
                showBrandWordmark: spec.showBrandWordmark,
                showSkip: spec.showSkip,
                onSkip: onSkip,
                leading: headerLeading,
                center: headerCenter,
                trailing: headerTrailing,
              ),
              if (spec.contentAlignment == PreAuthContentAlignment.centerStart)
                const Spacer(),
              if (spec.contentAlignment == PreAuthContentAlignment.bottomStart)
                const Spacer(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (spec.eyebrow != null) ...<Widget>[
                      _PreAuthEyebrow(
                        label: spec.eyebrow!,
                        showAccentLine: spec.showAccentLine,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (spec.showAccentLine &&
                        spec.eyebrow == null) ...<Widget>[
                      const _AccentRule(),
                      const SizedBox(height: 18),
                    ],
                    _HeadlineBlock(
                      lines: spec.headlineLines,
                      baseColor: spec.headlineBaseColor,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      spec.bodyCopy,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        height: 1.58,
                        fontWeight: FontWeight.w500,
                        color: spec.bodyColor,
                      ),
                    ),
                    if (spec.supportingCopy != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        spec.supportingCopy!,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                          color: spec.supportingColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    if (bottomOverride != null)
                      bottomOverride!
                    else
                      _CtaArea(
                        spec: spec,
                        onPrimaryAction: onPrimaryAction,
                        isBusy: isBusy,
                      ),
                    if (statusText != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        statusText!,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: spec.supportingColor,
                        ),
                      ),
                    ],
                    if (secondaryActionLabel != null &&
                        onSecondaryAction != null) ...<Widget>[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: onSecondaryAction,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: const Color(0xFFF3EAE2),
                        ),
                        child: Text(
                          secondaryActionLabel!,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFFF3EAE2),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _FooterBadge(footer: spec.footer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PreAuthGoogleButton extends StatelessWidget {
  const PreAuthGoogleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isBusy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: const Color(0xFFF3EFE8).withValues(alpha: 0.94),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0x26FFFFFF)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFF4C8BF5),
                              ),
                            )
                          : const SizedBox(
                              width: 22,
                              height: 22,
                              child: CustomPaint(painter: _GoogleMarkPainter()),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2B2A28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 52),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreAuthHeader extends StatelessWidget {
  const _PreAuthHeader({
    required this.showBrandWordmark,
    required this.showSkip,
    required this.onSkip,
    this.leading,
    this.center,
    this.trailing,
  });

  final bool showBrandWordmark;
  final bool showSkip;
  final VoidCallback? onSkip;
  final Widget? leading;
  final Widget? center;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: <Widget>[
          if (leading != null)
            leading!
          else if (showBrandWordmark)
            Text(
              'GymUnity',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF7C2805),
              ),
            )
          else
            const SizedBox(width: 42),
          if (center != null) ...<Widget>[const Spacer(), center!],
          const Spacer(),
          if (trailing != null)
            trailing!
          else if (showSkip)
            TextButton(
              key: const ValueKey<String>('preauth_skip_button'),
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8F7263),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                'Skip',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(width: 42),
        ],
      ),
    );
  }
}

class _PreAuthEyebrow extends StatelessWidget {
  const _PreAuthEyebrow({required this.label, required this.showAccentLine});

  final String label;
  final bool showAccentLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (showAccentLine) ...<Widget>[
          const SizedBox(
            width: 64,
            child: Divider(thickness: 1, height: 1, color: Color(0xFF9E5B43)),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
              color: const Color(0xFF875A49),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeadlineBlock extends StatelessWidget {
  const _HeadlineBlock({required this.lines, required this.baseColor});

  final List<PreAuthHeadlineLine> lines;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map(
            (PreAuthHeadlineLine line) => Text.rich(
              TextSpan(
                children: line.spans
                    .map(
                      (PreAuthHeadlineSpan span) => TextSpan(
                        text: span.text,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 34,
                          height: 0.92,
                          fontWeight: span.weight,
                          fontStyle: span.italic
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: span.color ?? baseColor,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CtaArea extends StatelessWidget {
  const _CtaArea({
    required this.spec,
    required this.onPrimaryAction,
    required this.isBusy,
  });

  final PreAuthSlideSpec spec;
  final VoidCallback? onPrimaryAction;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    switch (spec.ctaType) {
      case PreAuthCtaType.next:
        return _PrimaryNextButton(
          label: spec.ctaLabel ?? 'NEXT',
          onPressed: onPrimaryAction,
        );
      case PreAuthCtaType.google:
        return PreAuthGoogleButton(
          label: spec.ctaLabel ?? 'Continue with Google',
          onPressed: onPrimaryAction,
          isBusy: isBusy,
        );
      case PreAuthCtaType.none:
        return const SizedBox.shrink();
    }
  }
}

class _PrimaryNextButton extends StatelessWidget {
  const _PrimaryNextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF8A2D04),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        key: const ValueKey<String>('preauth_next_button'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterBadge extends StatelessWidget {
  const _FooterBadge({required this.footer});

  final PreAuthFooter footer;

  @override
  Widget build(BuildContext context) {
    switch (footer.style) {
      case PreAuthFooterStyle.pill:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              footer.label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF6C5548),
                letterSpacing: 1.8,
              ),
            ),
          ),
        );
      case PreAuthFooterStyle.text:
        return Text(
          footer.label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.68),
            letterSpacing: 1.8,
          ),
        );
      case PreAuthFooterStyle.none:
        return const SizedBox.shrink();
    }
  }
}

class _AccentRule extends StatelessWidget {
  const _AccentRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 92,
      decoration: BoxDecoration(
        color: const Color(0xFFFF8C5B),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _PreAuthOverlay extends StatelessWidget {
  const _PreAuthOverlay({required this.style});

  final PreAuthOverlayStyle style;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case PreAuthOverlayStyle.unified:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.white.withValues(alpha: 0.08),
                const Color(0x30FFFFFF),
                const Color(0xD6F3EEE7),
                const Color(0xEEF7F3EE),
              ],
              stops: const <double>[0.0, 0.34, 0.72, 1.0],
            ),
          ),
        );
      case PreAuthOverlayStyle.shopMask:
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.14),
                    Colors.black.withValues(alpha: 0.26),
                    Colors.black.withValues(alpha: 0.68),
                    const Color(0xF2171412),
                  ],
                  stops: const <double>[0.0, 0.34, 0.64, 1.0],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.0),
                      Colors.black.withValues(alpha: 0.74),
                      const Color(0xFF16110F),
                    ],
                    stops: const <double>[0.0, 0.44, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      case PreAuthOverlayStyle.workouts:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.20),
                Colors.black.withValues(alpha: 0.36),
                Colors.black.withValues(alpha: 0.62),
                const Color(0xE9111111),
              ],
              stops: const <double>[0.0, 0.26, 0.6, 1.0],
            ),
          ),
        );
      case PreAuthOverlayStyle.empire:
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.24),
                Colors.black.withValues(alpha: 0.52),
                const Color(0xD6181513),
              ],
              stops: const <double>[0.0, 0.38, 0.68, 1.0],
            ),
          ),
        );
    }
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.18;
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    Paint paintFor(Color color) {
      return Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
    }

    canvas.drawArc(rect, -0.20, 1.10, false, paintFor(const Color(0xFF4285F4)));
    canvas.drawArc(rect, 0.92, 1.08, false, paintFor(const Color(0xFFDB4437)));
    canvas.drawArc(rect, 2.02, 0.96, false, paintFor(const Color(0xFFF4B400)));
    canvas.drawArc(rect, 2.98, 1.42, false, paintFor(const Color(0xFF0F9D58)));

    final barPaint = paintFor(const Color(0xFF4285F4));
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.50),
      Offset(size.width * 0.89, size.height * 0.50),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
