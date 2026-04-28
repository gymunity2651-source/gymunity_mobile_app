import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/ai_branding.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../member/presentation/providers/member_providers.dart';
import '../../../member/presentation/widgets/member_profile_shortcut_button.dart';
import '../../../monetization/presentation/providers/monetization_providers.dart';
import '../../../monetization/presentation/screens/ai_premium_paywall_screen.dart';
import '../../../planner/presentation/route_args.dart';
import '../../domain/entities/chat_session_entity.dart';
import '../ai_personalization.dart';
import '../providers/chat_controller.dart';
import '../providers/chat_providers.dart';

const double _memberFloatingNavHeight = 68;
const double _memberFloatingNavBottomSpacing = 20;

class AiChatHomeScreen extends ConsumerWidget {
  const AiChatHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateAsync = ref.watch(aiPremiumGateProvider);

    return gateAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AtelierColors.surface,
        body: _TaiyoCanvas(
          child: Center(
            child: CircularProgressIndicator(color: AtelierColors.primary),
          ),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: AtelierColors.surface,
        body: _TaiyoCanvas(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'GymUnity could not verify ${AiBranding.premiumName} access right now.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      height: 1.6,
                      color: AtelierColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(currentSubscriptionSummaryProvider.notifier)
                        .refreshFromBackend(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      data: (gate) {
        if (gate.requiresBilling && !gate.hasAccess) {
          return AiPremiumPaywallScreen(
            showBackButton: false,
            lockReason: gate.message,
          );
        }
        return const _AiChatHomeUnlocked();
      },
    );
  }
}

class _AiChatHomeUnlocked extends ConsumerWidget {
  const _AiChatHomeUnlocked();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatControllerProvider);
    final sessionsAsync = ref.watch(chatSessionsProvider);
    final memberProfile = ref.watch(memberProfileDetailsProvider).valueOrNull;
    final memberSummary = ref.watch(memberHomeSummaryProvider).valueOrNull;
    final personalizedSuggestions = buildPersonalizedAiSuggestions(
      profile: memberProfile,
      summary: memberSummary,
    );
    final quickActions = _buildQuickActions(personalizedSuggestions);
    final metricCards = <_TaiyoMetricCardData>[
      _TaiyoMetricCardData(
        title: 'Saved sessions',
        subtitle: 'Your archived flows and active projects.',
        value: '${sessionsAsync.valueOrNull?.length ?? 0}',
        suffix: 'Total',
        leadingIcon: Icons.arrow_outward_rounded,
      ),
      _TaiyoMetricCardData(
        title: 'Quick prompts',
        subtitle: 'Ready-to-use structural starting points.',
        value: '${quickActions.length}',
        suffix: 'Available',
        leadingIcon: Icons.auto_awesome_rounded,
      ),
    ];
    final bottomBarClearance = _memberBottomBarClearance(context);

    Future<void> openSession({
      required ChatSessionType type,
      String? sessionId,
      String? seedPrompt,
    }) async {
      if (type == ChatSessionType.planner) {
        Navigator.pushNamed(
          context,
          AppRoutes.aiPlannerBuilder,
          arguments: PlannerBuilderArgs(
            seedPrompt: seedPrompt,
            existingSessionId: sessionId,
          ),
        );
        return;
      }

      try {
        final resolvedSessionId =
            sessionId ??
            await ref
                .read(chatControllerProvider.notifier)
                .createSessionIfNeeded(null, type: type);
        ref.read(activeChatSessionIdProvider.notifier).state =
            resolvedSessionId;
        ref.read(pendingChatPromptProvider.notifier).state = seedPrompt?.trim();
        if (!context.mounted) {
          return;
        }
        Navigator.pushNamed(
          context,
          AppRoutes.aiConversation,
          arguments: resolvedSessionId,
        );
      } catch (_) {
        if (!context.mounted) {
          return;
        }
        showAppFeedback(context, 'GymUnity could not open TAIYO right now.');
      }
    }

    void openPlannerSession(ChatSessionEntity session) {
      final draftId = session.latestDraftId;
      final status = session.plannerStatus.trim().toLowerCase();
      final canReview =
          draftId != null &&
          draftId.isNotEmpty &&
          (status == 'plan_ready' ||
              status == 'plan_updated' ||
              status == 'activated');
      if (canReview) {
        Navigator.pushNamed(
          context,
          AppRoutes.aiGeneratedPlan,
          arguments: AiGeneratedPlanArgs(
            sessionId: session.id,
            draftId: draftId,
          ),
        );
        return;
      }
      Navigator.pushNamed(
        context,
        AppRoutes.aiPlannerBuilder,
        arguments: PlannerBuilderArgs(existingSessionId: session.id),
      );
    }

    return Scaffold(
      backgroundColor: AtelierColors.surface,
      body: _TaiyoCanvas(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: _TaiyoTopChrome(),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSizes.xl,
                    28,
                    AppSizes.xl,
                    bottomBarClearance + 28,
                  ),
                  children: [
                    const _TaiyoHeroSection(),
                    const SizedBox(height: 24),
                    _TaiyoCommandDeck(
                      onOpenBuilder: chatState.isSending
                          ? null
                          : () => openSession(type: ChatSessionType.planner),
                      onOpenChat: chatState.isSending
                          ? null
                          : () => openSession(type: ChatSessionType.general),
                    ),
                    const SizedBox(height: 24),
                    _TaiyoFeatureCard(
                      icon: Icons.architecture_rounded,
                      title: 'Build a plan\nwith TAIYO',
                      description:
                          'Generate a highly specific, phase-based progression model for strength or endurance, adapting weekly to your physiological feedback.',
                      buttonLabel: 'OPEN BUILDER',
                      buttonKey: const Key('taiyo-open-builder-button'),
                      filledButton: true,
                      onPressed: chatState.isSending
                          ? null
                          : () => openSession(type: ChatSessionType.planner),
                    ),
                    const SizedBox(height: 22),
                    _TaiyoTalkCard(
                      onPromptTap: (prompt) => openSession(
                        type: ChatSessionType.general,
                        seedPrompt: prompt,
                      ),
                      onOpenTap: chatState.isSending
                          ? null
                          : () => openSession(type: ChatSessionType.general),
                    ),
                    const SizedBox(height: 34),
                    _TaiyoMetricsSection(cards: metricCards),
                    const SizedBox(height: 34),
                    _TaiyoSectionHeader(title: 'Quick Actions', trailing: null),
                    const SizedBox(height: 10),
                    ...quickActions.map(
                      (action) => _TaiyoQuickActionRow(
                        icon: action.icon,
                        label: action.label,
                        onTap: () => openSession(
                          type: action.type,
                          seedPrompt: action.prompt,
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    const _TaiyoSectionHeader(
                      title: 'Recent TAIYO\nsessions',
                      trailing: _TaiyoViewAllLabel(),
                    ),
                    const SizedBox(height: 16),
                    sessionsAsync.when(
                      loading: () => const _TaiyoStateCard(
                        loading: true,
                        title: 'Loading your recent sessions',
                        description:
                            'TAIYO is gathering the flows you recently opened.',
                      ),
                      error: (error, stackTrace) => _TaiyoStateCard(
                        title: 'Unable to load TAIYO sessions',
                        description:
                            'GymUnity could not fetch your saved TAIYO conversations from Supabase.',
                        actionLabel: 'Retry',
                        onTap: () => ref.refresh(chatSessionsProvider),
                      ),
                      data: (sessions) {
                        if (sessions.isEmpty) {
                          return _TaiyoStateCard(
                            title: 'No TAIYO sessions yet',
                            description:
                                'Start the builder or open a guided conversation and your recent flows will appear here.',
                            actionLabel: 'Open builder',
                            onTap: () =>
                                openSession(type: ChatSessionType.planner),
                          );
                        }

                        final cards = sessions
                            .take(4)
                            .toList(growable: false)
                            .asMap()
                            .entries
                            .map(
                              (entry) => _RecentSessionCardData.fromSession(
                                entry.value,
                                index: entry.key,
                              ),
                            )
                            .toList(growable: false);

                        return Column(
                          children: [
                            for (
                              var index = 0;
                              index < cards.length;
                              index++
                            ) ...[
                              _TaiyoSessionCard(
                                data: cards[index],
                                onTap: () => cards[index].session.isPlanner
                                    ? openPlannerSession(cards[index].session)
                                    : openSession(
                                        type: cards[index].session.type,
                                        sessionId: cards[index].session.id,
                                      ),
                              ),
                              if (index < cards.length - 1)
                                const SizedBox(height: 16),
                            ],
                          ],
                        );
                      },
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

double _memberBottomBarClearance(BuildContext context) {
  final safeBottom = MediaQuery.of(context).viewPadding.bottom;
  return _memberFloatingNavHeight +
      math.max(safeBottom, _memberFloatingNavBottomSpacing);
}

List<_QuickAction> _buildQuickActions(
  List<AiEntrySuggestion> personalizedSuggestions,
) {
  final actions = <_QuickAction>[
    ...personalizedSuggestions.map(_quickActionFromSuggestion),
    const _QuickAction(
      icon: Icons.fitness_center_rounded,
      label: 'Strength plan',
      type: ChatSessionType.planner,
      prompt:
          'I want a structured strength-focused plan. Ask me the key questions you need first.',
    ),
    const _QuickAction(
      icon: Icons.directions_run_rounded,
      label: 'Fat loss plan',
      type: ChatSessionType.planner,
      prompt:
          'I want a realistic fat loss plan. Ask me for the missing details before generating it.',
    ),
    const _QuickAction(
      icon: Icons.restaurant_menu_rounded,
      label: 'Nutrition tips',
      type: ChatSessionType.general,
      prompt:
          'Give me practical nutrition tips that support my current fitness goal.',
    ),
  ];

  final seenLabels = <String>{};
  return actions
      .where((action) {
        final key = action.label.trim().toLowerCase();
        return seenLabels.add(key);
      })
      .toList(growable: false);
}

_QuickAction _quickActionFromSuggestion(AiEntrySuggestion suggestion) {
  final normalizedLabel = suggestion.label.trim().toLowerCase();
  final isPlanner =
      normalizedLabel.contains('plan') || normalizedLabel.contains('refine');
  return _QuickAction(
    icon: _iconForSuggestionLabel(normalizedLabel),
    label: suggestion.label,
    prompt: suggestion.prompt,
    type: isPlanner ? ChatSessionType.planner : ChatSessionType.general,
  );
}

IconData _iconForSuggestionLabel(String normalizedLabel) {
  if (normalizedLabel.contains('refine')) {
    return Icons.tune_rounded;
  }
  if (normalizedLabel.contains('restart')) {
    return Icons.history_rounded;
  }
  if (normalizedLabel.contains('progress')) {
    return Icons.query_stats_rounded;
  }
  if (normalizedLabel.contains('strength')) {
    return Icons.fitness_center_rounded;
  }
  if (normalizedLabel.contains('nutrition')) {
    return Icons.restaurant_menu_rounded;
  }
  if (normalizedLabel.contains('fat')) {
    return Icons.directions_run_rounded;
  }
  return Icons.auto_awesome_rounded;
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.prompt,
    required this.type,
  });

  final IconData icon;
  final String label;
  final String prompt;
  final ChatSessionType type;
}

class _TaiyoCanvas extends StatelessWidget {
  const _TaiyoCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFEFC), AtelierColors.surface, Color(0xFFFFFEFC)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -120,
            right: -70,
            child: _TaiyoGlowOrb(
              size: 260,
              colors: [
                Color(0x26FFB798),
                Color(0x12F4D4C8),
                Colors.transparent,
              ],
            ),
          ),
          const Positioned(
            top: 280,
            left: -110,
            child: _TaiyoGlowOrb(
              size: 220,
              colors: [
                Color(0x18EADFD7),
                Color(0x0CF0EAE5),
                Colors.transparent,
              ],
            ),
          ),
          const Positioned(
            bottom: 140,
            right: -70,
            child: _TaiyoGlowOrb(
              size: 240,
              colors: [
                Color(0x16F0D2C0),
                Color(0x08FFFFFF),
                Colors.transparent,
              ],
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _TaiyoGlowOrb extends StatelessWidget {
  const _TaiyoGlowOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }
}

class _TaiyoTopChrome extends StatelessWidget {
  const _TaiyoTopChrome();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _TaiyoVisualMenuButton(),
        Expanded(
          child: Center(
            child: Text(
              AiBranding.assistantName,
              style: GoogleFonts.notoSerif(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AtelierColors.onSurface,
              ),
            ),
          ),
        ),
        const MemberProfileShortcutButton(
          backgroundColor: AtelierColors.surfaceContainerLowest,
          iconColor: AtelierColors.onSurface,
          borderColor: AtelierColors.ghostBorder,
          size: 48,
          tooltip: 'Profile',
          buttonKey: Key('taiyo-profile-shortcut'),
        ),
      ],
    );
  }
}

class _TaiyoVisualMenuButton extends StatelessWidget {
  const _TaiyoVisualMenuButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AtelierColors.surfaceContainerLowest,
      shape: const CircleBorder(),
      shadowColor: AtelierColors.navShadow,
      elevation: 1,
      child: InkWell(
        key: const Key('taiyo-menu-visual-button'),
        customBorder: const CircleBorder(),
        onTap: null,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.menu_rounded, color: AtelierColors.onSurface),
        ),
      ),
    );
  }
}

class _TaiyoHeroSection extends StatelessWidget {
  const _TaiyoHeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INTELLIGENCE',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
            color: AtelierColors.primary,
          ),
        ),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Your Personal\n',
                style: GoogleFonts.notoSerif(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1.04,
                  color: AtelierColors.onSurface,
                ),
              ),
              TextSpan(
                text: 'Sanctuary',
                style: GoogleFonts.notoSerif(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  height: 1.04,
                  color: AtelierColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 2,
              height: 146,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AtelierColors.primary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                'Curated guidance, grounded in science. Tailored nutrition and movement strategies designed specifically for your body and your lifestyle.',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  height: 1.55,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TaiyoCommandDeck extends StatelessWidget {
  const _TaiyoCommandDeck({
    required this.onOpenBuilder,
    required this.onOpenChat,
  });

  final VoidCallback? onOpenBuilder;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final buildButton = _TaiyoActionButton(
      label: 'BUILD',
      onPressed: onOpenBuilder,
      keyValue: const Key('taiyo-hero-build-button'),
      filled: true,
      fullWidth: true,
      leadingIcon: Icons.architecture_rounded,
    );
    final chatButton = _TaiyoActionButton(
      label: 'CHAT',
      onPressed: onOpenChat,
      keyValue: const Key('taiyo-hero-chat-button'),
      filled: false,
      fullWidth: true,
      leadingIcon: Icons.chat_bubble_outline_rounded,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1EA),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AtelierColors.ghostBorder.withValues(alpha: 0.75),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10291E14),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'START HERE',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.1,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Go directly to Build or Chat.',
            style: GoogleFonts.notoSerif(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.08,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Use Build for a guided plan flow, or jump straight into Chat for a live TAIYO conversation.',
            style: GoogleFonts.manrope(
              fontSize: 16,
              height: 1.55,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    buildButton,
                    const SizedBox(height: 12),
                    chatButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: buildButton),
                  const SizedBox(width: 12),
                  Expanded(child: chatButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TaiyoFeatureCard extends StatelessWidget {
  const _TaiyoFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    required this.buttonKey,
    required this.filledButton,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final Key buttonKey;
  final bool filledButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F1),
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F291E14),
            blurRadius: 34,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Stack(
          children: [
            const Positioned(
              left: 110,
              top: -30,
              bottom: -40,
              child: _TaiyoVerticalSheen(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 30, 30, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AtelierColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AtelierColors.primary),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    title,
                    style: GoogleFonts.notoSerif(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      height: 1.04,
                      color: AtelierColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    description,
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      height: 1.62,
                      color: AtelierColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _TaiyoActionButton(
                    label: buttonLabel,
                    onPressed: onPressed,
                    keyValue: buttonKey,
                    filled: filledButton,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaiyoVerticalSheen extends StatelessWidget {
  const _TaiyoVerticalSheen();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.08,
      child: Container(
        width: 112,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.5),
              Colors.white.withValues(alpha: 0.12),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _TaiyoTalkCard extends StatelessWidget {
  const _TaiyoTalkCard({required this.onPromptTap, required this.onOpenTap});

  final ValueChanged<String> onPromptTap;
  final VoidCallback? onOpenTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F4),
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C291E14),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AtelierColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'Talk to TAIYO',
            style: GoogleFonts.notoSerif(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Immediate answers to nuanced questions. Ask about macro adjustments, recovery protocols, or biomechanical tweaks to your current routine.',
            style: GoogleFonts.manrope(
              fontSize: 17,
              height: 1.62,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _TaiyoPromptChip(
            icon: Icons.local_fire_department_outlined,
            prompt: 'How should I adjust my protein intake on rest days?',
            onTap: () => onPromptTap(
              'How should I adjust my protein intake on rest days?',
            ),
          ),
          const SizedBox(height: 12),
          _TaiyoPromptChip(
            icon: Icons.fitness_center_rounded,
            prompt:
                'Alternative exercises for barbell squats due to lower back fatigue?',
            onTap: () => onPromptTap(
              'Alternative exercises for barbell squats due to lower back fatigue?',
            ),
          ),
          const SizedBox(height: 24),
          _TaiyoActionButton(
            label: 'OPEN TAIYO',
            onPressed: onOpenTap,
            keyValue: const Key('taiyo-open-chat-button'),
            filled: false,
            fullWidth: true,
            leadingIcon: Icons.chat_bubble_outline_rounded,
          ),
        ],
      ),
    );
  }
}

class _TaiyoActionButton extends StatelessWidget {
  const _TaiyoActionButton({
    required this.label,
    required this.onPressed,
    required this.keyValue,
    required this.filled,
    this.fullWidth = false,
    this.leadingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key keyValue;
  final bool filled;
  final bool fullWidth;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      key: keyValue,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(fullWidth ? double.infinity : 198, 58),
        side: BorderSide(
          color: filled ? Colors.transparent : AtelierColors.ghostBorder,
        ),
        backgroundColor: filled
            ? AtelierColors.primary
            : AtelierColors.surfaceContainerLowest,
        foregroundColor: filled
            ? AtelierColors.onPrimary
            : AtelierColors.onSurface,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        textStyle: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 20),
            const SizedBox(width: 10),
          ],
          Text(label),
          const SizedBox(width: 12),
          Icon(
            filled ? Icons.arrow_forward_rounded : Icons.arrow_outward_rounded,
            size: 20,
          ),
        ],
      ),
    );

    if (!filled) {
      return button;
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(AppSizes.radiusFull)),
        boxShadow: [
          BoxShadow(
            color: Color(0x29974417),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: button,
    );
  }
}

class _TaiyoPromptChip extends StatelessWidget {
  const _TaiyoPromptChip({
    required this.icon,
    required this.prompt,
    required this.onTap,
  });

  final IconData icon;
  final String prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AtelierColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AtelierColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AtelierColors.primary, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '"$prompt"',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    height: 1.45,
                    color: AtelierColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaiyoMetricsSection extends StatelessWidget {
  const _TaiyoMetricsSection({required this.cards});

  final List<_TaiyoMetricCardData> cards;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Built so TAIYO\nfeels focused,\nfast, and useful.',
          style: GoogleFonts.notoSerif(
            fontSize: 31,
            fontWeight: FontWeight.w500,
            height: 1.06,
            color: AtelierColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'A curated digital sanctuary to build your perfect flow.',
          style: GoogleFonts.manrope(
            fontSize: 17,
            height: 1.55,
            color: AtelierColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        for (var index = 0; index < cards.length; index++) ...[
          _TaiyoMetricCard(data: cards[index]),
          if (index < cards.length - 1) const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _TaiyoMetricCardData {
  const _TaiyoMetricCardData({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.suffix,
    required this.leadingIcon,
  });

  final String title;
  final String subtitle;
  final String value;
  final String suffix;
  final IconData leadingIcon;
}

class _TaiyoMetricCard extends StatelessWidget {
  const _TaiyoMetricCard({required this.data});

  final _TaiyoMetricCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F3F1),
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C291E14),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: GoogleFonts.notoSerif(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: AtelierColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data.subtitle,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        height: 1.5,
                        color: AtelierColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AtelierColors.surfaceContainerLowest,
                  shape: BoxShape.circle,
                ),
                child: Icon(data.leadingIcon, color: AtelierColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 36),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.value,
                style: GoogleFonts.notoSerif(
                  fontSize: 56,
                  fontWeight: FontWeight.w400,
                  height: 0.95,
                  color: AtelierColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  data.suffix,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    color: AtelierColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaiyoSectionHeader extends StatelessWidget {
  const _TaiyoSectionHeader({required this.title, required this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 4,
          height: title.contains('\n') ? 72 : 38,
          decoration: BoxDecoration(
            color: AtelierColors.primary,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.notoSerif(
              fontSize: 29,
              fontWeight: FontWeight.w700,
              height: 1.06,
              color: AtelierColors.onSurface,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 18), trailing!],
      ],
    );
  }
}

class _TaiyoViewAllLabel extends StatelessWidget {
  const _TaiyoViewAllLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'VIEW\nALL',
      textAlign: TextAlign.right,
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: AtelierColors.primary,
      ),
    );
  }
}

class _TaiyoQuickActionRow extends StatelessWidget {
  const _TaiyoQuickActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAE7E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AtelierColors.onSurface, size: 21),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: AtelierColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSessionCardData {
  const _RecentSessionCardData({
    required this.session,
    required this.title,
    required this.durationLabel,
    required this.dateLabel,
    required this.icon,
    required this.gradientColors,
  });

  final ChatSessionEntity session;
  final String title;
  final String durationLabel;
  final String dateLabel;
  final IconData icon;
  final List<Color> gradientColors;

  factory _RecentSessionCardData.fromSession(
    ChatSessionEntity session, {
    required int index,
  }) {
    final artwork = _sessionArtwork(index: index, isPlanner: session.isPlanner);
    return _RecentSessionCardData(
      session: session,
      title: session.title.isEmpty ? 'New TAIYO chat' : session.title,
      durationLabel: '${_resolveSessionDurationMinutes(session)} min',
      dateLabel: _formatSessionDate(session.updatedAt),
      icon: artwork.$1,
      gradientColors: artwork.$2,
    );
  }
}

class _TaiyoSessionCard extends StatelessWidget {
  const _TaiyoSessionCard({required this.data, required this.onTap});

  final _RecentSessionCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AtelierColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A291E14),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              _TaiyoSessionBadge(
                icon: data.icon,
                gradientColors: data.gradientColors,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: GoogleFonts.notoSerif(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AtelierColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _SessionMetaPill(
                          icon: Icons.schedule_rounded,
                          label: data.durationLabel,
                        ),
                        Text(
                          '•',
                          style: GoogleFonts.manrope(
                            color: AtelierColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        _SessionMetaPill(
                          icon: Icons.calendar_today_outlined,
                          label: data.dateLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AtelierColors.primary,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaiyoSessionBadge extends StatelessWidget {
  const _TaiyoSessionBadge({required this.icon, required this.gradientColors});

  final IconData icon;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          child: Icon(icon, color: AtelierColors.surface, size: 18),
        ),
      ),
    );
  }
}

class _SessionMetaPill extends StatelessWidget {
  const _SessionMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AtelierColors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 15,
            color: AtelierColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TaiyoStateCard extends StatelessWidget {
  const _TaiyoStateCard({
    required this.title,
    required this.description,
    this.loading = false,
    this.actionLabel,
    this.onTap,
  });

  final String title;
  final String description;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A291E14),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AtelierColors.primary,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: AtelierColors.primary,
                size: 26,
              ),
            ),
          Text(
            title,
            style: GoogleFonts.notoSerif(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.manrope(
              fontSize: 16,
              height: 1.55,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          if (!loading && actionLabel != null && onTap != null) ...[
            const SizedBox(height: 18),
            _TaiyoActionButton(
              label: actionLabel!,
              onPressed: onTap,
              keyValue: Key('taiyo-state-${actionLabel!.toLowerCase()}'),
              filled: false,
            ),
          ],
        ],
      ),
    );
  }
}

int _resolveSessionDurationMinutes(ChatSessionEntity session) {
  final rawMinutes = session.plannerProfileJson['session_minutes'];
  if (rawMinutes is num && rawMinutes > 0) {
    return rawMinutes.toInt();
  }
  if (rawMinutes is String) {
    final parsed = int.tryParse(rawMinutes);
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }

  const fallbacks = <int>[15, 20, 30, 45];
  final seed =
      session.id.codeUnits.fold<int>(
        session.isPlanner ? 7 : 3,
        (sum, unit) => sum + unit,
      ) +
      session.title.length;
  return fallbacks[seed % fallbacks.length];
}

String _formatSessionDate(DateTime dateTime) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final difference = today.difference(target).inDays;

  if (difference <= 0) {
    return 'Today';
  }
  if (difference == 1) {
    return 'Yesterday';
  }

  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dateTime.month - 1]} ${dateTime.day}';
}

(IconData, List<Color>) _sessionArtwork({
  required int index,
  required bool isPlanner,
}) {
  const plannerArt = <(IconData, List<Color>)>[
    (
      Icons.self_improvement_rounded,
      <Color>[Color(0xFF7D1F00), Color(0xFFE87231)],
    ),
    (
      Icons.fitness_center_rounded,
      <Color>[Color(0xFF4E2A1A), Color(0xFFAE5D2F)],
    ),
    (Icons.bolt_rounded, <Color>[Color(0xFF2D2A29), Color(0xFF9F4A16)]),
    (Icons.spa_rounded, <Color>[Color(0xFF6D5947), Color(0xFFC08A5C)]),
  ];
  const generalArt = <(IconData, List<Color>)>[
    (Icons.chat_bubble_rounded, <Color>[Color(0xFF6F4E37), Color(0xFFDBA97E)]),
    (
      Icons.psychology_alt_rounded,
      <Color>[Color(0xFF3E534D), Color(0xFF8FB0A2)],
    ),
    (Icons.auto_awesome_rounded, <Color>[Color(0xFF855B36), Color(0xFFD3A77B)]),
    (Icons.wb_twilight_rounded, <Color>[Color(0xFF5A4238), Color(0xFFA5735B)]),
  ];
  final options = isPlanner ? plannerArt : generalArt;
  return options[index % options.length];
}
