import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/app_reveal.dart';
import '../../../ai_coach/domain/entities/ai_coach_entities.dart';
import '../../../ai_coach/presentation/providers/ai_coach_providers.dart';
import '../../../ai_coach/presentation/screens/ai_coach_home_screen.dart';
import '../../../coaches/presentation/screens/coaches_screen.dart';
import '../../../news/presentation/screens/news_feed_screen.dart';
import '../../../planner/presentation/route_args.dart';
import '../../../store/presentation/screens/store_home_screen.dart';
import '../../domain/entities/member_home_summary_entity.dart';
import '../providers/member_providers.dart';
import '../widgets/member_profile_shortcut_button.dart';
import 'member_checkins_screen.dart';
import 'member_coach_hub_screen.dart';
import 'member_messages_screen.dart';
import 'progress_screen.dart';

/// The editorial "Ethereal Atelier" member home page.
///
/// Every section matches the luxury-magazine layout from the design system
/// document. Depth is achieved via tonal layering (no borders, no shadows),
/// typography uses Noto Serif for headlines and Manrope for supporting copy.
class MemberHomeContent extends ConsumerWidget {
  const MemberHomeContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final coachBriefAsync = ref.watch(aiCoachDailyBriefProvider(today));
    final profileAsync = ref.watch(currentUserProfileProvider);
    final summaryAsync = ref.watch(memberHomeSummaryProvider);

    const baseDelay = 40;
    Duration revealDelay(int index) =>
        Duration(milliseconds: baseDelay + (index * 55));

    return SafeArea(
      child: RefreshIndicator.adaptive(
        color: AtelierColors.primary,
        onRefresh: () async {
          ref.invalidate(currentUserProfileProvider);
          ref.invalidate(memberHomeSummaryProvider);
          ref.invalidate(memberSubscriptionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
          children: [
            // ── Top bar: Atelier brand + actions ──
            AppReveal(
              delay: revealDelay(0),
              child: _TopBar(profileAsync: profileAsync),
            ),
            const SizedBox(height: 28),

            // ── Hero card (greeting + streak pill) ──
            AppReveal(
              delay: revealDelay(1),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: AtelierColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    // Greeting
                    AnimatedSwitcher(
                      duration: AppMotion.medium,
                      switchInCurve: AppMotion.emphasizedCurve,
                      switchOutCurve: AppMotion.exitCurve,
                      transitionBuilder: _fadeSlide,
                      child: profileAsync.when(
                        loading: () => const KeyedSubtree(
                          key: ValueKey('hero-loading'),
                          child: SizedBox(height: 140),
                        ),
                        error: (_, _) =>
                            const SizedBox.shrink(key: ValueKey('hero-error')),
                        data: (profile) => KeyedSubtree(
                          key: ValueKey(
                            'hero-${profile?.fullName ?? 'member'}',
                          ),
                          child: _HeroGreeting(
                            name: profile?.fullName?.trim().isNotEmpty == true
                                ? profile!.fullName!.trim()
                                : 'GymUnity Member',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Streak pill
                    _StreakPill(summaryAsync: summaryAsync),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── "What Matters Now" section ──
            AppReveal(
              delay: revealDelay(3),
              child: _SectionHeading(
                title: 'What Matters Now',
                subtitle: 'Your immediate status and pending tasks',
              ),
            ),
            const SizedBox(height: 16),

            // ── Metric cards + next-step CTA ──
            AppReveal(
              delay: revealDelay(4),
              child: _DynamicMetricsBlock(
                key: ValueKey(
                  'metrics-${summaryAsync.valueOrNull?.activeCoachCount ?? 'pending'}-${summaryAsync.valueOrNull?.activeAiPlan?.id ?? 'none'}',
                ),
                summaryAsync: summaryAsync,
              ),
            ),
            const SizedBox(height: 36),

            // ── "Quick Actions" section ──
            AppReveal(
              delay: revealDelay(5),
              child: _SectionHeading(title: 'Quick Actions', subtitle: ''),
            ),
            const SizedBox(height: 16),

            // ── Featured TAIYO card ──
            AppReveal(
              delay: revealDelay(6),
              child: _AiCoachFeaturedCard(briefAsync: coachBriefAsync),
            ),
            const SizedBox(height: 14),

            // ── Quick-action grid (2 columns) ──
            AppReveal(delay: revealDelay(7), child: const _QuickActionsGrid()),
            const SizedBox(height: 24),

            // ── Browse store row ──
            AppReveal(delay: revealDelay(8), child: const _BrowseStoreCard()),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TOP BAR
// ═══════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({required this.profileAsync});

  final AsyncValue profileAsync;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Brand mark — circular green avatar
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF5C8A6E),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.spa_rounded,
            color: AtelierColors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            AppStrings.appName,
            style: GoogleFonts.notoSerif(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: AtelierColors.onSurface,
            ),
          ),
        ),
        // Notification bell
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLowest,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AtelierColors.onSurfaceVariant,
            size: 21,
          ),
        ),
        const SizedBox(width: 8),
        // Profile avatar
        MemberProfileShortcutButton(
          backgroundColor: AtelierColors.surfaceContainerLowest,
          iconColor: AtelierColors.onSurfaceVariant,
          borderColor: AtelierColors.transparent,
          size: 40,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HERO GREETING
// ═══════════════════════════════════════════════════════════════════════════

class _HeroGreeting extends StatelessWidget {
  const _HeroGreeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'WELLNESS COLLECTIVE',
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
            color: AtelierColors.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Welcome back,',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerif(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 1.2,
            color: AtelierColors.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerif(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            height: 1.15,
            color: AtelierColors.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Your journey toward optimal vitality is curated here. Today is a perfect day for progress.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.55,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  STREAK PILL
// ═══════════════════════════════════════════════════════════════════════════

class _StreakPill extends StatefulWidget {
  const _StreakPill({required this.summaryAsync});

  final AsyncValue<MemberHomeSummaryEntity> summaryAsync;

  @override
  State<_StreakPill> createState() => _StreakPillState();
}

class _StreakPillState extends State<_StreakPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // "Reverse" enables the seamless yoyo effect (eats toward middle, un-eats back to start)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildTextColumn(String headline, {bool includeValueKey = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'DAILY STREAK',
          style: GoogleFonts.manrope(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: AtelierColors.onSurfaceVariant,
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 2),
        Text(
          headline,
          key: includeValueKey ? const Key('member-daily-streak-value') : null,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AtelierColors.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final headline = _resolveDailyStreakHeadline(widget.summaryAsync);

    return Center(
      child: Container(
        key: const Key('member-daily-streak-card'),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AtelierColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Smooth natural pacing curve
            final progress = Curves.easeInOut.transform(_controller.value);

            return Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                // 1. Invisible Layout Guide (calculates the pill's static footprint)
                Opacity(
                  opacity: 0.0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 36,
                      ), // The exact footprint of the icon
                      const SizedBox(width: 12),
                      _buildTextColumn(headline),
                    ],
                  ),
                ),

                // 2. The Text (Appears to get swallowed into the icon)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double W = constraints.maxWidth;
                      return ClipRect(
                        clipper: _SmoothEatingClipper(progress),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Transform.translate(
                            // Text moves exactly W/2 to the left.
                            // Icon moves to exactly W/2 from the left.
                            // They converge in the absolute center pixel-perfectly with 0 gap!
                            offset: Offset(-progress * (W / 2), 0.0),
                            child: _buildTextColumn(
                              headline,
                              includeValueKey: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 3. The sliding Icon (Ends exactly at the center of the pill)
                Positioned.fill(
                  child: Align(
                    // -1.0 is Left Edge. 0.0 is Exact Center.
                    alignment: Alignment(-1.0 + progress, 0.0),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/streak_icon.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF4DCC5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: AtelierColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SmoothEatingClipper extends CustomClipper<Rect> {
  _SmoothEatingClipper(this.progress);
  final double progress;

  @override
  Rect getClip(Size size) {
    // Determine the exact pixel coordinate of the Icon's dynamic center
    // Icon aligns from -1.0 (left) to 0.0 (center)
    final centerOfIconX = ((size.width - 36) / 2) * progress + 18;

    // Anything to the left of the Icon's center is mathematically clipped (invisible)
    // Making it seamlessly disappear as the texts dives in.
    return Rect.fromLTWH(
      centerOfIconX,
      0,
      size.width - centerOfIconX,
      size.height,
    );
  }

  @override
  bool shouldReclip(covariant _SmoothEatingClipper oldDelegate) =>
      oldDelegate.progress != progress;
}

String _resolveDailyStreakHeadline(
  AsyncValue<MemberHomeSummaryEntity> summaryAsync,
) {
  return summaryAsync.when(
    loading: () => 'Loading...',
    error: (_, _) => 'Unavailable',
    data: (summary) =>
        _formatDailyStreakHeadline(summary.dailyStreak.currentCount),
  );
}

String _formatDailyStreakHeadline(int count) {
  final safeCount = math.max(0, count);
  return safeCount == 1 ? '1 Day Active' : '$safeCount Days Active';
}

// ═══════════════════════════════════════════════════════════════════════════
//  SECTION HEADING
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.notoSerif(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AtelierColors.onSurface,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  METRICS BLOCK
// ═══════════════════════════════════════════════════════════════════════════

// ignore: unused_element
class _MetricsBlock extends StatelessWidget {
  const _MetricsBlock({
    required this.activeCoaches,
    required this.latestWeightKg,
    required this.hasPlan,
    required this.needsCheckout,
  });

  final int activeCoaches;
  final double? latestWeightKg;
  final bool hasPlan;
  final bool needsCheckout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricTile(
          imageAsset: 'assets/images/coaches_icon.png',
          label: 'ACTIVE COACHES',
          value: '$activeCoaches',
          trailingWidget: const _CoachesRadarGraph(),
        ),
        const SizedBox(height: 12),
        _MetricTile(
          icon: Icons.monitor_weight_outlined,
          label: 'LATEST WEIGHT',
          value: latestWeightKg == null
              ? '--'
              : '${latestWeightKg!.toStringAsFixed(1)} kg',
          trailingWidget: const _WeightSparkline(),
        ),
        const SizedBox(height: 12),
        _MetricTile(
          icon: Icons.event_note_outlined,
          label: 'CURRENT PLAN',
          value: hasPlan ? '• Live' : 'None',
          valueColor: hasPlan ? AtelierColors.success : null,
          trailingWidget: const _PlanProgressWeek(),
        ),
        const SizedBox(height: 14),

        _NextStepCard(needsCheckout: needsCheckout),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    this.icon,
    this.imageAsset,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailingWidget,
  }) : assert(icon != null || imageAsset != null);

  final IconData? icon;
  final String? imageAsset;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailingWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AtelierColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: imageAsset != null
                    ? Center(
                        child: Image.asset(
                          imageAsset!,
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.groups_2_rounded,
                                size: 18,
                                color: AtelierColors.primary,
                              ),
                        ),
                      )
                    : Icon(
                        icon,
                        size: 20,
                        color: AtelierColors.onSurfaceVariant,
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AtelierColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? AtelierColors.onSurface,
                ),
              ),
            ],
          ),
          // Custom trailing animation
          ?trailingWidget,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  1. COACHES RADAR GRAPH
// ═══════════════════════════════════════════════════════════════════════════

class _CoachesRadarGraph extends StatefulWidget {
  const _CoachesRadarGraph();

  @override
  State<_CoachesRadarGraph> createState() => _CoachesRadarGraphState();
}

class _CoachesRadarGraphState extends State<_CoachesRadarGraph>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _RadarPainter(
              progress: _controller.value,
              color: AtelierColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Expand ripple 1
    final p1 = (progress + 0.5) % 1.0;
    canvas.drawCircle(
      center,
      maxRadius * p1,
      Paint()
        ..color = color.withValues(alpha: (1 - p1) * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Expand ripple 2
    final p2 = progress;
    canvas.drawCircle(
      center,
      maxRadius * p2,
      Paint()
        ..color = color.withValues(alpha: (1 - p2) * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Core dot (you)
    canvas.drawCircle(center, 3, Paint()..color = color.withValues(alpha: 0.8));

    // Orbital dots (potential coaches)
    final coach1 = Offset(
      center.dx + math.cos(progress * math.pi * 2) * maxRadius * 0.5,
      center.dy + math.sin(progress * math.pi * 2) * maxRadius * 0.5,
    );
    final coach2 = Offset(
      center.dx + math.cos(progress * math.pi * 2 + math.pi) * maxRadius * 0.8,
      center.dy + math.sin(progress * math.pi * 2 + math.pi) * maxRadius * 0.8,
    );

    canvas.drawCircle(coach1, 2, Paint()..color = color.withValues(alpha: 0.6));
    canvas.drawCircle(
      coach2,
      2.5,
      Paint()..color = color.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
//  2. WEIGHT TREND SPARKLINE
// ═══════════════════════════════════════════════════════════════════════════

class _WeightSparkline extends StatefulWidget {
  const _WeightSparkline();

  @override
  State<_WeightSparkline> createState() => _WeightSparklineState();
}

class _WeightSparklineState extends State<_WeightSparkline>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Continuous loop for an organic floating effect
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 35,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _SparklinePainter(
              progress: _controller.value,
              color: AtelierColors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Fake downward trend for weight: mapped 0 to 1 (0 is top of chart, 1 is bottom)
    final baseValues = [0.2, 0.4, 0.3, 0.6, 0.5, 0.9];

    // Calculate undulating values using the progress as a phase
    double getValue(int index) {
      // Create a smooth floating offset for each point based on the continuous progress
      final shift = math.sin((progress * math.pi * 2) + (index * 1.5)) * 0.12;
      return math.max(0.0, math.min(1.0, baseValues[index] + shift));
    }

    final path = Path();
    final step = size.width / (baseValues.length - 1);

    path.moveTo(0, size.height * getValue(0));
    for (int i = 0; i < baseValues.length - 1; i++) {
      final x1 = step * i;
      final y1 = size.height * getValue(i);
      final x2 = step * (i + 1);
      final y2 = size.height * getValue(i + 1);

      // Smooth cubic bezier connection
      path.cubicTo(x1 + step / 2, y1, x1 + step / 2, y2, x2, y2);
    }

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Area gradient under the curve
    final areaPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, fillPaint);

    // Glowing tip at current data point
    final tipPos = Offset(
      size.width,
      size.height * getValue(baseValues.length - 1),
    );
    canvas.drawCircle(tipPos, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
//  3. PLAN PROGRESS WEEK
// ═══════════════════════════════════════════════════════════════════════════

class _PlanProgressWeek extends StatefulWidget {
  const _PlanProgressWeek();

  @override
  State<_PlanProgressWeek> createState() => _PlanProgressWeekState();
}

class _PlanProgressWeekState extends State<_PlanProgressWeek>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 30,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _WeekPainter(
              pulse: _controller.value,
              color: AtelierColors.success,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekPainter extends CustomPainter {
  _WeekPainter({required this.pulse, required this.color});

  final double pulse;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const int days = 7;
    const int currentDay = 4; // 0-indexed: 4th block is today
    const double radius = 3.0;

    final double spacing = (size.width - (radius * 2 * days)) / (days - 1);
    final double y = size.height / 2;

    for (int i = 0; i < days; i++) {
      final x = (radius * 2 * i) + (spacing * i) + radius;

      if (i < currentDay) {
        // Completed days: solid dot
        canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
      } else if (i == currentDay) {
        // Current day: pulsating glow + solid core
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.2 + (0.4 * pulse));
        canvas.drawCircle(
          Offset(x, y),
          radius + (1.5 + (2.5 * pulse)),
          glowPaint,
        );
        canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
      } else {
        // Upcoming days: hollow outline
        final outlinePaint = Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(Offset(x, y), radius, outlinePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeekPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

// ═══════════════════════════════════════════════════════════════════════════
//  NEXT-STEP CTA
// ═══════════════════════════════════════════════════════════════════════════

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.needsCheckout});

  final bool needsCheckout;

  @override
  Widget build(BuildContext context) {
    final label = needsCheckout ? 'Complete Checkout' : 'Submit Check-in';
    final cta = needsCheckout ? 'Checkout Now' : 'Open Check-in';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AtelierColors.darkCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT STEP',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: AtelierColors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AtelierColors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Mesh-gradient CTA button
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AtelierColors.primary, AtelierColors.primaryContainer],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Material(
              color: AtelierColors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(9999),
                onTap: () {
                  if (needsCheckout) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CoachesScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MemberCheckinsScreen(),
                      ),
                    );
                  }
                },
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cta,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AtelierColors.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AtelierColors.onPrimary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FEATURED TAIYO CARD
// ═══════════════════════════════════════════════════════════════════════════

class _DynamicMetricsBlock extends StatelessWidget {
  const _DynamicMetricsBlock({super.key, required this.summaryAsync});

  final AsyncValue<MemberHomeSummaryEntity> summaryAsync;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ActiveCoachesSummaryCard(summaryAsync: summaryAsync),
        const SizedBox(height: 12),
        _LatestWeightSummaryCard(summaryAsync: summaryAsync),
        const SizedBox(height: 12),
        _CurrentPlanSummaryCard(summaryAsync: summaryAsync),
        if (summary != null) ...[
          const SizedBox(height: 14),
          _DynamicNextStepCard(
            hasActiveCoach: summary.activeCoachCount > 0,
            hasPendingCoachCheckout: summary.hasPendingCoachCheckout,
          ),
        ],
      ],
    );
  }
}

class _DashboardMetricTile extends StatelessWidget {
  const _DashboardMetricTile({
    this.cardKey,
    this.valueKey,
    this.icon,
    this.imageAsset,
    required this.label,
    required this.headline,
    this.headlineColor,
    this.supportingText,
    this.compactHeadline = false,
    this.trailingWidget,
  }) : assert(icon != null || imageAsset != null);

  final Key? cardKey;
  final Key? valueKey;
  final IconData? icon;
  final String? imageAsset;
  final String label;
  final String headline;
  final Color? headlineColor;
  final String? supportingText;
  final bool compactHeadline;
  final Widget? trailingWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AtelierColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: imageAsset != null
                      ? Center(
                          child: Image.asset(
                            imageAsset!,
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.groups_2_rounded,
                                  size: 18,
                                  color: AtelierColors.primary,
                                ),
                          ),
                        )
                      : Icon(
                          icon,
                          size: 20,
                          color: AtelierColors.onSurfaceVariant,
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AtelierColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  headline,
                  key: valueKey,
                  maxLines: compactHeadline ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: compactHeadline ? 18 : 24,
                    fontWeight: FontWeight.w800,
                    height: compactHeadline ? 1.2 : 1.0,
                    color: headlineColor ?? AtelierColors.onSurface,
                  ),
                ),
                if (supportingText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    supportingText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      color: AtelierColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailingWidget != null) ...[
            const SizedBox(width: 16),
            trailingWidget!,
          ],
        ],
      ),
    );
  }
}

class _ActiveCoachesSummaryCard extends ConsumerWidget {
  const _ActiveCoachesSummaryCard({required this.summaryAsync});

  final AsyncValue<MemberHomeSummaryEntity> summaryAsync;

  void _navigateToCoaches(WidgetRef ref) {
    ref.read(memberHomeTabSwitchProvider.notifier).state = 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _navigateToCoaches(ref),
      child: summaryAsync.when(
        loading: () => const _DashboardMetricTile(
          cardKey: Key('member-summary-active-coaches'),
          valueKey: Key('member-summary-active-coaches-value'),
          imageAsset: 'assets/images/coaches_icon.png',
          label: 'ACTIVE COACHES',
          headline: 'Loading...',
          compactHeadline: true,
          supportingText: 'Checking live coach assignments.',
          trailingWidget: _MetricLoadingGlyph(),
        ),
        error: (_, _) => const _DashboardMetricTile(
          cardKey: Key('member-summary-active-coaches'),
          valueKey: Key('member-summary-active-coaches-value'),
          imageAsset: 'assets/images/coaches_icon.png',
          label: 'ACTIVE COACHES',
          headline: 'Unavailable',
          compactHeadline: true,
          supportingText: 'Unable to load coaching status.',
          trailingWidget: _MetricErrorGlyph(),
        ),
        data: (summary) {
          final count = summary.activeCoachCount;
          final supportingText = count == 0
              ? summary.hasPendingCoachCheckout
                    ? 'Checkout pending. This count updates as soon as your coach is active.'
                    : 'No active coach subscription. Tap to browse coaches.'
              : count == 1
              ? '1 live coach connection.'
              : '$count live coach connections.';

          return _DashboardMetricTile(
            cardKey: const Key('member-summary-active-coaches'),
            valueKey: const Key('member-summary-active-coaches-value'),
            imageAsset: 'assets/images/coaches_icon.png',
            label: 'ACTIVE COACHES',
            headline: '$count',
            supportingText: supportingText,
            trailingWidget: _CoachPresenceStack(count: count),
          );
        },
      ),
    );
  }
}

class _LatestWeightSummaryCard extends StatelessWidget {
  const _LatestWeightSummaryCard({required this.summaryAsync});

  final AsyncValue<MemberHomeSummaryEntity> summaryAsync;

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => const _DashboardMetricTile(
        cardKey: Key('member-summary-latest-weight'),
        valueKey: Key('member-summary-latest-weight-value'),
        icon: Icons.monitor_weight_outlined,
        label: 'LATEST WEIGHT',
        headline: 'Loading...',
        compactHeadline: true,
        supportingText: 'Syncing your latest weigh-in.',
        trailingWidget: _MetricLoadingGlyph(),
      ),
      error: (_, _) => const _DashboardMetricTile(
        cardKey: Key('member-summary-latest-weight'),
        valueKey: Key('member-summary-latest-weight-value'),
        icon: Icons.monitor_weight_outlined,
        label: 'LATEST WEIGHT',
        headline: 'Unavailable',
        compactHeadline: true,
        supportingText: 'Unable to load weight data right now.',
        trailingWidget: _MetricErrorGlyph(),
      ),
      data: (summary) {
        final latestWeight = summary.latestWeightEntry;
        if (latestWeight == null) {
          return const _DashboardMetricTile(
            cardKey: Key('member-summary-latest-weight'),
            valueKey: Key('member-summary-latest-weight-value'),
            icon: Icons.monitor_weight_outlined,
            label: 'LATEST WEIGHT',
            headline: 'No weight data yet',
            compactHeadline: true,
            supportingText:
                'Track your first weigh-in to unlock real trend changes.',
            trailingWidget: _WeightTrendGlyph(
              direction: MemberWeightTrendDirection.neutral,
            ),
          );
        }

        return _DashboardMetricTile(
          cardKey: const Key('member-summary-latest-weight'),
          valueKey: const Key('member-summary-latest-weight-value'),
          icon: Icons.monitor_weight_outlined,
          label: 'LATEST WEIGHT',
          headline: '${latestWeight.weightKg.toStringAsFixed(1)} kg',
          supportingText: _buildWeightSupportingText(summary),
          trailingWidget: _WeightTrendGlyph(
            direction: summary.weightTrendDirection,
          ),
        );
      },
    );
  }

  String _buildWeightSupportingText(MemberHomeSummaryEntity summary) {
    final latest = summary.latestWeightEntry;
    if (latest == null) {
      return 'No weight data yet.';
    }
    final updatedAt = _formatMetricDate(latest.recordedAt);
    final delta = summary.weightDeltaKg;
    if (delta == null) {
      return 'First recorded weigh-in. Updated $updatedAt.';
    }
    if (summary.weightTrendDirection == MemberWeightTrendDirection.stable) {
      return 'Stable vs previous entry. Updated $updatedAt.';
    }
    final amount = delta.abs().toStringAsFixed(1);
    if (summary.weightTrendDirection == MemberWeightTrendDirection.down) {
      return '$amount kg down vs previous entry. Updated $updatedAt.';
    }
    return '$amount kg up vs previous entry. Updated $updatedAt.';
  }
}

class _CurrentPlanSummaryCard extends StatelessWidget {
  const _CurrentPlanSummaryCard({required this.summaryAsync});

  final AsyncValue<MemberHomeSummaryEntity> summaryAsync;

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => const _DashboardMetricTile(
        cardKey: Key('member-summary-current-plan'),
        valueKey: Key('member-summary-current-plan-value'),
        icon: Icons.event_note_outlined,
        label: 'CURRENT PLAN',
        headline: 'Loading...',
        compactHeadline: true,
        supportingText: 'Checking your live AI plan.',
        trailingWidget: _MetricLoadingGlyph(),
      ),
      error: (_, _) => const _DashboardMetricTile(
        cardKey: Key('member-summary-current-plan'),
        valueKey: Key('member-summary-current-plan-value'),
        icon: Icons.event_note_outlined,
        label: 'CURRENT PLAN',
        headline: 'Unavailable',
        compactHeadline: true,
        supportingText: 'Unable to load AI plan status.',
        trailingWidget: _MetricErrorGlyph(),
      ),
      data: (summary) {
        final consistency = summary.planConsistency;
        final activePlan = summary.activeAiPlan;
        final hasActivePlan = activePlan != null;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (activePlan != null) {
              Navigator.pushNamed(
                context,
                AppRoutes.workoutPlan,
                arguments: WorkoutPlanArgs(planId: activePlan.id),
              );
              return;
            }
            Navigator.pushNamed(context, AppRoutes.aiPlannerBuilder);
          },
          child: _DashboardMetricTile(
            cardKey: const Key('member-summary-current-plan'),
            valueKey: const Key('member-summary-current-plan-value'),
            icon: Icons.event_note_outlined,
            label: 'CURRENT PLAN',
            headline: hasActivePlan ? 'Live' : 'No active plan',
            compactHeadline: !hasActivePlan,
            headlineColor: hasActivePlan ? AtelierColors.success : null,
            supportingText: _buildPlanSupportingText(
              hasActivePlan: hasActivePlan,
              consistency: consistency,
              planTitle: activePlan?.title,
            ),
            trailingWidget: _PlanConsistencyGlyph(
              weeks: hasActivePlan
                  ? consistency.visibleWeeks
                  : const <MemberPlanConsistencyWeek>[],
              visualCap: consistency.visualCap,
              hasActivePlan: hasActivePlan,
            ),
          ),
        );
      },
    );
  }

  String _buildPlanSupportingText({
    required bool hasActivePlan,
    required MemberPlanConsistencySummary consistency,
    String? planTitle,
  }) {
    if (!hasActivePlan) {
      return 'Tap to build and activate your AI workout plan.';
    }
    final title = planTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return '$title. Tap to open your workout plan.';
    }
    if (consistency.currentStreakWeeks > 0) {
      return '${_pluralize(consistency.currentStreakWeeks, 'consistent week')} in a row. Tap to open.';
    }
    if (consistency.totalConsistentWeeks > 0) {
      return '${_pluralize(consistency.totalConsistentWeeks, 'consistent week')} logged so far. Tap to open.';
    }
    return 'Plan is live. Tap to open your workout plan.';
  }
}

class _MetricLoadingGlyph extends StatelessWidget {
  const _MetricLoadingGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 54,
      height: 54,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AtelierColors.primary,
          ),
        ),
      ),
    );
  }
}

class _MetricErrorGlyph extends StatelessWidget {
  const _MetricErrorGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.sync_problem_rounded,
        color: AtelierColors.error,
        size: 22,
      ),
    );
  }
}

class _CoachPresenceStack extends StatelessWidget {
  const _CoachPresenceStack({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final visibleCount = math.max(0, math.min(count, 3));

    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: AppMotion.emphasizedCurve,
      switchOutCurve: AppMotion.exitCurve,
      transitionBuilder: _fadeSlide,
      child: SizedBox(
        key: ValueKey(count),
        width: 76,
        height: 74,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 8,
              right: 8,
              top: 6,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: count == 0
                      ? AtelierColors.surfaceContainer
                      : AtelierColors.primary.withValues(alpha: 0.10),
                ),
              ),
            ),
            if (count == 0)
              Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AtelierColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AtelierColors.outlineVariant,
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.groups_2_rounded,
                    color: AtelierColors.onSurfaceVariant,
                    size: 18,
                  ),
                ),
              )
            else
              for (var index = 0; index < visibleCount; index++)
                Positioned(
                  left: 10.0 + (index * 14),
                  top: index.isEven ? 16 : 8,
                  child: _CoachPresenceAvatar(index: index),
                ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AtelierColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: count == 0
                        ? AtelierColors.onSurfaceVariant
                        : AtelierColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachPresenceAvatar extends StatelessWidget {
  const _CoachPresenceAvatar({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = <Color>[
      AtelierColors.primary.withValues(alpha: 0.92),
      AtelierColors.primaryContainer.withValues(alpha: 0.92),
      AtelierColors.success.withValues(alpha: 0.88),
    ];

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: palette[index % palette.length],
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_rounded,
        color: AtelierColors.white,
        size: 15,
      ),
    );
  }
}

class _WeightTrendGlyph extends StatelessWidget {
  const _WeightTrendGlyph({required this.direction});

  final MemberWeightTrendDirection direction;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: AppMotion.emphasizedCurve,
      switchOutCurve: AppMotion.exitCurve,
      transitionBuilder: _fadeSlide,
      child: _AnimatedWeightTrendGlyph(
        key: ValueKey(direction),
        direction: direction,
      ),
    );
  }
}

class _AnimatedWeightTrendGlyph extends StatelessWidget {
  const _AnimatedWeightTrendGlyph({super.key, required this.direction});

  final MemberWeightTrendDirection direction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 46,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: AppMotion.slow,
        curve: AppMotion.emphasizedCurve,
        builder: (context, reveal, _) {
          return CustomPaint(
            painter: _WeightTrendGlyphPainter(
              direction: direction,
              reveal: reveal,
            ),
          );
        },
      ),
    );
  }
}

class _WeightTrendGlyphPainter extends CustomPainter {
  _WeightTrendGlyphPainter({required this.direction, required this.reveal});

  final MemberWeightTrendDirection direction;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final color = _colorFor(direction);
    final values = _normalizedValues(direction);
    final step = size.width / (values.length - 1);
    final points = values
        .asMap()
        .entries
        .map((entry) => Offset(step * entry.key, size.height * entry.value))
        .toList(growable: false);

    canvas.drawLine(
      Offset(0, size.height * 0.8),
      Offset(size.width, size.height * 0.8),
      Paint()
        ..color = AtelierColors.outlineVariant.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(controlX, current.dy, controlX, next.dy, next.dx, next.dy);
    }

    final areaPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));
    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    if (reveal >= 0.98) {
      canvas.drawCircle(points.last, 3.5, Paint()..color = color);
    }
  }

  List<double> _normalizedValues(MemberWeightTrendDirection direction) {
    switch (direction) {
      case MemberWeightTrendDirection.down:
        return const <double>[0.30, 0.38, 0.44, 0.58, 0.70];
      case MemberWeightTrendDirection.up:
        return const <double>[0.70, 0.58, 0.50, 0.38, 0.26];
      case MemberWeightTrendDirection.stable:
        return const <double>[0.49, 0.48, 0.50, 0.49, 0.48];
      case MemberWeightTrendDirection.neutral:
        return const <double>[0.56, 0.54, 0.53, 0.52, 0.51];
    }
  }

  Color _colorFor(MemberWeightTrendDirection direction) {
    switch (direction) {
      case MemberWeightTrendDirection.down:
        return AtelierColors.success;
      case MemberWeightTrendDirection.up:
        return AtelierColors.primary;
      case MemberWeightTrendDirection.stable:
        return AtelierColors.onSurfaceVariant;
      case MemberWeightTrendDirection.neutral:
        return AtelierColors.textMuted;
    }
  }

  @override
  bool shouldRepaint(covariant _WeightTrendGlyphPainter oldDelegate) {
    return oldDelegate.direction != direction || oldDelegate.reveal != reveal;
  }
}

class _PlanConsistencyGlyph extends StatelessWidget {
  const _PlanConsistencyGlyph({
    required this.weeks,
    required this.visualCap,
    required this.hasActivePlan,
  });

  final List<MemberPlanConsistencyWeek> weeks;
  final int visualCap;
  final bool hasActivePlan;

  @override
  Widget build(BuildContext context) {
    final visibleWeeks = weeks.length <= visualCap
        ? weeks
        : weeks.sublist(weeks.length - visualCap);
    final dotStates = hasActivePlan
        ? (visibleWeeks.isEmpty
              ? List<MemberPlanConsistencyState>.filled(
                  math.min(visualCap, 4),
                  MemberPlanConsistencyState.pending,
                )
              : visibleWeeks.map((week) => week.state).toList(growable: false))
        : List<MemberPlanConsistencyState>.filled(
            math.min(visualCap, 6),
            MemberPlanConsistencyState.pending,
          );

    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: AppMotion.emphasizedCurve,
      switchOutCurve: AppMotion.exitCurve,
      transitionBuilder: _fadeSlide,
      child: KeyedSubtree(
        key: ValueKey(dotStates.map((state) => state.name).join('-')),
        child: Row(
          key: const Key('member-summary-current-plan-dots'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < dotStates.length; index++)
              Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                child: _PlanConsistencyDotGlyph(
                  key: ValueKey(
                    'member-summary-plan-dot-$index-${dotStates[index].name}',
                  ),
                  state: dotStates[index],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanConsistencyDotGlyph extends StatelessWidget {
  const _PlanConsistencyDotGlyph({super.key, required this.state});

  final MemberPlanConsistencyState state;

  @override
  Widget build(BuildContext context) {
    final isConsistent = state == MemberPlanConsistencyState.consistent;
    final isPending = state == MemberPlanConsistencyState.pending;

    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.standardCurve,
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isConsistent
            ? AtelierColors.success
            : isPending
            ? AtelierColors.transparent
            : AtelierColors.primary.withValues(alpha: 0.20),
        border: Border.all(
          color: isConsistent
              ? AtelierColors.success
              : AtelierColors.outlineVariant.withValues(
                  alpha: isPending ? 0.9 : 0.55,
                ),
          width: 1.2,
        ),
      ),
    );
  }
}

class _DynamicNextStepCard extends StatelessWidget {
  const _DynamicNextStepCard({
    required this.hasActiveCoach,
    required this.hasPendingCoachCheckout,
  });

  final bool hasActiveCoach;
  final bool hasPendingCoachCheckout;

  @override
  Widget build(BuildContext context) {
    final label = hasPendingCoachCheckout
        ? 'Complete Checkout'
        : hasActiveCoach
        ? 'Submit Check-in'
        : 'Browse Coaches';
    final cta = hasPendingCoachCheckout
        ? 'Checkout Now'
        : hasActiveCoach
        ? 'Open Check-in'
        : 'Find a Coach';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AtelierColors.darkCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT STEP',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: AtelierColors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AtelierColors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  AtelierColors.primary,
                  AtelierColors.primaryContainer,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Material(
              color: AtelierColors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(9999),
                onTap: () {
                  if (hasPendingCoachCheckout || !hasActiveCoach) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CoachesScreen()),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MemberCheckinsScreen(),
                    ),
                  );
                },
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cta,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AtelierColors.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AtelierColors.onPrimary,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMetricDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _pluralize(int value, String noun) {
  return value == 1 ? '1 $noun' : '$value ${noun}s';
}

class _AiCoachFeaturedCard extends StatelessWidget {
  const _AiCoachFeaturedCard({required this.briefAsync});

  final AsyncValue<AiDailyBriefEntity?> briefAsync;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: _buildAiHome)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AtelierColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AtelierColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome_outlined,
                color: AtelierColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: briefAsync.when(
                loading: () => _buildCopy(
                  title: 'Open TAIYO',
                  subtitle: 'Preparing today\'s coach brief...',
                ),
                error: (error, stackTrace) => _buildCopy(
                  title: 'Open TAIYO',
                  subtitle: 'Daily AI coaching and workout guidance',
                ),
                data: (brief) => _buildCopy(
                  title: _resolveBriefTitle(brief),
                  subtitle: _resolveBriefSubtitle(brief),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopy({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AtelierColors.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AtelierColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _resolveBriefTitle(AiDailyBriefEntity? brief) {
    try {
      final title = brief?.workoutTitle.trim();
      if (title != null && title.isNotEmpty) {
        return title;
      }
    } catch (_) {
      // Fall back to safe copy when backend payloads are partially malformed.
    }
    return 'Open TAIYO';
  }

  String _resolveBriefSubtitle(AiDailyBriefEntity? brief) {
    final subtitle = brief?.whyShort.trim();
    if (subtitle != null && subtitle.isNotEmpty) {
      return subtitle;
    }
    return 'Daily AI coaching and workout guidance';
  }
}

class _FeaturedActionCard extends StatefulWidget {
  const _FeaturedActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.destinationBuilder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function(BuildContext) destinationBuilder;

  @override
  State<_FeaturedActionCard> createState() => _FeaturedActionCardState();
}

class _FeaturedActionCardState extends State<_FeaturedActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? AppMotion.pressedScale : 1,
      duration: AppMotion.fast,
      curve: AppMotion.standardCurve,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: widget.destinationBuilder),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AtelierColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: AtelierColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AtelierColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AtelierColors.onSurfaceVariant,
                      ),
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

// ═══════════════════════════════════════════════════════════════════════════
//  QUICK-ACTIONS GRID (2 COLUMNS)
// ═══════════════════════════════════════════════════════════════════════════

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final actions = <_GridAction>[
      _GridAction(
        title: 'Open news\nfeed',
        icon: Icons.newspaper_outlined,
        destinationBuilder: _buildNewsFeed,
      ),
      _GridAction(
        title: 'Open my\ncoaching',
        icon: Icons.workspace_premium_outlined,
        destinationBuilder: _buildSubscriptions,
      ),
      _GridAction(
        title: 'Weekly\ncheck-ins',
        icon: Icons.assignment_outlined,
        destinationBuilder: _buildCheckins,
      ),
      _GridAction(
        title: 'Submit\nprogress',
        icon: Icons.trending_up_outlined,
        destinationBuilder: _buildProgress,
      ),
      _GridAction(
        title: 'Browse\ncoaches',
        icon: Icons.search_rounded,
        destinationBuilder: _buildCoaches,
      ),
      _GridAction(
        title: 'Open\nmessages',
        icon: Icons.chat_bubble_outline_rounded,
        destinationBuilder: _buildMessages,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _GridActionTile(action: action);
      },
    );
  }
}

class _GridAction {
  const _GridAction({
    required this.title,
    required this.icon,
    required this.destinationBuilder,
  });

  final String title;
  final IconData icon;
  final Widget Function(BuildContext) destinationBuilder;
}

class _GridActionTile extends StatefulWidget {
  const _GridActionTile({required this.action});

  final _GridAction action;

  @override
  State<_GridActionTile> createState() => _GridActionTileState();
}

class _GridActionTileState extends State<_GridActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? AppMotion.pressedScale : 1,
      duration: AppMotion.fast,
      curve: AppMotion.standardCurve,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: widget.action.destinationBuilder),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AtelierColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.action.icon,
                  size: 20,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                widget.action.title,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: AtelierColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  BROWSE STORE
// ═══════════════════════════════════════════════════════════════════════════

class _BrowseStoreCard extends StatefulWidget {
  const _BrowseStoreCard();

  @override
  State<_BrowseStoreCard> createState() => _BrowseStoreCardState();
}

class _BrowseStoreCardState extends State<_BrowseStoreCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? AppMotion.pressedScale : 1,
      duration: AppMotion.fast,
      curve: AppMotion.standardCurve,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StoreHomeScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Browse store',
                      style: GoogleFonts.notoSerif(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AtelierColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Premium essentials for your transformation',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AtelierColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Decorative element
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AtelierColors.primaryContainer.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AtelierColors.primaryContainer,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════

// ignore: unused_element
class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AtelierColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════

Widget _fadeSlide(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: AppMotion.standardCurve,
    reverseCurve: AppMotion.exitCurve,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.035),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

Widget _buildAiHome(BuildContext context) => const AiCoachHomeScreen();

Widget _buildNewsFeed(BuildContext context) => const NewsFeedScreen();

Widget _buildSubscriptions(BuildContext context) =>
    const MemberCoachHubScreen();

Widget _buildCheckins(BuildContext context) => const MemberCheckinsScreen();

Widget _buildProgress(BuildContext context) => const ProgressScreen();

Widget _buildCoaches(BuildContext context) => const CoachesScreen();

Widget _buildMessages(BuildContext context) => const MemberMessagesScreen();
