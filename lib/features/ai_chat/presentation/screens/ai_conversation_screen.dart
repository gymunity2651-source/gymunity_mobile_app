import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../monetization/presentation/providers/monetization_providers.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../providers/chat_controller.dart';
import '../providers/chat_providers.dart';

class AiConversationScreen extends ConsumerStatefulWidget {
  const AiConversationScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  ConsumerState<AiConversationScreen> createState() =>
      _AiConversationScreenState();
}

class _AiConversationScreenState extends ConsumerState<AiConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _consumedPendingPrompt = false;

  @override
  void initState() {
    super.initState();
    if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeChatSessionIdProvider.notifier).state = widget.sessionId;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingPrompt());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gateAsync = ref.watch(aiPremiumGateProvider);

    return gateAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF5F0EB),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: const Color(0xFFF5F0EB),
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
          return _LockedConversationScreen(message: gate.message);
        }
        return _buildUnlockedConversation(context);
      },
    );
  }

  Widget _buildUnlockedConversation(BuildContext context) {
    final controllerState = ref.watch(chatControllerProvider);
    final activeSessionId =
        ref.watch(activeChatSessionIdProvider) ?? widget.sessionId;
    final messages = activeSessionId == null
        ? const <ChatMessageEntity>[]
        : (ref.watch(chatMessagesProvider(activeSessionId)).valueOrNull ??
              const <ChatMessageEntity>[]);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.screenPadding,
                vertical: 14,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF2A2A2A),
                      child: const Icon(
                        Icons.smart_toy,
                        color: AppColors.limeGreen,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GymUnity AI Premium',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'Verified premium conversation',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'TODAY',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ),
                  if (messages.isEmpty)
                    _buildMessage(
                      ChatMessageEntity(
                        id: 'seed',
                        sessionId: 'seed',
                        sender: 'assistant',
                        content:
                            'Welcome back. Ask for a workout structure, nutrition help, or an AI-guided plan.',
                        createdAt: DateTime.now(),
                      ),
                    ),
                  ...messages.map(_buildMessage),
                  if (controllerState.isSending)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Text(
                            '...  ',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            'AI IS THINKING',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: 'Ask GymUnity AI Premium',
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.orange,
                    child: IconButton(
                      onPressed: controllerState.isSending ? null : _handleSend,
                      icon: const Icon(Icons.send, color: AppColors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessageEntity message) {
    final isUser = message.sender == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser ? AppColors.orange : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        ),
        child: Text(
          message.content,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: isUser ? AppColors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    final rawMessage = _messageController.text.trim();
    if (rawMessage.isEmpty) {
      return;
    }

    final controller = ref.read(chatControllerProvider.notifier);
    String? sessionId =
        ref.read(activeChatSessionIdProvider) ?? widget.sessionId;

    try {
      sessionId = await controller.createSessionIfNeeded(sessionId);
      ref.read(activeChatSessionIdProvider.notifier).state = sessionId;
      _messageController.clear();
      final sent = await controller.sendMessage(
        sessionId: sessionId,
        message: rawMessage,
      );
      if (!sent && mounted) {
        showAppFeedback(
          context,
          ref.read(chatControllerProvider).errorMessage ??
              'GymUnity could not send this message right now.',
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppFeedback(
        context,
        'GymUnity could not start this AI conversation right now.',
      );
    }
  }

  void _consumePendingPrompt() {
    if (_consumedPendingPrompt) {
      return;
    }
    _consumedPendingPrompt = true;
    final prompt = ref.read(pendingChatPromptProvider);
    if (prompt == null || prompt.trim().isEmpty) {
      return;
    }
    ref.read(pendingChatPromptProvider.notifier).state = null;
    _messageController.text = prompt.trim();
    unawaited(_handleSend());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }
}

class _LockedConversationScreen extends StatelessWidget {
  const _LockedConversationScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 42,
                color: AppColors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'AI Premium required',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.aiPremiumPaywall),
                child: const Text('View Plans'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.subscriptionManagement,
                ),
                child: const Text('Subscription Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
