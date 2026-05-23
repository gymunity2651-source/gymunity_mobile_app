import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/atelier_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TaiyoReadinessGauge — Animated arc gauge for readiness score
// ─────────────────────────────────────────────────────────────────────────────

class TaiyoReadinessGauge extends StatefulWidget {
  const TaiyoReadinessGauge({
    super.key,
    required this.score,
    this.size = 120,
    this.strokeWidth = 10,
    this.label,
  });

  final int score;
  final double size;
  final double strokeWidth;
  final String? label;

  @override
  State<TaiyoReadinessGauge> createState() => _TaiyoReadinessGaugeState();
}

class _TaiyoReadinessGaugeState extends State<TaiyoReadinessGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(TaiyoReadinessGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedScore = widget.score.clamp(0, 100);
    final color = _gaugeColor(normalizedScore);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size * 0.65,
          child: CustomPaint(
            painter: _ReadinessArcPainter(
              progress: (_animation.value * normalizedScore) / 100,
              strokeWidth: widget.strokeWidth,
              activeColor: color,
              trackColor: Colors.white.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(normalizedScore * _animation.value).round()}',
                      style: GoogleFonts.manrope(
                        fontSize: widget.size * 0.24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    if (widget.label != null)
                      Text(
                        widget.label!,
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _gaugeColor(int score) {
    if (score >= 80) return const Color(0xFF4ADE80);
    if (score >= 60) return const Color(0xFF86EFAC);
    if (score >= 40) return const Color(0xFFFBBF24);
    if (score >= 20) return const Color(0xFFFB923C);
    return const Color(0xFFEF4444);
  }
}

class _ReadinessArcPainter extends CustomPainter {
  _ReadinessArcPainter({
    required this.progress,
    required this.strokeWidth,
    required this.activeColor,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color activeColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height) - strokeWidth / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      trackPaint,
    );

    if (progress > 0) {
      final activePaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.bottomCenter,
          startAngle: math.pi,
          endAngle: 2 * math.pi,
          colors: [
            activeColor.withValues(alpha: 0.6),
            activeColor,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ReadinessArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaiyoPulsingDot — Animated pulsing status indicator
// ─────────────────────────────────────────────────────────────────────────────

class TaiyoPulsingDot extends StatefulWidget {
  const TaiyoPulsingDot({
    super.key,
    this.color = const Color(0xFF4ADE80),
    this.size = 8,
  });

  final Color color;
  final double size;

  @override
  State<TaiyoPulsingDot> createState() => _TaiyoPulsingDotState();
}

class _TaiyoPulsingDotState extends State<TaiyoPulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.4);
        final opacity = 1.0 - (_controller.value * 0.4);
        return SizedBox(
          width: widget.size * 2.5,
          height: widget.size * 2.5,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size * 1.8,
                    height: widget.size * 1.8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withValues(alpha: 0.2 * opacity),
                    ),
                  ),
                ),
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaiyoAiShimmerText — Shimmer effect text for AI labels
// ─────────────────────────────────────────────────────────────────────────────

class TaiyoAiShimmerText extends StatefulWidget {
  const TaiyoAiShimmerText({
    super.key,
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  State<TaiyoAiShimmerText> createState() => _TaiyoAiShimmerTextState();
}

class _TaiyoAiShimmerTextState extends State<TaiyoAiShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ??
        GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
        );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + 3.0 * _controller.value, 0),
              end: Alignment(0.0 + 3.0 * _controller.value, 0),
              colors: const [
                Color(0xAAFFFFFF),
                Color(0xFFFFFFFF),
                Color(0xAAFFFFFF),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(widget.text, style: baseStyle),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaiyoSignalChips — Row of glowing AI signal chips
// ─────────────────────────────────────────────────────────────────────────────

class TaiyoSignalChips extends StatelessWidget {
  const TaiyoSignalChips({
    super.key,
    required this.signals,
    this.maxVisible = 4,
  });

  final List<String> signals;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: signals
          .take(maxVisible)
          .map(
            (signal) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4ADE80),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    signal,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFBBF7D0),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaiyoAdherenceRing — Animated circular progress for adherence
// ─────────────────────────────────────────────────────────────────────────────

class TaiyoAdherenceRing extends StatefulWidget {
  const TaiyoAdherenceRing({
    super.key,
    required this.percentage,
    this.size = 80,
    this.strokeWidth = 6,
  });

  final int percentage;
  final double size;
  final double strokeWidth;

  @override
  State<TaiyoAdherenceRing> createState() => _TaiyoAdherenceRingState();
}

class _TaiyoAdherenceRingState extends State<TaiyoAdherenceRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clamped = widget.percentage.clamp(0, 100);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _RingPainter(
              progress: (_animation.value * clamped) / 100,
              strokeWidth: widget.strokeWidth,
              color: AtelierColors.primary,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(clamped * _animation.value).round()}%',
                    style: GoogleFonts.manrope(
                      fontSize: widget.size * 0.22,
                      fontWeight: FontWeight.w900,
                      color: AtelierColors.primary,
                      height: 1,
                    ),
                  ),
                  Text(
                    'adherence',
                    style: GoogleFonts.manrope(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AtelierColors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
  });

  final double progress;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final activePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaiyoAgentBadge — "Safety Reviewed ✓" badge
// ─────────────────────────────────────────────────────────────────────────────

class TaiyoAgentBadge extends StatelessWidget {
  const TaiyoAgentBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? const Color(0xFF4ADE80);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: badgeColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: badgeColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaiyoAgentCapabilityCard — Card showing an AI agent capability
// ─────────────────────────────────────────────────────────────────────────────

class TaiyoAgentCapabilityCard extends StatelessWidget {
  const TaiyoAgentCapabilityCard({
    super.key,
    required this.agentName,
    required this.description,
    required this.icon,
    this.accentColor,
  });

  final String agentName;
  final String description;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AtelierColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agentName,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AtelierColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    height: 1.4,
                    color: AtelierColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TaiyoPulsingDot(color: accent, size: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TaiyoThinkingDots — Animated bouncing dots for AI thinking state
// ─────────────────────────────────────────────────────────────────────────────

class TaiyoThinkingDots extends StatefulWidget {
  const TaiyoThinkingDots({
    super.key,
    this.color = AtelierColors.primary,
    this.size = 6,
  });

  final Color color;
  final double size;

  @override
  State<TaiyoThinkingDots> createState() => _TaiyoThinkingDotsState();
}

class _TaiyoThinkingDotsState extends State<TaiyoThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final bounce = math.sin(value * math.pi);
            return Padding(
              padding: EdgeInsets.only(right: index < 2 ? 4 : 0),
              child: Transform.translate(
                offset: Offset(0, -bounce * 4),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.5 + bounce * 0.5),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
