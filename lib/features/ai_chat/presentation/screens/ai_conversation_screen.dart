import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _consumePendingPrompt(),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          'GymUnity AI',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.limeGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Online • Elite Performance Coach',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => showAppFeedback(
                      context,
                      'Voice and calls will be enabled after media features are connected.',
                    ),
                    child: const Icon(
                      Icons.phone_outlined,
                      color: AppColors.textDark,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => showAppFeedback(
                      context,
                      'More AI conversation actions will appear here soon.',
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      color: AppColors.textDark,
                      size: 24,
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
                            'Welcome back! Ask me for a workout plan, nutrition tips, or progress analysis.',
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
                            '• • •  ',
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
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SuggestionChip(
                    label: 'Show technique video',
                    onTap: () => _handleSuggestion(
                      'Show technique cues for the workout I am doing right now.',
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SuggestionChip(
                    label: 'Log equipment weight',
                    onTap: () => _handleSuggestion(
                      'Help me log the equipment weight for my next exercise.',
                    ),
                  ),
                  const SizedBox(width: 10),
                  _SuggestionChip(
                    label: 'Add to plan',
                    onTap: () => _handleSuggestion(
                      'Add this recommendation to my training plan.',
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
                  GestureDetector(
                    onTap: () => showAppFeedback(
                      context,
                      'Attachments will be enabled after media upload support is connected.',
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.border,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onSubmitted: (_) => _sendMessage(),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask GymUnity AI...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 15,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => showAppFeedback(
                      context,
                      'Voice input will be enabled after audio capture is connected.',
                    ),
                    child: const Icon(
                      Icons.mic_none,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: controllerState.isSending ? null : _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: AppColors.white,
                        size: 20,
                      ),
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

  Future<void> _consumePendingPrompt() async {
    if (_consumedPendingPrompt) return;
    final pending = ref.read(pendingChatPromptProvider);
    if (pending == null || pending.trim().isEmpty) return;

    _consumedPendingPrompt = true;
    ref.read(pendingChatPromptProvider.notifier).state = null;
    _messageController.text = pending.trim();
    await _sendMessage();
  }

  Future<void> _handleSuggestion(String suggestion) async {
    _messageController.text = suggestion;
    await _sendMessage();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final controller = ref.read(chatControllerProvider.notifier);
    final existing = ref.read(activeChatSessionIdProvider) ?? widget.sessionId;

    try {
      final sessionId = await controller.createSessionIfNeeded(existing);
      ref.read(activeChatSessionIdProvider.notifier).state = sessionId;
      _messageController.clear();

      final sent = await controller.sendMessage(
        sessionId: sessionId,
        message: text,
      );
      if (!mounted) return;

      if (!sent) {
        final error =
            ref.read(chatControllerProvider).errorMessage ??
            'Unable to send your message right now.';
        showAppFeedback(context, error);
        return;
      }

      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      showAppFeedback(
        context,
        'AI chat needs a signed-in user and a working backend connection before it can send messages.',
      );
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _buildMessage(ChatMessageEntity message) {
    final isUser = message.sender == 'user';
    final timestamp = TimeOfDay.fromDateTime(message.createdAt).format(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            isUser ? 'You • $timestamp' : 'GymUnity AI • $timestamp',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE0E0E0),
                  child: Text(
                    'AI',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.orange : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: isUser ? AppColors.white : AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.orange.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.textDark,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
