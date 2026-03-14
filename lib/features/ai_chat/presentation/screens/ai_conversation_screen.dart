import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../monetization/presentation/providers/monetization_providers.dart';
import '../../../planner/domain/entities/planner_entities.dart';
import '../../../planner/presentation/providers/planner_providers.dart';
import '../../../planner/presentation/route_args.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_session_entity.dart';
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
  final _composerFocusNode = FocusNode();
  bool _consumedPendingPrompt = false;
  String? _lastScrollSignature;

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
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gateAsync = ref.watch(aiPremiumGateProvider);

    return gateAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF130F0B),
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: const Color(0xFF130F0B),
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
    final session = ref.watch(chatSessionProvider(activeSessionId));
    final isPlanner = session?.isPlanner ?? false;

    final messages = activeSessionId == null
        ? const <ChatMessageEntity>[]
        : (ref.watch(chatMessagesProvider(activeSessionId)).valueOrNull ??
              const <ChatMessageEntity>[]);
    final draftAsync = activeSessionId != null && isPlanner
        ? ref.watch(latestPlannerDraftProvider(activeSessionId))
        : const AsyncValue<PlannerDraftEntity?>.data(null);
    final draft = draftAsync.valueOrNull;
    final scrollSignature = [
      activeSessionId ?? 'new',
      messages.length,
      controllerState.isSending,
      controllerState.isRegenerating,
      draft?.id ?? 'no-draft',
      draft?.updatedAt.toIso8601String() ?? 'no-draft-update',
    ].join('|');
    if (_lastScrollSignature != scrollSignature) {
      _lastScrollSignature = scrollSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleScrollToBottom());
    }

    return Scaffold(
      backgroundColor: const Color(0xFF130F0B),
      body: SafeArea(
        child: Column(
          children: [
            _ConversationHeader(
              title: isPlanner ? 'AI Plan Builder' : 'GymUnity AI',
              subtitle: isPlanner
                  ? 'Guided member planning session'
                  : 'General AI conversation',
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                children: [
                  if (controllerState.errorMessage != null &&
                      controllerState.errorMessage!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PlannerBanner(
                        title: 'AI message failed',
                        description: controllerState.errorMessage!,
                        accent: AppColors.orange,
                      ),
                    ),
                  if (isPlanner)
                    draftAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (error, stackTrace) => const SizedBox.shrink(),
                      data: (draft) => draft == null
                          ? _PlannerBanner(
                              title: 'Planner mode is active',
                              description:
                                  'Tell GymUnity your goal, schedule, experience level, limitations, and available equipment. If the planner flags missing details, tap a chip to prefill your reply.',
                              accent: AppColors.orange,
                            )
                          : _DraftStatusCard(
                              draft: draft,
                              onReview: draft.plan == null
                                  ? () => _primeMissingFieldReply(
                                      draft.missingFields,
                                    )
                                  : () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.aiGeneratedPlan,
                                      arguments: AiGeneratedPlanArgs(
                                        sessionId: activeSessionId!,
                                        draftId: draft.id,
                                      ),
                                    ),
                              onMissingFieldTap: (field) =>
                                  _primeSingleFieldReply(field),
                              onRegenerate: controllerState.isRegenerating
                                  ? null
                                  : () => _regeneratePlan(
                                      context,
                                      sessionId: activeSessionId!,
                                      draftId: draft.id,
                                    ),
                            ),
                    ),
                  if (messages.isEmpty)
                    _buildMessage(
                      ChatMessageEntity(
                        id: 'seed',
                        sessionId: activeSessionId ?? 'seed',
                        sender: 'assistant',
                        content: isPlanner
                            ? 'Let’s build a plan that fits your week. Tell me your main goal first, then I’ll ask only for the details that still matter.'
                            : 'Ask for practical fitness guidance, recovery tips, nutrition support, or a training idea.',
                        createdAt: DateTime.now(),
                      ),
                    ),
                  ...messages.map(_buildMessage),
                  if (controllerState.isSending ||
                      controllerState.isRegenerating)
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
                            controllerState.isRegenerating
                                ? 'AI IS REVISING THE PLAN'
                                : 'AI IS THINKING',
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
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF18120D),
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _composerFocusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(session: session),
                      style: GoogleFonts.inter(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: isPlanner
                            ? 'Answer the planner or ask for changes'
                            : 'Ask GymUnity AI',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF100C09),
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
                      onPressed: controllerState.isSending
                          ? null
                          : () => _handleSend(session: session),
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
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: isUser ? AppColors.orange : AppColors.cardDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.55,
                color: isUser ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            if (message.missingFields.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: message.missingFields
                    .map(
                      (field) => _FieldChip(
                        label: field.replaceAll('_', ' '),
                        onTap: isUser ? null : () => _primeSingleFieldReply(field),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleSend({ChatSessionEntity? session}) async {
    final rawMessage = _messageController.text.trim();
    if (rawMessage.isEmpty) {
      return;
    }

    final controller = ref.read(chatControllerProvider.notifier);
    String? sessionId =
        ref.read(activeChatSessionIdProvider) ?? widget.sessionId;

    try {
      sessionId = await controller.createSessionIfNeeded(
        sessionId,
        type: session?.type ?? ChatSessionType.general,
      );
      ref.read(activeChatSessionIdProvider.notifier).state = sessionId;
      _messageController.clear();
      final result = await controller.sendMessage(
        sessionId: sessionId,
        message: rawMessage,
      );
      ref.invalidate(chatSessionsProvider);
      ref.invalidate(chatMessagesProvider(sessionId));
      ref.invalidate(latestPlannerDraftProvider(sessionId));
      if (result?.draftId != null) {
        ref.invalidate(plannerDraftProvider(result!.draftId!));
      }
      _scheduleScrollToBottom();
      if (!mounted) {
        return;
      }
      if (result == null) {
        _restoreComposerText(rawMessage);
        showAppFeedback(
          context,
          ref.read(chatControllerProvider).errorMessage ??
              'GymUnity could not send this message right now.',
        );
      }
    } catch (_) {
      _restoreComposerText(rawMessage);
      if (!mounted) {
        return;
      }
      showAppFeedback(
        context,
        'GymUnity could not start this AI conversation right now.',
      );
    }
  }

  Future<void> _regeneratePlan(
    BuildContext context, {
    required String sessionId,
    required String draftId,
  }) async {
    final result = await ref
        .read(chatControllerProvider.notifier)
        .regeneratePlan(sessionId: sessionId, draftId: draftId);
    ref.invalidate(chatSessionsProvider);
    ref.invalidate(chatMessagesProvider(sessionId));
    ref.invalidate(latestPlannerDraftProvider(sessionId));
    ref.invalidate(plannerDraftProvider(draftId));
    _scheduleScrollToBottom();
    if (!context.mounted) {
      return;
    }
    if (result == null) {
      showAppFeedback(
        context,
        ref.read(chatControllerProvider).errorMessage ??
            'GymUnity could not refresh the plan right now.',
      );
      return;
    }
    showAppFeedback(context, 'The AI plan draft has been updated.');
  }

  void _restoreComposerText(String message) {
    _messageController
      ..text = message
      ..selection = TextSelection.collapsed(offset: message.length);
    _composerFocusNode.requestFocus();
  }

  void _primeSingleFieldReply(String field) {
    _appendComposerTemplate(_templateForMissingField(field));
  }

  void _primeMissingFieldReply(List<String> missingFields) {
    if (missingFields.isEmpty) {
      _composerFocusNode.requestFocus();
      return;
    }
    final template = missingFields
        .map(_templateForMissingField)
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
    _appendComposerTemplate(template);
  }

  void _appendComposerTemplate(String template) {
    if (template.trim().isEmpty) {
      _composerFocusNode.requestFocus();
      return;
    }
    final existing = _messageController.text.trimRight();
    final nextValue = existing.isEmpty ? template : '$existing\n$template';
    _messageController
      ..text = nextValue
      ..selection = TextSelection.collapsed(offset: nextValue.length);
    _composerFocusNode.requestFocus();
  }

  String _templateForMissingField(String field) {
    switch (field) {
      case 'days_per_week':
        return 'Days per week: ';
      case 'session_minutes':
        return 'Session minutes: ';
      case 'equipment':
        return 'Equipment available: ';
      case 'goal':
        return 'Main goal: ';
      case 'experience_level':
        return 'Experience level: ';
      case 'limitations':
        return 'Injuries or limitations: ';
      default:
        return '${field.replaceAll('_', ' ')}: ';
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
    final sessionId = ref.read(activeChatSessionIdProvider) ?? widget.sessionId;
    unawaited(_handleSend(session: ref.read(chatSessionProvider(sessionId))));
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    final target = _scrollController.position.maxScrollExtent;
    if ((_scrollController.offset - target).abs() < 1) {
      return;
    }
    _scrollController.jumpTo(target);
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scrollToBottom();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scrollToBottom();
      });
    });
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.screenPadding,
        vertical: 14,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.orange),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerBanner extends StatelessWidget {
  const _PlannerBanner({
    required this.title,
    required this.description,
    required this.accent,
  });

  final String title;
  final String description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftStatusCard extends StatelessWidget {
  const _DraftStatusCard({
    required this.draft,
    this.onReview,
    this.onMissingFieldTap,
    this.onRegenerate,
  });

  final PlannerDraftEntity draft;
  final VoidCallback? onReview;
  final ValueChanged<String>? onMissingFieldTap;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final isReady =
        draft.plan != null &&
        (draft.status == 'plan_ready' || draft.status == 'plan_updated');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: (isReady ? AppColors.limeGreen : AppColors.orange).withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isReady
                      ? 'Plan is ready for review'
                      : 'Planner still needs input',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusChip(
                label: draft.status.replaceAll('_', ' '),
                color: isReady ? AppColors.limeGreen : AppColors.orange,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            draft.assistantMessage,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (draft.missingFields.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Tap a field to prefill your reply.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: draft.missingFields
                  .map(
                    (field) => _FieldChip(
                      label: field.replaceAll('_', ' '),
                      onTap: onMissingFieldTap == null
                          ? null
                          : () => onMissingFieldTap!(field),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRegenerate,
                  child: const Text('Regenerate'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReady
                        ? AppColors.limeGreen
                        : AppColors.orange,
                    foregroundColor: AppColors.white,
                  ),
                  child: Text(isReady ? 'Review plan' : 'Answer details'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: onTap == null
                ? Colors.black.withValues(alpha: 0.15)
                : AppColors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            border: onTap == null
                ? null
                : Border.all(color: AppColors.orange.withValues(alpha: 0.28)),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: onTap == null ? FontWeight.w400 : FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedConversationScreen extends StatelessWidget {
  const _LockedConversationScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF130F0B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 42, color: AppColors.orange),
              const SizedBox(height: 16),
              Text(
                'AI Premium required',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
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
                child: const Text('View plans'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.subscriptionManagement,
                ),
                child: const Text('Subscription status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
