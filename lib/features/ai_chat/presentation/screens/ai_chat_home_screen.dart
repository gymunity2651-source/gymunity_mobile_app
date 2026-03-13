import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../monetization/presentation/providers/monetization_providers.dart';
import '../../../monetization/presentation/screens/ai_premium_paywall_screen.dart';
import '../../domain/entities/chat_session_entity.dart';
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
        body: Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
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

    Future<void> openConversation({
      String? sessionId,
      String? seedPrompt,
    }) async {
      if (seedPrompt != null && seedPrompt.trim().isNotEmpty) {
        ref.read(pendingChatPromptProvider.notifier).state = seedPrompt.trim();
      }
      ref.read(activeChatSessionIdProvider.notifier).state = sessionId;
      Navigator.pushNamed(
        context,
        AppRoutes.aiConversation,
        arguments: sessionId,
      );
    }

    Future<void> startFreshChat() async {
      try {
        final sessionId = await ref
            .read(chatControllerProvider.notifier)
            .createSessionIfNeeded(null);
        if (!context.mounted) {
          return;
        }
        await openConversation(sessionId: sessionId);
      } catch (_) {
        if (!context.mounted) {
          return;
        }
        showAppFeedback(
          context,
          'GymUnity could not start a new AI conversation right now.',
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A120B),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.screenPadding,
                vertical: AppSizes.lg,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: AppColors.textPrimary,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'GymUnity AI Premium',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                children: [
                  Text(
                    'Use GymUnity AI for verified premium prompts and stored conversations only.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuickChip(
                        icon: Icons.auto_awesome,
                        label: 'Build a workout plan',
                        onTap: () => openConversation(
                          seedPrompt:
                              'Build a workout plan for me based on my current fitness level.',
                        ),
                      ),
                      _QuickChip(
                        icon: Icons.restaurant,
                        label: 'Nutrition tips',
                        onTap: () => openConversation(
                          seedPrompt:
                              'Give me practical nutrition tips for my fitness goals.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Recent chats',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  sessionsAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: CircularProgressIndicator(
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                    error: (error, stackTrace) => _StateCard(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to load conversations',
                      description:
                          'GymUnity could not fetch AI sessions from the backend.',
                      actionLabel: 'Retry',
                      onTap: () => ref.refresh(chatSessionsProvider),
                    ),
                    data: (sessions) {
                      if (sessions.isEmpty) {
                        return _StateCard(
                          icon: Icons.chat_bubble_outline,
                          title: 'No conversations yet',
                          description:
                              'Start your first AI conversation and GymUnity will keep it here.',
                          actionLabel: 'Start chat',
                          onTap: startFreshChat,
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
                                  onTap: () =>
                                      openConversation(sessionId: session.id),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              child: Align(
                alignment: Alignment.centerRight,
                child: FloatingActionButton(
                  onPressed: chatState.isSending ? null : startFreshChat,
                  backgroundColor: const Color(0xFF2196F3),
                  child: const Icon(Icons.add, color: AppColors.white),
                ),
              ),
            ),
          ],
        ),
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
                fontWeight: FontWeight.w500,
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
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.chat_bubble_outline,
          color: AppColors.orange,
          size: 20,
        ),
      ),
      title: Text(
        session.title.isEmpty ? 'New chat' : session.title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        _formatSessionTime(session.updatedAt),
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
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
