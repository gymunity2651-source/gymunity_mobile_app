import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../member/domain/entities/coaching_engagement_entity.dart';
import '../providers/coach_providers.dart';

class CoachCheckinInboxScreen extends ConsumerWidget {
  const CoachCheckinInboxScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinsAsync = ref.watch(coachCheckinInboxProvider);
    final content = RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(coachCheckinInboxProvider);
        await ref.read(coachCheckinInboxProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.lg,
          AppSizes.screenPadding,
          96,
        ),
        children: [
          Text(
            'Check-in inbox',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          checkinsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _InboxState(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load check-ins',
              body: error.toString(),
              actionLabel: 'Retry',
              onTap: () => ref.invalidate(coachCheckinInboxProvider),
            ),
            data: (checkins) {
              if (checkins.isEmpty) {
                return const _InboxState(
                  icon: Icons.fact_check_outlined,
                  title: 'No pending check-ins',
                  body: 'Pending and overdue check-ins appear here.',
                );
              }
              return Column(
                children: checkins
                    .map((checkin) => _CheckinCard(checkin: checkin))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );

    if (embedded) {
      return content;
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Check-ins'),
        backgroundColor: AppColors.background,
      ),
      body: content,
    );
  }
}

class _CheckinCard extends ConsumerWidget {
  const _CheckinCard({required this.checkin});

  final WeeklyCheckinEntity checkin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: AppColors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Week of ${_date(checkin.weekStart)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Chip(
                label: Text('Adherence ${checkin.adherenceScore}/10'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (checkin.workoutsCompleted != null)
            _TextBlock(
              label: 'Workouts completed',
              value: checkin.workoutsCompleted.toString(),
            ),
          if (checkin.missedWorkouts != null)
            _TextBlock(
              label: 'Missed workouts',
              value: checkin.missedWorkouts.toString(),
            ),
          if (checkin.missedWorkoutsReason?.trim().isNotEmpty == true)
            _TextBlock(
              label: 'Missed reason',
              value: checkin.missedWorkoutsReason!,
            ),
          if (checkin.painWarning?.trim().isNotEmpty == true)
            _TextBlock(label: 'Pain warning', value: checkin.painWarning!),
          if (checkin.biggestObstacle?.trim().isNotEmpty == true)
            _TextBlock(
              label: 'Biggest obstacle',
              value: checkin.biggestObstacle!,
            ),
          if (checkin.supportNeeded?.trim().isNotEmpty == true)
            _TextBlock(label: 'Support needed', value: checkin.supportNeeded!),
          if (checkin.wins?.trim().isNotEmpty == true)
            _TextBlock(label: 'Wins', value: checkin.wins!),
          if (checkin.blockers?.trim().isNotEmpty == true)
            _TextBlock(label: 'Blockers', value: checkin.blockers!),
          if (checkin.questions?.trim().isNotEmpty == true)
            _TextBlock(label: 'Questions', value: checkin.questions!),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              onPressed: checkin.threadId == null
                  ? null
                  : () => _openFeedbackSheet(context, ref, checkin),
              label: const Text('Review check-in'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFeedbackSheet(
    BuildContext context,
    WidgetRef ref,
    WeeklyCheckinEntity checkin,
  ) async {
    final controller = TextEditingController();
    final wentWellController = TextEditingController();
    final attentionController = TextEditingController();
    final adjustmentController = TextEditingController();
    final priorityController = TextEditingController();
    final coachNoteController = TextEditingController();
    final planChangesController = TextEditingController();
    final nextCheckinController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.screenPadding,
          right: AppSizes.screenPadding,
          top: AppSizes.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Structured feedback',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              controller: wentWellController,
              decoration: const InputDecoration(labelText: 'What went well'),
            ),
            TextField(
              controller: attentionController,
              decoration: const InputDecoration(
                labelText: 'What needs attention',
              ),
            ),
            TextField(
              controller: adjustmentController,
              decoration: const InputDecoration(
                labelText: 'Adjustment for next week',
              ),
            ),
            TextField(
              controller: priorityController,
              decoration: const InputDecoration(labelText: 'One priority'),
            ),
            TextField(
              controller: planChangesController,
              decoration: const InputDecoration(
                labelText: 'Plan changes summary',
              ),
            ),
            TextField(
              controller: nextCheckinController,
              decoration: const InputDecoration(
                labelText: 'Next check-in date (YYYY-MM-DD)',
              ),
              keyboardType: TextInputType.datetime,
            ),
            TextField(
              controller: coachNoteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Private coach note',
                alignLabelWithHint: true,
              ),
            ),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Member-facing feedback message',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_outlined, size: 18),
                onPressed: () async {
                  final feedback = controller.text.trim();
                  if (feedback.isEmpty || checkin.threadId == null) return;
                  await ref
                      .read(coachRepositoryProvider)
                      .submitCheckinFeedback(
                        checkinId: checkin.id,
                        threadId: checkin.threadId!,
                        feedback: feedback,
                        whatWentWell: _emptyToNull(wentWellController.text),
                        whatNeedsAttention: _emptyToNull(
                          attentionController.text,
                        ),
                        adjustmentForNextWeek: _emptyToNull(
                          adjustmentController.text,
                        ),
                        onePriority: _emptyToNull(priorityController.text),
                        coachNote: _emptyToNull(coachNoteController.text),
                        planChangesSummary: _emptyToNull(
                          planChangesController.text,
                        ),
                        nextCheckinDate:
                            nextCheckinController.text.trim().isEmpty
                            ? null
                            : DateTime.tryParse(
                                nextCheckinController.text.trim(),
                              ),
                      );
                  ref.invalidate(coachCheckinInboxProvider);
                  if (context.mounted) Navigator.pop(context);
                },
                label: const Text('Send feedback'),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    wentWellController.dispose();
    attentionController.dispose();
    adjustmentController.dispose();
    priorityController.dispose();
    coachNoteController.dispose();
    planChangesController.dispose();
    nextCheckinController.dispose();
  }
}

String _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '' : trimmed;
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 13, height: 1.35)),
        ],
      ),
    );
  }
}

class _InboxState extends StatelessWidget {
  const _InboxState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onTap != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onTap, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
