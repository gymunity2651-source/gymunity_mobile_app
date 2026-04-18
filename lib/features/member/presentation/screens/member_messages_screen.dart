import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/coaching_engagement_entity.dart';
import '../providers/member_providers.dart';

class MemberMessagesScreen extends ConsumerWidget {
  const MemberMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(memberCoachingThreadsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.background,
      ),
      body: threadsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (threads) {
          if (threads.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                child: Text(
                  'Messages appear after a coaching checkout is paid and activated.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            itemCount: threads.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final thread = threads[index];
              return ListTile(
                tileColor: AppColors.cardDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                ),
                title: Text(
                  thread.coachName ?? 'Coach',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  thread.lastMessagePreview.isEmpty
                      ? thread.packageTitle ?? 'Coaching thread'
                      : thread.lastMessagePreview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.memberThread,
                  arguments: thread,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MemberThreadScreen extends ConsumerStatefulWidget {
  const MemberThreadScreen({super.key, required this.thread});

  final CoachingThreadEntity thread;

  @override
  ConsumerState<MemberThreadScreen> createState() => _MemberThreadScreenState();
}

class _MemberThreadScreenState extends ConsumerState<MemberThreadScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      memberCoachingMessagesProvider(widget.thread.id),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.thread.coachName ?? 'Coach'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.orange),
              ),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (messages) => ListView.builder(
                padding: const EdgeInsets.all(AppSizes.screenPadding),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMine = !message.isCoach && !message.isSystem;
                  return Align(
                    alignment: isMine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: message.isSystem
                            ? AppColors.fieldFill
                            : isMine
                            ? AppColors.orange.withValues(alpha: 0.16)
                            : AppColors.cardDark,
                        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      ),
                      child: Text(
                        message.content,
                        style: GoogleFonts.inter(color: AppColors.textPrimary),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Write an update or question',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      return;
    }
    _controller.clear();
    await ref
        .read(memberRepositoryProvider)
        .sendCoachingMessage(threadId: widget.thread.id, content: content);
    ref.invalidate(memberCoachingMessagesProvider(widget.thread.id));
    ref.invalidate(memberCoachingThreadsProvider);
  }
}
