import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/ai_branding.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/theme/atelier_theme.dart';
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
  bool _isSubmittingMessage = false;
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

    return Theme(
      data: AtelierTheme.light,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AtelierColors.surfaceContainerLowest,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: gateAsync.when(
          loading: () => const Scaffold(
            backgroundColor: AtelierColors.surface,
            body: _EditorialStateView(
              title: 'Opening TAIYO Atelier',
              description: 'Preparing your guided wellness conversation.',
              loading: true,
            ),
          ),
          error: (error, stackTrace) => Scaffold(
            backgroundColor: AtelierColors.surface,
            body: _EditorialStateView(
              title: 'Access Needs A Refresh',
              description:
                  'GymUnity could not verify ${AiBranding.premiumName} access right now.',
              primaryLabel: 'Retry',
              onPrimaryTap: () => ref
                  .read(currentSubscriptionSummaryProvider.notifier)
                  .refreshFromBackend(),
            ),
          ),
          data: (gate) {
            if (gate.requiresBilling && !gate.hasAccess) {
              return _LockedConversationScreen(message: gate.message);
            }
            return _buildUnlockedConversation(context);
          },
        ),
      ),
    );
  }

  Widget _buildUnlockedConversation(BuildContext context) {
    final controllerState = ref.watch(chatControllerProvider);
    final isSendingMessage = _isSubmittingMessage || controllerState.isSending;
    final isComposerBusy = isSendingMessage || controllerState.isRegenerating;
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
    final composerSuggestions = _resolveComposerSuggestions(
      messages: messages,
      draft: draft,
      isPlanner: isPlanner,
    );
    final scrollSignature = [
      activeSessionId ?? 'new',
      messages.length,
      isSendingMessage,
      controllerState.isRegenerating,
      draft?.id ?? 'no-draft',
      draft?.updatedAt.toIso8601String() ?? 'no-draft-update',
    ].join('|');
    if (_lastScrollSignature != scrollSignature) {
      _lastScrollSignature = scrollSignature;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scheduleScrollToBottom(),
      );
    }

    final timeline = <Widget>[
      _ConversationHero(isPlanner: isPlanner),
      if (controllerState.errorMessage != null &&
          controllerState.errorMessage!.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _ConversationNoticeCard(
            eyebrow: 'TAIYO UPDATE',
            title: 'Message delivery paused',
            description: controllerState.errorMessage!,
          ),
        ),
      if (messages.isEmpty)
        _buildMessage(
          ChatMessageEntity(
            id: 'seed',
            sessionId: activeSessionId ?? 'seed',
            sender: 'assistant',
            content: isPlanner
                ? 'Welcome to your bespoke plan builder. I have analyzed your recent biometric trends and activity history. To start, how would you like to prioritize your energy levels this coming week?'
                : 'Ask TAIYO for practical fitness guidance, recovery tips, nutrition support, or a training idea crafted for your current rhythm.',
            createdAt: DateTime.now(),
          ),
          showAssistantLabel: true,
        )
      else
        for (var index = 0; index < messages.length; index++)
          _buildMessage(
            messages[index],
            showAssistantLabel:
                messages[index].sender != 'user' &&
                (index == 0 || messages[index - 1].sender == 'user'),
          ),
      draftAsync.when(
        loading: () => isPlanner
            ? const Padding(
                padding: EdgeInsets.only(top: 12, bottom: 24),
                child: _ThinkingRibbon(label: 'TAIYO is shaping your plan'),
              )
            : const SizedBox.shrink(),
        error: (error, stackTrace) => const SizedBox.shrink(),
        data: (draft) {
          if (!isPlanner || draft == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 28),
            child: _DraftStatusCard(
              draft: draft,
              onReview: draft.plan == null
                  ? () => _primeMissingFieldReply(draft.missingFields)
                  : () => Navigator.pushNamed(
                      context,
                      AppRoutes.aiGeneratedPlan,
                      arguments: AiGeneratedPlanArgs(
                        sessionId: activeSessionId!,
                        draftId: draft.id,
                      ),
                    ),
              onMissingFieldTap: _primeSingleFieldReply,
              onRegenerate: controllerState.isRegenerating
                  ? null
                  : () => _regeneratePlan(
                      context,
                      sessionId: activeSessionId!,
                      draftId: draft.id,
                    ),
            ),
          );
        },
      ),
      if (isComposerBusy)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _ThinkingRibbon(
            label: controllerState.isRegenerating
                ? 'TAIYO is revising the structure'
                : 'TAIYO is sculpting the next response',
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: AtelierColors.surface,
      body: Stack(
        children: [
          const Positioned.fill(child: _EditorialBackdrop()),
          SafeArea(
            child: Column(
              children: [
                _ConversationTopBar(
                  onBack: Navigator.canPop(context)
                      ? () => Navigator.maybePop(context)
                      : null,
                  onMenu: () => _openConversationOptions(
                    context,
                    sessionId: activeSessionId,
                    hasDraft: draft?.plan != null,
                    draftId: draft?.id,
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.screenPadding,
                      0,
                      AppSizes.screenPadding,
                      24,
                    ),
                    children: timeline,
                  ),
                ),
                _ComposerDock(
                  controller: _messageController,
                  focusNode: _composerFocusNode,
                  busy: isComposerBusy,
                  hintText: isPlanner
                      ? 'Tell TAIYO about your goals...'
                      : 'Ask TAIYO anything about training, recovery, or nutrition...',
                  onSend: () => _handleSend(session: session),
                  onAdd: () {
                    if (isPlanner && draft?.missingFields.isNotEmpty == true) {
                      _primeMissingFieldReply(draft!.missingFields);
                      return;
                    }
                    _composerFocusNode.requestFocus();
                  },
                  suggestions: composerSuggestions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(
    ChatMessageEntity message, {
    required bool showAssistantLabel,
  }) {
    final isUser = message.sender == 'user';
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Padding(
      padding: EdgeInsets.only(bottom: isUser ? 18 : 26),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isUser && showAssistantLabel) ...[
            const _AssistantLabel(),
            const SizedBox(height: 14),
          ],
          Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              decoration: BoxDecoration(
                color: isUser ? null : AtelierColors.surfaceContainerLowest,
                gradient: isUser
                    ? const LinearGradient(
                        colors: [AtelierColors.primary, Color(0xFFD76830)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(30),
                  topRight: const Radius.circular(30),
                  bottomLeft: Radius.circular(isUser ? 30 : 10),
                  bottomRight: Radius.circular(isUser ? 10 : 30),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AtelierColors.navShadow,
                    blurRadius: 32,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                  color: isUser
                      ? AtelierColors.onPrimary
                      : AtelierColors.onSurface,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 8,
              left: isUser ? 0 : 6,
              right: isUser ? 6 : 0,
            ),
            child: Text(
              _formatConversationTimestamp(message.createdAt),
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AtelierColors.textMuted,
              ),
            ),
          ),
          if (!isUser && message.personalizationUsed.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.personalizationUsed
                  .take(4)
                  .map((item) => _SoftTag(label: item))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleSend({ChatSessionEntity? session}) async {
    final rawMessage = _messageController.text.trim();
    final controllerState = ref.read(chatControllerProvider);
    if (rawMessage.isEmpty ||
        _isSubmittingMessage ||
        controllerState.isSending ||
        controllerState.isRegenerating) {
      return;
    }

    final controller = ref.read(chatControllerProvider.notifier);
    String? sessionId =
        ref.read(activeChatSessionIdProvider) ?? widget.sessionId;
    setState(() {
      _isSubmittingMessage = true;
    });
    _messageController.clear();
    _scheduleScrollToBottom();

    try {
      sessionId = await controller.createSessionIfNeeded(
        sessionId,
        type: session?.type ?? ChatSessionType.general,
      );
      ref.read(activeChatSessionIdProvider.notifier).state = sessionId;
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
        'GymUnity could not start this TAIYO conversation right now.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingMessage = false;
        });
      }
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
    showAppFeedback(context, 'The TAIYO plan draft has been updated.');
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

  void _applySuggestedReply(String reply) {
    _appendComposerTemplate(reply.trim());
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

  void _openConversationOptions(
    BuildContext context, {
    required String? sessionId,
    required bool hasDraft,
    required String? draftId,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AtelierColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AtelierColors.surfaceDim,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'TAIYO Atelier',
                  style: GoogleFonts.notoSerif(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AtelierColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Session controls and access options for your current conversation.',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: AtelierColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                if (hasDraft && sessionId != null && draftId != null)
                  _SheetAction(
                    icon: Icons.article_outlined,
                    title: 'Review current plan',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Navigator.pushNamed(
                        context,
                        AppRoutes.aiGeneratedPlan,
                        arguments: AiGeneratedPlanArgs(
                          sessionId: sessionId,
                          draftId: draftId,
                        ),
                      );
                    },
                  ),
                _SheetAction(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Subscription status',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.pushNamed(
                      context,
                      AppRoutes.subscriptionManagement,
                    );
                  },
                ),
                _SheetAction(
                  icon: Icons.arrow_back_rounded,
                  title: 'Back to AI home',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.maybePop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_ComposerSuggestionAction> _resolveComposerSuggestions({
    required List<ChatMessageEntity> messages,
    required PlannerDraftEntity? draft,
    required bool isPlanner,
  }) {
    final suggestions = <_ComposerSuggestionAction>[];
    final seen = <String>{};
    final latestInteractive = _latestInteractiveAssistantMessage(messages);

    void addSuggestion(String label, VoidCallback onTap) {
      final normalized = label.trim().toLowerCase();
      if (normalized.isEmpty || seen.contains(normalized)) {
        return;
      }
      seen.add(normalized);
      suggestions.add(_ComposerSuggestionAction(label: label, onTap: onTap));
    }

    if (latestInteractive != null) {
      for (final reply in latestInteractive.suggestedReplies.take(4)) {
        addSuggestion(reply, () => _applySuggestedReply(reply));
      }
      for (final field in latestInteractive.missingFields.take(4)) {
        addSuggestion(
          _fieldPromptLabel(field),
          () => _primeSingleFieldReply(field),
        );
      }
    }

    if (draft != null) {
      for (final field in draft.missingFields.take(4)) {
        addSuggestion(
          _fieldPromptLabel(field),
          () => _primeSingleFieldReply(field),
        );
      }
    }

    if (suggestions.isEmpty && isPlanner) {
      const defaults = <String>[
        "I'd like more mobility",
        'Make it 5 days',
        'Suggest nutrition support',
      ];
      for (final reply in defaults) {
        addSuggestion(reply, () => _applySuggestedReply(reply));
      }
    }

    if (suggestions.isEmpty && !isPlanner) {
      const defaults = <String>[
        'Review my recovery',
        'Build a quick workout',
        'Lower the intensity',
      ];
      for (final reply in defaults) {
        addSuggestion(reply, () => _applySuggestedReply(reply));
      }
    }

    return suggestions.take(4).toList(growable: false);
  }

  ChatMessageEntity? _latestInteractiveAssistantMessage(
    List<ChatMessageEntity> messages,
  ) {
    for (final message in messages.reversed) {
      if (message.sender == 'user') {
        continue;
      }
      if (message.suggestedReplies.isNotEmpty ||
          message.missingFields.isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  String _fieldPromptLabel(String field) {
    switch (field) {
      case 'days_per_week':
        return 'Adjust training days';
      case 'session_minutes':
        return 'Refine session length';
      case 'equipment':
        return 'List available equipment';
      case 'goal':
        return 'Set my main goal';
      case 'experience_level':
        return 'Share experience level';
      case 'limitations':
        return 'Mention limitations';
      default:
        return field.replaceAll('_', ' ');
    }
  }

  String _formatConversationTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inSeconds < 90) {
      return 'JUST NOW';
    }
    if (difference.inMinutes < 60) {
      final value = difference.inMinutes;
      return '$value ${value == 1 ? 'MIN' : 'MINS'} AGO';
    }
    if (difference.inHours < 24) {
      final value = difference.inHours;
      return '$value ${value == 1 ? 'HR' : 'HRS'} AGO';
    }
    if (difference.inDays < 7) {
      final value = difference.inDays;
      return '$value ${value == 1 ? 'DAY' : 'DAYS'} AGO';
    }
    const months = <String>[
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}';
  }
}

class _ConversationTopBar extends StatelessWidget {
  const _ConversationTopBar({required this.onMenu, this.onBack});

  final VoidCallback onMenu;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AtelierColors.onSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                onBack == null
                    ? Icons.auto_awesome_rounded
                    : Icons.arrow_back_rounded,
                color: AtelierColors.onPrimary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'ATELIER',
              style: GoogleFonts.notoSerif(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.4,
                color: AtelierColors.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: onMenu,
            icon: const Icon(
              Icons.settings_rounded,
              color: AtelierColors.onSurfaceVariant,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationHero extends StatelessWidget {
  const _ConversationHero({required this.isPlanner});

  final bool isPlanner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 30, 0, 34),
      child: Column(
        children: [
          _EditorialPill(
            label: isPlanner ? 'PLANNER MODE ACTIVE' : 'TAIYO SESSION LIVE',
          ),
          const SizedBox(height: 28),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.notoSerif(
                fontSize: 30,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: AtelierColors.onSurface,
              ),
              children: [
                TextSpan(
                  text: isPlanner ? 'TAIYO ' : '${AiBranding.assistantName} ',
                ),
                TextSpan(
                  text: isPlanner ? 'Plan Builder' : 'Atelier',
                  style: GoogleFonts.notoSerif(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: AtelierColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              isPlanner
                  ? 'Refining your path to vitality with AI-guided precision.\nLet us sculpt your perfect wellness routine.'
                  : 'A composed conversation for training clarity, nutrition support, and recovery decisions that fit your week.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 15,
                height: 1.75,
                fontWeight: FontWeight.w500,
                color: AtelierColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantLabel extends StatelessWidget {
  const _AssistantLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AtelierColors.primary, AtelierColors.primaryContainer],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AtelierColors.onPrimary,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'TAIYO AI',
          style: GoogleFonts.notoSerif(
            fontSize: 18,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            color: AtelierColors.primary,
          ),
        ),
      ],
    );
  }
}

class _ConversationNoticeCard extends StatelessWidget {
  const _ConversationNoticeCard({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.manrope(
              fontSize: 14,
              height: 1.65,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurfaceVariant,
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
    final title = draft.plan?.title.trim().isNotEmpty == true
        ? draft.plan!.title
        : (isReady ? 'Plan Ready For Review' : 'Shape Your Direction');
    final description = draft.plan?.summary.trim().isNotEmpty == true
        ? draft.plan!.summary
        : draft.assistantMessage;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: AtelierColors.navShadow,
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AtelierColors.primaryContainer.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReady
                  ? Icons.psychology_alt_rounded
                  : Icons.auto_awesome_rounded,
              color: AtelierColors.primaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerif(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              height: 1.7,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
          if (draft.missingFields.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
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
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _GhostButton(
                  label: isReady ? 'Adjust Intensity' : 'Refine Inputs',
                  onTap: onRegenerate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PrimaryEditorialButton(
                  label: isReady ? 'Proceed with Plan' : 'Continue Builder',
                  onTap: onReview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerDock extends StatelessWidget {
  const _ComposerDock({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.hintText,
    required this.onSend,
    required this.onAdd,
    required this.suggestions,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final String hintText;
  final VoidCallback onSend;
  final VoidCallback onAdd;
  final List<_ComposerSuggestionAction> suggestions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AtelierColors.glass,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AtelierColors.ghostBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: AtelierColors.navShadow,
                      blurRadius: 40,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: busy ? null : onAdd,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AtelierColors.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: AtelierColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: AtelierColors.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: GoogleFonts.manrope(
                            fontSize: 15,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            color: AtelierColors.textMuted,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AtelierColors.primary,
                            AtelierColors.primaryContainer,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: AtelierColors.navShadow,
                            blurRadius: 26,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: busy ? null : onSend,
                        icon: Icon(
                          Icons.north_rounded,
                          color: busy
                              ? AtelierColors.onPrimary.withValues(alpha: 0.55)
                              : AtelierColors.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: suggestions
                      .map(
                        (suggestion) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _SuggestionChip(
                            label: suggestion.label,
                            onTap: suggestion.onTap,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AtelierColors.onSurface,
        side: BorderSide(
          color: AtelierColors.outlineVariant.withValues(alpha: 0.4),
        ),
        backgroundColor: AtelierColors.surfaceContainerLowest,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AtelierColors.onSurface,
        ),
      ),
    );
  }
}

class _PrimaryEditorialButton extends StatelessWidget {
  const _PrimaryEditorialButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AtelierColors.primary, AtelierColors.primaryContainer],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(9999),
        boxShadow: const [
          BoxShadow(
            color: AtelierColors.navShadow,
            blurRadius: 34,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          foregroundColor: AtelierColors.onPrimary,
          surfaceTintColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AtelierColors.onPrimary,
          ),
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
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AtelierColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: AtelierColors.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AtelierColors.onSurface,
            ),
          ),
        ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: AtelierColors.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            '"$label"',
            style: GoogleFonts.notoSerif(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftTag extends StatelessWidget {
  const _SoftTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AtelierColors.surfaceContainer,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AtelierColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ThinkingRibbon extends StatelessWidget {
  const _ThinkingRibbon({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AtelierColors.primaryContainer,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AtelierColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AtelierColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AtelierColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AtelierColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AtelierColors.onSurface,
                    ),
                  ),
                ),
              ],
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
      backgroundColor: AtelierColors.surface,
      body: Stack(
        children: [
          const Positioned.fill(child: _EditorialBackdrop()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(26, 32, 26, 26),
                  decoration: BoxDecoration(
                    color: AtelierColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                        color: AtelierColors.navShadow,
                        blurRadius: 40,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: AtelierColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: AtelierColors.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${AiBranding.premiumName} required',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSerif(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: AtelierColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          height: 1.65,
                          fontWeight: FontWeight.w500,
                          color: AtelierColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _PrimaryEditorialButton(
                        label: 'View plans',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.aiPremiumPaywall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GhostButton(
                        label: 'Subscription status',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.subscriptionManagement,
                        ),
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

class _EditorialStateView extends StatelessWidget {
  const _EditorialStateView({
    required this.title,
    required this.description,
    this.primaryLabel,
    this.onPrimaryTap,
    this.loading = false,
  });

  final String title;
  final String description;
  final String? primaryLabel;
  final VoidCallback? onPrimaryTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _EditorialBackdrop()),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.screenPadding),
              child: Container(
                padding: const EdgeInsets.fromLTRB(26, 32, 26, 26),
                decoration: BoxDecoration(
                  color: AtelierColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(
                      color: AtelierColors.navShadow,
                      blurRadius: 40,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: AtelierColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: loading
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AtelierColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_rounded,
                              color: AtelierColors.primary,
                              size: 30,
                            ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSerif(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: AtelierColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        height: 1.65,
                        fontWeight: FontWeight.w500,
                        color: AtelierColors.onSurfaceVariant,
                      ),
                    ),
                    if (!loading &&
                        primaryLabel != null &&
                        onPrimaryTap != null) ...[
                      const SizedBox(height: 22),
                      _PrimaryEditorialButton(
                        label: primaryLabel!,
                        onTap: onPrimaryTap,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditorialPill extends StatelessWidget {
  const _EditorialPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AtelierColors.primaryContainer.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: AtelierColors.primary,
        ),
      ),
    );
  }
}

class _EditorialBackdrop extends StatelessWidget {
  const _EditorialBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AtelierColors.surface),
        Positioned(
          top: -40,
          right: -30,
          child: _BlurBlob(
            width: 180,
            height: 180,
            colors: [
              AtelierColors.primaryContainer.withValues(alpha: 0.16),
              AtelierColors.transparent,
            ],
          ),
        ),
        Positioned(
          top: 120,
          left: -50,
          child: _BlurBlob(
            width: 150,
            height: 190,
            colors: [
              AtelierColors.surfaceContainer.withValues(alpha: 0.9),
              AtelierColors.transparent,
            ],
          ),
        ),
        Positioned(
          bottom: 120,
          right: -40,
          child: _BlurBlob(
            width: 170,
            height: 210,
            colors: [
              AtelierColors.primary.withValues(alpha: 0.09),
              AtelierColors.transparent,
            ],
          ),
        ),
      ],
    );
  }
}

class _BlurBlob extends StatelessWidget {
  const _BlurBlob({
    required this.width,
    required this.height,
    required this.colors,
  });

  final double width;
  final double height;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width),
          gradient: RadialGradient(
            colors: colors,
            center: Alignment.topLeft,
            radius: 0.9,
          ),
        ),
      ),
    );
  }
}

class _ComposerSuggestionAction {
  const _ComposerSuggestionAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}
