import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_reveal.dart';
import '../../../member/presentation/widgets/member_profile_shortcut_button.dart';
import '../../../member/presentation/providers/member_providers.dart';
import '../../../monetization/presentation/providers/monetization_providers.dart';
import '../../../monetization/presentation/screens/ai_premium_paywall_screen.dart';
import '../../domain/entities/chat_session_entity.dart';
import '../ai_personalization.dart';
import '../providers/chat_controller.dart';
import '../providers/chat_providers.dart';

class AiChatHomeScreen extends ConsumerWidget {
  const AiChatHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gateAsync = ref.watch(aiPremiumGateProvider);

    return gateAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF1A120B),
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: const Color(0xFF1A120B),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GymUnity could not verify AI Premium access right now.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
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
    Duration revealDelay(int index) =>
        Duration(milliseconds: 40 + (index * 55));

    Future<void> openSession({
      required ChatSessionType type,
      String? sessionId,
      String? seedPrompt,
    }) async {
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
        showAppFeedback(
          context,
          'GymUnity could not open this AI session right now.',
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A120B),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppReveal(
              delay: revealDelay(0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.lg,
                  AppSizes.screenPadding,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AI Assistant',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const MemberProfileShortcutButton(),
                  ],
                ),
              ),
            ),
            AppReveal(
              delay: revealDelay(1),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  8,
                  AppSizes.screenPadding,
                  0,
                ),
                child: Text(
                  'Start a guided member plan or keep a general fitness conversation inside your GymUnity account.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                children: [
                  AppReveal(
                    delay: revealDelay(2),
                    child: _EntryCard(
                      icon: Icons.route_outlined,
                      title: 'Start AI plan',
                      description:
                          'Answer focused follow-up questions, review the generated plan, then activate daily tasks and reminders.',
                      accent: AppColors.orange,
                      buttonLabel: 'Open planner',
                      onTap: () => openSession(type: ChatSessionType.planner),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppReveal(
                    delay: revealDelay(3),
                    child: _EntryCard(
                      icon: Icons.chat_bubble_outline,
                      title: 'General AI conversation',
                      description:
                          'Use AI for practical fitness guidance, nutrition tips, and recovery questions without entering the planning flow.',
                      accent: AppColors.electricBlue,
                      buttonLabel: 'Open chat',
                      onTap: () => openSession(type: ChatSessionType.general),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppReveal(
                    delay: revealDelay(4),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: quickActions
                          .map(
                            (action) => _QuickChip(
                              icon: action.icon,
                              label: action.label,
                              onTap: () => openSession(
                                type: action.type,
                                seedPrompt: action.prompt,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppReveal(
                    delay: revealDelay(5),
                    child: Text(
                      'Recent sessions',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppReveal(
                    delay: revealDelay(6),
                    child: sessionsAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: CircularProgressIndicator(
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                      error: (error, stackTrace) => _StateCard(
                        icon: Icons.cloud_off_outlined,
                        title: 'Unable to load AI sessions',
                        description:
                            'GymUnity could not fetch your stored conversations from Supabase.',
                        actionLabel: 'Retry',
                        onTap: () => ref.refresh(chatSessionsProvider),
                      ),
                      data: (sessions) {
                        if (sessions.isEmpty) {
                          return _StateCard(
                            icon: Icons.auto_awesome_outlined,
                            title: 'No AI sessions yet',
                            description:
                                'Start a planner session or a general conversation and GymUnity will keep it here.',
                            actionLabel: 'Start planner',
                            onTap: () =>
                                openSession(type: ChatSessionType.planner),
                          );
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A1F14),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusLg,
                            ),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            children: List.generate(sessions.length, (index) {
                              final session = sessions[index];
                              return Column(
                                children: [
                                  _SessionTile(
                                    session: session,
                                    onTap: () => openSession(
                                      type: session.type,
                                      sessionId: session.id,
                                    ),
                                  ),
                                  if (index < sessions.length - 1)
                                    Divider(
                                      color: AppColors.border.withValues(
                                        alpha: 0.3,
                                      ),
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                ],
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: chatState.isSending
            ? null
            : () => openSession(type: ChatSessionType.planner),
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Plan'),
      ),
    );
  }
}

List<_QuickAction> _buildQuickActions(
  List<AiEntrySuggestion> personalizedSuggestions,
) {
  final actions = <_QuickAction>[
    ...personalizedSuggestions.map(_quickActionFromSuggestion),
    const _QuickAction(
      icon: Icons.fitness_center_outlined,
      label: 'Strength plan',
      type: ChatSessionType.planner,
      prompt:
          'I want a structured strength-focused plan. Ask me the key questions you need first.',
    ),
    const _QuickAction(
      icon: Icons.directions_run_outlined,
      label: 'Fat loss plan',
      type: ChatSessionType.planner,
      prompt:
          'I want a realistic fat loss plan. Ask me for the missing details before generating it.',
    ),
    const _QuickAction(
      icon: Icons.restaurant_outlined,
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
    icon: Icons.auto_awesome_outlined,
    label: suggestion.label,
    prompt: suggestion.prompt,
    type: isPlanner ? ChatSessionType.planner : ChatSessionType.general,
  );
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F14),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: AppColors.white,
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1F14),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.orange, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onTap});

  final ChatSessionEntity session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = session.isPlanner
        ? AppColors.orange
        : AppColors.electricBlue;
    final subtitle = session.isPlanner
        ? 'Planner - ${session.plannerStatus.replaceAll('_', ' ')}'
        : 'Conversation';

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          session.isPlanner ? Icons.route_outlined : Icons.chat_bubble_outline,
          color: accent,
          size: 20,
        ),
      ),
      title: Text(
        session.title.isEmpty ? 'New session' : session.title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            _formatSessionTime(session.updatedAt),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  static String _formatSessionTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F14),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.orange, size: 34),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
