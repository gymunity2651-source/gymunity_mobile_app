import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/chat_session_entity.dart';
import '../providers/chat_controller.dart';
import '../providers/chat_providers.dart';

class AiChatHomeScreen extends ConsumerWidget {
  const AiChatHomeScreen({super.key});

  static const _fallbackChats = [
    {
      'title': 'High protein vegan meal plan',
      'time': 'Yesterday',
      'messages': '12 messages',
      'icon': Icons.chat_bubble,
      'color': AppColors.orange,
    },
    {
      'title': 'Leg day hypertrophy routine',
      'time': '2 days ago',
      'messages': '8 messages',
      'icon': Icons.fitness_center,
      'color': AppColors.orange,
    },
    {
      'title': 'Quick 15-min HIIT cardio',
      'time': 'Monday',
      'messages': '4 messages',
      'icon': Icons.bolt,
      'color': Colors.amber,
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatControllerProvider);
    final sessions =
        ref.watch(chatSessionsProvider).valueOrNull ??
        const <ChatSessionEntity>[];
    final hasSessions = sessions.isNotEmpty;

    Future<void> openConversation({
      String? sessionId,
      String? seedPrompt,
    }) async {
      if (seedPrompt != null && seedPrompt.trim().isNotEmpty) {
        ref.read(pendingChatPromptProvider.notifier).state = seedPrompt.trim();
      }
      if (sessionId != null && sessionId.isNotEmpty) {
        ref.read(activeChatSessionIdProvider.notifier).state = sessionId;
      } else {
        ref.read(activeChatSessionIdProvider.notifier).state = null;
      }
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
        if (!context.mounted) return;
        await openConversation(sessionId: sessionId);
      } catch (error) {
        if (!context.mounted) return;
        showAppFeedback(
          context,
          'Unable to start a new AI chat until authentication and backend setup are available.',
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
                    Icons.menu,
                    color: AppColors.textPrimary,
                    size: 26,
                  ),
                  const Spacer(),
                  Text(
                    'GymUnity AI Assistant',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.orange,
                    child: const Icon(
                      Icons.person,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'How can I help you\ntoday?',
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _QuickChip(
                          icon: Icons.auto_awesome,
                          label: 'Build a workout plan',
                          onTap: () => openConversation(
                            seedPrompt:
                                'Build a workout plan for me based on my current fitness level.',
                          ),
                        ),
                        const SizedBox(width: 12),
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
                    const SizedBox(height: 32),
                    Text(
                      'Recent chats',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1F14),
                        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: List.generate(
                          hasSessions ? sessions.length : _fallbackChats.length,
                          (index) {
                            final session = hasSessions
                                ? sessions[index]
                                : null;
                            final fallback = hasSessions
                                ? null
                                : _fallbackChats[index];
                            final title = hasSessions
                                ? (session!.title.isEmpty
                                      ? 'New chat'
                                      : session.title)
                                : fallback!['title'] as String;
                            final subtitle = hasSessions
                                ? _formatSessionTime(session!.updatedAt)
                                : '${fallback!['time']} • ${fallback['messages']}';
                            final icon = hasSessions
                                ? Icons.chat_bubble
                                : fallback!['icon'] as IconData;
                            final iconColor = hasSessions
                                ? AppColors.orange
                                : fallback!['color'] as Color;

                            return Column(
                              children: [
                                ListTile(
                                  leading: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      icon,
                                      color: iconColor,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    subtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textMuted,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  onTap: () {
                                    openConversation(
                                      sessionId: session?.id,
                                      seedPrompt: session == null
                                          ? title
                                          : null,
                                    );
                                  },
                                ),
                                if (index <
                                    (hasSessions
                                            ? sessions.length
                                            : _fallbackChats.length) -
                                        1)
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
                          },
                        ),
                      ),
                    ),
                  ],
                ),
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

  String _formatSessionTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inHours < 1) return 'Just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1F14),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.orange, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
