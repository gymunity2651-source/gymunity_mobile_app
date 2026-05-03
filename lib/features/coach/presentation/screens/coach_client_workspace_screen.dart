import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../member/domain/entities/coaching_engagement_entity.dart';
import '../../domain/entities/coach_taiyo_entity.dart';
import '../../domain/entities/coach_workspace_entity.dart';
import '../providers/coach_providers.dart';

class CoachClientWorkspaceScreen extends ConsumerStatefulWidget {
  const CoachClientWorkspaceScreen({super.key, required this.subscriptionId});

  final String subscriptionId;

  @override
  ConsumerState<CoachClientWorkspaceScreen> createState() =>
      _CoachClientWorkspaceScreenState();
}

class _CoachClientWorkspaceScreenState
    extends ConsumerState<CoachClientWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 10, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceAsync = ref.watch(
      coachClientWorkspaceProvider(widget.subscriptionId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Client workspace'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Plan'),
            Tab(text: 'Check-ins'),
            Tab(text: 'Progress'),
            Tab(text: 'Nutrition'),
            Tab(text: 'Messages'),
            Tab(text: 'Notes'),
            Tab(text: 'Files'),
            Tab(text: 'Billing'),
            Tab(text: 'Privacy'),
          ],
        ),
      ),
      body: workspaceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _WorkspaceState(
          icon: Icons.cloud_off_outlined,
          title: 'Client unavailable',
          body: error.toString(),
          actionLabel: 'Retry',
          onTap: () => ref.invalidate(
            coachClientWorkspaceProvider(widget.subscriptionId),
          ),
        ),
        data: (workspace) => TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(
              workspace: workspace,
              onReviewPayment: () => _tabController.animateTo(8),
              onReviewConsent: () => _tabController.animateTo(9),
            ),
            _PlanTab(workspace: workspace),
            _CheckinsTab(workspace: workspace),
            _ConsentLockedTab(
              enabled:
                  workspace.visibility?.shareProgressMetrics == true ||
                  workspace.visibility?.shareWorkoutAdherence == true,
              title: 'Progress',
              unlocked: _ProgressUnlocked(workspace: workspace),
              lockedBody:
                  'Progress photos, body metrics, and adherence are available only when the member grants progress or workout visibility.',
            ),
            _ConsentLockedTab(
              enabled: workspace.visibility?.shareNutritionSummary == true,
              title: 'Nutrition',
              unlocked: _NutritionUnlocked(workspace: workspace),
              lockedBody:
                  'Nutrition summary is hidden until the member enables nutrition sharing for this subscription.',
            ),
            _MessagesTab(workspace: workspace),
            _NotesTab(workspace: workspace),
            _FilesTab(workspace: workspace),
            _BillingTab(workspace: workspace),
            _PrivacyTab(workspace: workspace),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({
    required this.workspace,
    required this.onReviewPayment,
    required this.onReviewConsent,
  });

  final CoachClientWorkspaceEntity workspace;
  final VoidCallback onReviewPayment;
  final VoidCallback onReviewConsent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = workspace.client;
    final canSchedule = workspace.client.canScheduleBookings;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        _ClientHeader(client: client),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(label: client.status.replaceAll('_', ' ')),
            _Chip(label: client.pipelineStage.replaceAll('_', ' ')),
            if (client.goal != null) _Chip(label: client.goal!),
            if (client.nextRenewalAt != null)
              _Chip(label: 'Renews ${_date(client.nextRenewalAt!)}'),
            if (client.unreadMessages > 0)
              _Chip(label: '${client.unreadMessages} unread'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_outlined, size: 18),
                onPressed: workspace.threads.isEmpty
                    ? null
                    : () => _openMessageSheet(
                        context,
                        ref,
                        workspace.threads.first,
                        workspace.client.subscriptionId,
                        workspace.client.status,
                      ),
                label: const Text('Message'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                onPressed: canSchedule
                    ? () => _openScheduleSessionSheet(context, ref, workspace)
                    : () => _showWorkspaceSnack(
                        context,
                        'Activate or unpause this client before scheduling.',
                      ),
                label: const Text('Schedule'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _QuickActionGrid(
          workspace: workspace,
          onReviewPayment: onReviewPayment,
          onReviewConsent: onReviewConsent,
        ),
        const SizedBox(height: 14),
        _InfoGrid(
          items: [
            _InfoItem('Package', client.packageTitle ?? 'Coaching'),
            _InfoItem('Payment', client.checkoutStatus.replaceAll('_', ' ')),
            _InfoItem(
              'Started',
              client.startedAt == null
                  ? 'Not started'
                  : _date(client.startedAt!),
            ),
            _InfoItem(
              'Adherence',
              client.riskFlags.isEmpty
                  ? 'No active flags'
                  : client.riskFlags.join(', '),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _TaiyoCoachBrief(
          workspace: workspace,
          onReviewConsent: onReviewConsent,
        ),
        const SizedBox(height: 14),
        _Timeline(workspace: workspace),
      ],
    );
  }
}

class _TaiyoCoachBrief extends ConsumerWidget {
  const _TaiyoCoachBrief({
    required this.workspace,
    required this.onReviewConsent,
  });

  final CoachClientWorkspaceEntity workspace;
  final VoidCallback onReviewConsent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefAsync = ref.watch(
      taiyoCoachClientBriefProvider(workspace.client.subscriptionId),
    );
    return briefAsync.when(
      loading: () => const _SimplePanel(
        icon: Icons.auto_awesome_outlined,
        title: 'TAIYO Coach Brief',
        body: 'TAIYO is reviewing the shared client context.',
      ),
      error: (error, _) => _SimplePanel(
        icon: Icons.cloud_off_outlined,
        title: 'TAIYO Coach Brief',
        body: 'TAIYO could not prepare this client brief right now.',
        actionLabel: 'Retry',
        onTap: () => ref.invalidate(
          taiyoCoachClientBriefProvider(workspace.client.subscriptionId),
        ),
      ),
      data: (brief) =>
          _TaiyoCoachBriefPanel(brief: brief, onReviewConsent: onReviewConsent),
    );
  }
}

class _TaiyoCoachBriefPanel extends StatelessWidget {
  const _TaiyoCoachBriefPanel({
    required this.brief,
    required this.onReviewConsent,
  });

  final CoachTaiyoClientBriefEntity brief;
  final VoidCallback onReviewConsent;

  @override
  Widget build(BuildContext context) {
    if (brief.needsVisibilityPermission) {
      return _SimplePanel(
        icon: Icons.privacy_tip_outlined,
        title: 'TAIYO Coach Brief',
        body: brief.summary,
        actionLabel: 'Review Privacy',
        onTap: onReviewConsent,
      );
    }

    final redFlags = brief.redFlags.isEmpty
        ? 'No new red flags from shared data.'
        : 'Red flags: ${brief.redFlags.join(', ')}.';
    final action = brief.suggestedAction.trim().isEmpty
        ? 'Review the brief before taking action.'
        : brief.suggestedAction;
    final draft = brief.hasDraftMessage
        ? '\nDraft message: ${brief.suggestedMessage}'
        : '';
    return _SimplePanel(
      icon: brief.riskLevel == 'high'
          ? Icons.warning_amber_outlined
          : Icons.auto_awesome_outlined,
      title: 'TAIYO Coach Brief',
      body:
          '${brief.summary.isEmpty ? 'TAIYO prepared a client brief.' : brief.summary}\n$redFlags\n$action$draft\nDraft only: review before the member sees anything.',
    );
  }
}

class _QuickActionGrid extends ConsumerWidget {
  const _QuickActionGrid({
    required this.workspace,
    required this.onReviewPayment,
    required this.onReviewConsent,
  });

  final CoachClientWorkspaceEntity workspace;
  final VoidCallback onReviewPayment;
  final VoidCallback onReviewConsent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.15,
      children: [
        _ActionTile(
          icon: Icons.chat_outlined,
          title: 'Message client',
          onTap: workspace.threads.isEmpty
              ? null
              : () => _openMessageSheet(
                  context,
                  ref,
                  workspace.threads.first,
                  workspace.client.subscriptionId,
                  workspace.client.status,
                ),
        ),
        _ActionTile(
          icon: Icons.event_outlined,
          title: 'Schedule session',
          onTap: workspace.client.canScheduleBookings
              ? () => _openScheduleSessionSheet(context, ref, workspace)
              : () => _showWorkspaceSnack(
                  context,
                  'Activate or unpause this client before scheduling.',
                ),
        ),
        _ActionTile(
          icon: Icons.view_week_outlined,
          title: 'Assign program',
          onTap: () => _openAssignTemplateSheet(context, ref, workspace),
        ),
        _ActionTile(
          icon: Icons.receipt_long_outlined,
          title: 'Review payment',
          onTap: onReviewPayment,
        ),
        _ActionTile(
          icon: Icons.folder_open_outlined,
          title: 'Assign resource',
          onTap: () => _openAssignResourceSheet(context, ref, workspace),
        ),
        _ActionTile(
          icon: Icons.shield_outlined,
          title: 'Review consent',
          onTap: onReviewConsent,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTab extends ConsumerWidget {
  const _PlanTab({required this.workspace});

  final CoachClientWorkspaceEntity workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(coachProgramTemplatesProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        _SimplePanel(
          icon: Icons.view_week_outlined,
          title: 'Program delivery',
          body:
              'Assign phased templates, then layer habits and accountability tasks without leaving the client workspace.',
          actionLabel: 'Open library',
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.coachProgramLibrary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.playlist_add_check, size: 18),
                onPressed: () => _openAssignHabitSheet(context, ref, workspace),
                label: const Text('Assign habits'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                onPressed: () =>
                    _openAssignResourceSheet(context, ref, workspace),
                label: const Text('Assign resources'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        templatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _WorkspaceState(
            icon: Icons.cloud_off_outlined,
            title: 'Templates unavailable',
            body: error.toString(),
          ),
          data: (templates) {
            if (templates.isEmpty) {
              return const _SimplePanel(
                icon: Icons.library_add_outlined,
                title: 'No templates yet',
                body: 'Create templates in Library before assigning programs.',
              );
            }
            return Column(
              children: templates
                  .take(6)
                  .map(
                    (template) => _ListPanel(
                      icon: Icons.fitness_center_outlined,
                      title: template.title,
                      subtitle:
                          '${template.goalType.replaceAll('_', ' ')} · ${template.durationWeeks} weeks · ${template.locationMode}',
                      actionLabel: 'Assign',
                      onTap: () async {
                        try {
                          await ref
                              .read(coachRepositoryProvider)
                              .assignProgramTemplate(
                                subscriptionId: workspace.client.subscriptionId,
                                templateId: template.id,
                              );
                          ref.invalidate(
                            coachClientWorkspaceProvider(
                              workspace.client.subscriptionId,
                            ),
                          );
                          if (context.mounted) {
                            _showWorkspaceSnack(context, 'Program assigned.');
                          }
                        } catch (error) {
                          if (context.mounted) {
                            _showWorkspaceSnack(
                              context,
                              'Program could not be assigned: $error',
                            );
                          }
                        }
                      },
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _CheckinsTab extends ConsumerWidget {
  const _CheckinsTab({required this.workspace});

  final CoachClientWorkspaceEntity workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workspace.checkins.isEmpty) {
      return const _WorkspaceState(
        icon: Icons.fact_check_outlined,
        title: 'No check-ins yet',
        body: 'Submitted weekly check-ins appear here for review.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: workspace.checkins
          .map(
            (checkin) => _ListPanel(
              icon: Icons.fact_check_outlined,
              title: 'Week of ${_date(checkin.weekStart)}',
              subtitle:
                  'Adherence ${checkin.adherenceScore}/10 · ${checkin.coachReply == null ? 'pending feedback' : 'reviewed'}',
              actionLabel: 'Review',
              onTap: () =>
                  _openCheckinReviewSheet(context, ref, workspace, checkin),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ProgressUnlocked extends StatelessWidget {
  const _ProgressUnlocked({required this.workspace});

  final CoachClientWorkspaceEntity workspace;

  @override
  Widget build(BuildContext context) {
    final latest = workspace.checkins.isEmpty ? null : workspace.checkins.first;
    if (latest == null) {
      return const _SimplePanel(
        icon: Icons.show_chart_outlined,
        title: 'Shared progress',
        body:
            'Progress sharing is active, but no progress entries are available yet.',
      );
    }
    return _InfoGrid(
      items: [
        _InfoItem('Latest adherence', '${latest.adherenceScore}/10'),
        _InfoItem('Training week', _date(latest.weekStart)),
        _InfoItem(
          'Coach review',
          latest.coachReply == null ? 'Pending' : 'Sent',
        ),
        _InfoItem(
          'Risk state',
          workspace.client.riskFlags.isEmpty
              ? 'Stable'
              : workspace.client.riskFlags.join(', '),
        ),
      ],
    );
  }
}

class _NutritionUnlocked extends StatelessWidget {
  const _NutritionUnlocked({required this.workspace});

  final CoachClientWorkspaceEntity workspace;

  @override
  Widget build(BuildContext context) {
    final latest = workspace.checkins.isEmpty ? null : workspace.checkins.first;
    if (latest == null) {
      return const _SimplePanel(
        icon: Icons.restaurant_menu_outlined,
        title: 'Nutrition summary',
        body:
            'The client has granted access, but no nutrition-linked check-in data is available yet.',
      );
    }
    return _InfoGrid(
      items: [
        _InfoItem('Adherence', '${latest.adherenceScore}/10'),
        _InfoItem(
          'Energy',
          latest.energyScore == null
              ? 'Not logged'
              : '${latest.energyScore}/10',
        ),
        _InfoItem(
          'Sleep',
          latest.sleepScore == null ? 'Not logged' : '${latest.sleepScore}/10',
        ),
        _InfoItem(
          'Wins',
          latest.wins == null || latest.wins!.trim().isEmpty
              ? 'No notes submitted'
              : 'Submitted',
        ),
      ],
    );
  }
}

class _MessagesTab extends ConsumerWidget {
  const _MessagesTab({required this.workspace});

  final CoachClientWorkspaceEntity workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workspace.threads.isEmpty) {
      return const _WorkspaceState(
        icon: Icons.chat_bubble_outline,
        title: 'No thread yet',
        body: 'The coaching thread is created when payment is activated.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: workspace.threads
          .map(
            (thread) => _ListPanel(
              icon: Icons.chat_bubble_outline,
              title: 'Coaching thread',
              subtitle: thread.lastMessagePreview.isEmpty
                  ? 'No recent message'
                  : thread.lastMessagePreview,
              actionLabel: 'Send',
              onTap: () => _openMessageSheet(
                context,
                ref,
                thread,
                workspace.client.subscriptionId,
                workspace.client.status,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _NotesTab extends ConsumerStatefulWidget {
  const _NotesTab({required this.workspace});

  final CoachClientWorkspaceEntity workspace;

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Private coach note',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () async {
            final note = _controller.text.trim();
            if (note.isEmpty) return;
            try {
              await ref
                  .read(coachRepositoryProvider)
                  .addClientNote(
                    subscriptionId: widget.workspace.client.subscriptionId,
                    note: note,
                  );
              _controller.clear();
              ref.invalidate(
                coachClientWorkspaceProvider(
                  widget.workspace.client.subscriptionId,
                ),
              );
              if (context.mounted) {
                _showWorkspaceSnack(context, 'Note saved.');
              }
            } catch (error) {
              if (context.mounted) {
                _showWorkspaceSnack(context, 'Note could not be saved: $error');
              }
            }
          },
          icon: const Icon(Icons.lock_outline, size: 18),
          label: const Text('Save note'),
        ),
        const SizedBox(height: 14),
        ...widget.workspace.notes.map(
          (note) => _ListPanel(
            icon: note.isPinned ? Icons.push_pin : Icons.note_alt_outlined,
            title: note.noteType.replaceAll('_', ' '),
            subtitle: note.note,
          ),
        ),
      ],
    );
  }
}

class _FilesTab extends ConsumerWidget {
  const _FilesTab({required this.workspace});

  final CoachClientWorkspaceEntity workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add_link_outlined, size: 18),
            onPressed: () => _openAssignResourceSheet(context, ref, workspace),
            label: const Text('Assign resource'),
          ),
        ),
        const SizedBox(height: 12),
        if (workspace.resources.isEmpty)
          _WorkspaceState(
            icon: Icons.folder_outlined,
            title: 'No assigned files',
            body:
                'Client resources assigned from the resource library appear here.',
            actionLabel: 'Resources',
            onTap: () => Navigator.pushNamed(context, AppRoutes.coachResources),
          )
        else
          ...workspace.resources.map(
            (resource) => _ListPanel(
              icon: Icons.attach_file,
              title: resource.title,
              subtitle: resource.externalUrl ?? resource.resourceType,
            ),
          ),
      ],
    );
  }
}

class _BillingTab extends ConsumerWidget {
  const _BillingTab({required this.workspace});

  final CoachClientWorkspaceEntity workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = workspace.billing;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        if (billing.isEmpty)
          _WorkspaceState(
            icon: Icons.receipt_long_outlined,
            title: 'Awaiting payment',
            body: 'Receipt submissions and verification history appear here.',
            actionLabel: 'Billing queue',
            onTap: () => Navigator.pushNamed(context, AppRoutes.coachBilling),
          )
        else
          ...billing.map(
            (receipt) => _ListPanel(
              icon: Icons.receipt_long_outlined,
              title: receipt.billingState.replaceAll('_', ' '),
              subtitle:
                  '${receipt.currency} ${receipt.amount.toStringAsFixed(0)} · ${receipt.status.replaceAll('_', ' ')}',
              actionLabel: 'Open queue',
              onTap: () => Navigator.pushNamed(context, AppRoutes.coachBilling),
            ),
          ),
        const SizedBox(height: 12),
        FutureBuilder<List<CoachPaymentAuditEntity>>(
          future: ref
              .read(coachRepositoryProvider)
              .listPaymentAuditTrail(workspace.client.subscriptionId),
          builder: (context, snapshot) {
            final audits = snapshot.data ?? const <CoachPaymentAuditEntity>[];
            if (audits.isEmpty) {
              return const _SimplePanel(
                icon: Icons.history_outlined,
                title: 'No billing audit yet',
                body:
                    'Payment state changes and verification notes appear here.',
              );
            }
            return Column(
              children: audits
                  .map(
                    (audit) => _ListPanel(
                      icon: Icons.history_outlined,
                      title: audit.newState.replaceAll('_', ' '),
                      subtitle:
                          audit.note ??
                          'Updated by ${audit.actorName ?? 'coach'}',
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _PrivacyTab extends StatelessWidget {
  const _PrivacyTab({required this.workspace});

  final CoachClientWorkspaceEntity workspace;

  @override
  Widget build(BuildContext context) {
    final visibility = workspace.visibility;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        _SimplePanel(
          icon: Icons.shield_outlined,
          title: visibility?.hasAnySharing == true
              ? 'Member consent active'
              : 'Privacy locked',
          body:
              'Progress, workout, nutrition, purchase, and AI plan insights remain member-controlled.',
        ),
        const SizedBox(height: 12),
        _InfoGrid(
          items: [
            _InfoItem(
              'Workout',
              visibility?.shareWorkoutAdherence == true ? 'Shared' : 'Locked',
            ),
            _InfoItem(
              'Progress',
              visibility?.shareProgressMetrics == true ? 'Shared' : 'Locked',
            ),
            _InfoItem(
              'Nutrition',
              visibility?.shareNutritionSummary == true ? 'Shared' : 'Locked',
            ),
            _InfoItem(
              'AI plan',
              visibility?.shareAiPlanSummary == true ? 'Shared' : 'Locked',
            ),
          ],
        ),
      ],
    );
  }
}

class _ConsentLockedTab extends StatelessWidget {
  const _ConsentLockedTab({
    required this.enabled,
    required this.title,
    required this.unlocked,
    required this.lockedBody,
  });

  final bool enabled;
  final String title;
  final Widget unlocked;
  final String lockedBody;

  @override
  Widget build(BuildContext context) {
    if (enabled) {
      return ListView(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        children: [unlocked],
      );
    }
    return _WorkspaceState(
      icon: Icons.lock_outline,
      title: '$title locked',
      body: lockedBody,
    );
  }
}

class _ClientHeader extends StatelessWidget {
  const _ClientHeader({required this.client});

  final CoachClientPipelineEntry client;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            child: Text(
              client.memberName.isEmpty
                  ? '?'
                  : client.memberName.characters.first.toUpperCase(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.memberName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  client.packageTitle ?? 'Coaching',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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

class _Timeline extends StatelessWidget {
  const _Timeline({required this.workspace});

  final CoachClientWorkspaceEntity workspace;

  @override
  Widget build(BuildContext context) {
    final items = <_InfoItem>[
      if (workspace.client.startedAt != null)
        _InfoItem('Started', _date(workspace.client.startedAt!)),
      if (workspace.checkins.isNotEmpty)
        _InfoItem('Latest check-in', _date(workspace.checkins.first.weekStart)),
      if (workspace.bookings.isNotEmpty)
        _InfoItem('Latest session', _date(workspace.bookings.first.startsAt)),
      if (workspace.billing.isNotEmpty)
        _InfoItem('Billing', workspace.billing.first.billingState),
    ];
    if (items.isEmpty) {
      return const _SimplePanel(
        icon: Icons.timeline_outlined,
        title: 'No activity yet',
        body:
            'Activity appears after check-ins, bookings, resources, or billing events.',
      );
    }
    return _InfoGrid(items: items);
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value);

  final String label;
  final String value;
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.8,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ListPanel extends StatelessWidget {
  const _ListPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onTap, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _SimplePanel extends StatelessWidget {
  const _SimplePanel({
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
    return _WorkspaceState(
      icon: icon,
      title: title,
      body: body,
      actionLabel: actionLabel,
      onTap: onTap,
    );
  }
}

class _WorkspaceState extends StatelessWidget {
  const _WorkspaceState({
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.orange),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              if (actionLabel != null && onTap != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onTap, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceDetailLine extends StatelessWidget {
  const _WorkspaceDetailLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachMessageBubble extends StatelessWidget {
  const _CoachMessageBubble({required this.message});

  final CoachMessageEntity message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isCoach && !message.isSystem;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          message.content,
          style: GoogleFonts.inter(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

Future<void> _openScheduleSessionSheet(
  BuildContext context,
  WidgetRef ref,
  CoachClientWorkspaceEntity workspace,
) async {
  List<CoachSessionTypeEntity> sessionTypes;
  try {
    sessionTypes = await ref.read(coachSessionTypesProvider.future);
  } catch (error) {
    if (context.mounted) {
      _showWorkspaceSnack(context, 'Session types could not load: $error');
    }
    return;
  }
  if (!context.mounted) return;

  CoachSessionTypeEntity? sessionType = sessionTypes.isEmpty
      ? null
      : sessionTypes.first;
  final dateController = TextEditingController(
    text: _dateTimeInput(DateTime.now().add(const Duration(days: 1))),
  );
  final noteController = TextEditingController();

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
      child: StatefulBuilder(
        builder: (context, setSheetState) => ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Schedule session',
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
            _WorkspaceDetailLine('Client', workspace.client.memberName),
            if (sessionTypes.isEmpty)
              _SimplePanel(
                icon: Icons.video_call_outlined,
                title: 'No session types',
                body:
                    'Create a consultation, check-in, video, or in-person session type before booking this client.',
                actionLabel: 'Open calendar',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.coachCalendar);
                },
              )
            else ...[
              DropdownButtonFormField<CoachSessionTypeEntity>(
                initialValue: sessionType,
                decoration: const InputDecoration(labelText: 'Session type'),
                items: sessionTypes
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.title),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setSheetState(() => sessionType = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Start datetime',
                  hintText: 'YYYY-MM-DD HH:MM',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                onTap: () async {
                  final pickedAt = await _pickDateTime(
                    context,
                    initial:
                        _parseDateTimeInput(dateController.text) ??
                        DateTime.now().add(const Duration(days: 1)),
                  );
                  if (pickedAt != null) {
                    dateController.text = _dateTimeInput(pickedAt);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Session note',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  onPressed: () async {
                    final startsAt = _parseDateTimeInput(dateController.text);
                    if (sessionType == null || startsAt == null) {
                      _showWorkspaceSnack(
                        context,
                        'Choose a session type and valid start time.',
                      );
                      return;
                    }
                    if (!startsAt.isAfter(DateTime.now())) {
                      _showWorkspaceSnack(
                        context,
                        'Choose a future start time.',
                      );
                      return;
                    }
                    try {
                      await ref
                          .read(coachRepositoryProvider)
                          .createBooking(
                            subscriptionId: workspace.client.subscriptionId,
                            sessionTypeId: sessionType!.id,
                            startsAt: startsAt,
                            timezone: DateTime.now().timeZoneName,
                            note: _textOrNull(noteController.text),
                          );
                      ref.invalidate(coachBookingsProvider);
                      ref.invalidate(
                        coachClientWorkspaceProvider(
                          workspace.client.subscriptionId,
                        ),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showWorkspaceSnack(context, 'Session scheduled.');
                      }
                    } catch (error) {
                      if (context.mounted) {
                        _showWorkspaceSnack(
                          context,
                          'Session could not be scheduled: $error',
                        );
                      }
                    }
                  },
                  label: const Text('Create booking'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  dateController.dispose();
  noteController.dispose();
}

Future<void> _openCheckinReviewSheet(
  BuildContext context,
  WidgetRef ref,
  CoachClientWorkspaceEntity workspace,
  WeeklyCheckinEntity checkin,
) async {
  final rootContext = context;
  final structuredFeedback = checkin.coachFeedback;
  final feedbackController = TextEditingController(
    text: checkin.coachReply ?? '',
  );
  final wentWellController = TextEditingController(
    text: structuredFeedback['what_went_well']?.toString() ?? '',
  );
  final attentionController = TextEditingController(
    text: structuredFeedback['what_needs_attention']?.toString() ?? '',
  );
  final adjustmentController = TextEditingController(
    text: structuredFeedback['adjustment_for_next_week']?.toString() ?? '',
  );
  final priorityController = TextEditingController(
    text: structuredFeedback['one_priority']?.toString() ?? '',
  );
  final coachNoteController = TextEditingController(
    text: structuredFeedback['coach_note']?.toString() ?? '',
  );
  final planChangesController = TextEditingController(
    text: structuredFeedback['plan_changes_summary']?.toString() ?? '',
  );
  final nextCheckinController = TextEditingController(
    text: checkin.nextCheckinDate == null
        ? ''
        : _date(checkin.nextCheckinDate!),
  );
  final threadId =
      checkin.threadId ??
      (workspace.threads.isEmpty ? null : workspace.threads.first.id);

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
                  'Review check-in',
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
          _WorkspaceDetailLine('Week', _date(checkin.weekStart)),
          _WorkspaceDetailLine('Adherence', '${checkin.adherenceScore}/10'),
          if (checkin.workoutsCompleted != null)
            _WorkspaceDetailLine(
              'Workouts completed',
              checkin.workoutsCompleted.toString(),
            ),
          if (checkin.missedWorkouts != null)
            _WorkspaceDetailLine(
              'Missed workouts',
              checkin.missedWorkouts.toString(),
            ),
          if (_textOrNull(checkin.missedWorkoutsReason) != null)
            _WorkspaceDetailLine(
              'Missed reason',
              checkin.missedWorkoutsReason!,
            ),
          if (checkin.energyScore != null)
            _WorkspaceDetailLine('Energy', '${checkin.energyScore}/10'),
          if (checkin.sleepScore != null)
            _WorkspaceDetailLine('Sleep', '${checkin.sleepScore}/10'),
          if (checkin.sorenessScore != null)
            _WorkspaceDetailLine('Soreness', '${checkin.sorenessScore}/10'),
          if (checkin.fatigueScore != null)
            _WorkspaceDetailLine('Fatigue', '${checkin.fatigueScore}/10'),
          if (_textOrNull(checkin.painWarning) != null)
            _WorkspaceDetailLine('Pain warning', checkin.painWarning!),
          if (checkin.nutritionAdherenceScore != null)
            _WorkspaceDetailLine(
              'Nutrition',
              '${checkin.nutritionAdherenceScore}%',
            ),
          if (checkin.habitAdherenceScore != null)
            _WorkspaceDetailLine('Habits', '${checkin.habitAdherenceScore}%'),
          if (_textOrNull(checkin.biggestObstacle) != null)
            _WorkspaceDetailLine('Biggest obstacle', checkin.biggestObstacle!),
          if (_textOrNull(checkin.supportNeeded) != null)
            _WorkspaceDetailLine('Support needed', checkin.supportNeeded!),
          if (_textOrNull(checkin.wins) != null)
            _WorkspaceDetailLine('Wins', checkin.wins!),
          if (_textOrNull(checkin.blockers) != null)
            _WorkspaceDetailLine('Blockers', checkin.blockers!),
          if (_textOrNull(checkin.questions) != null)
            _WorkspaceDetailLine('Questions', checkin.questions!),
          if (checkin.photos.isNotEmpty)
            _WorkspaceDetailLine('Photos', '${checkin.photos.length} shared'),
          const SizedBox(height: 12),
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
            controller: feedbackController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Member-facing feedback message',
              alignLabelWithHint: true,
            ),
          ),
          if (threadId == null) ...[
            const SizedBox(height: 10),
            const _SimplePanel(
              icon: Icons.chat_bubble_outline,
              title: 'No coaching thread',
              body:
                  'Feedback needs an active coaching thread. Activate payment or open messages after the thread is created.',
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              onPressed: threadId == null
                  ? null
                  : () async {
                      final feedback = feedbackController.text.trim();
                      if (feedback.isEmpty) return;
                      final nextCheckin = nextCheckinController.text.trim();
                      try {
                        await ref
                            .read(coachRepositoryProvider)
                            .submitCheckinFeedback(
                              checkinId: checkin.id,
                              threadId: threadId,
                              feedback: feedback,
                              whatWentWell:
                                  _textOrNull(wentWellController.text) ?? '',
                              whatNeedsAttention:
                                  _textOrNull(attentionController.text) ?? '',
                              adjustmentForNextWeek:
                                  _textOrNull(adjustmentController.text) ?? '',
                              onePriority:
                                  _textOrNull(priorityController.text) ?? '',
                              coachNote:
                                  _textOrNull(coachNoteController.text) ?? '',
                              planChangesSummary:
                                  _textOrNull(planChangesController.text) ?? '',
                              nextCheckinDate: nextCheckin.isEmpty
                                  ? null
                                  : DateTime.tryParse(nextCheckin),
                            );
                        ref.invalidate(coachCheckinInboxProvider);
                        ref.invalidate(
                          coachClientWorkspaceProvider(
                            workspace.client.subscriptionId,
                          ),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          if (rootContext.mounted) {
                            _showWorkspaceSnack(rootContext, 'Feedback sent.');
                          }
                        }
                      } catch (error) {
                        if (rootContext.mounted) {
                          _showWorkspaceSnack(
                            rootContext,
                            'Feedback could not be sent: $error',
                          );
                        }
                      }
                    },
              label: const Text('Send feedback'),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _openMessageSheet(
  BuildContext context,
  WidgetRef ref,
  CoachThreadEntity thread,
  String subscriptionId,
  String subscriptionStatus,
) async {
  final rootContext = context;
  final controller = TextEditingController();
  final canSend = subscriptionStatus == 'active';
  Future<List<CoachMessageEntity>> messagesFuture() =>
      ref.read(coachRepositoryProvider).listCoachMessages(thread.id);
  var currentMessages = messagesFuture();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => FractionallySizedBox(
        heightFactor: 0.85,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSizes.screenPadding,
            right: AppSizes.screenPadding,
            top: AppSizes.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Coaching messages',
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
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<CoachMessageEntity>>(
                  future: currentMessages,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _WorkspaceState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Messages unavailable',
                        body: snapshot.error.toString(),
                      );
                    }
                    final messages =
                        snapshot.data ?? const <CoachMessageEntity>[];
                    if (messages.isEmpty) {
                      return const _WorkspaceState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No messages yet',
                        body:
                            'Start the coaching conversation with this client.',
                      );
                    }
                    return ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          _CoachMessageBubble(message: messages[index]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                enabled: canSend,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              if (!canSend) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'This subscription is paused. Message history remains available, but new messages require an active subscription.',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_outlined, size: 18),
                  onPressed: canSend
                      ? () async {
                          final message = controller.text.trim();
                          if (message.isEmpty) return;
                          try {
                            await ref
                                .read(coachRepositoryProvider)
                                .sendCoachMessage(
                                  threadId: thread.id,
                                  content: message,
                                );
                            controller.clear();
                            ref.invalidate(
                              coachClientWorkspaceProvider(subscriptionId),
                            );
                            ref.invalidate(coachClientPipelineProvider);
                            setSheetState(
                              () => currentMessages = messagesFuture(),
                            );
                          } catch (error) {
                            if (rootContext.mounted) {
                              _showWorkspaceSnack(
                                rootContext,
                                'Message could not be sent: $error',
                              );
                            }
                          }
                        }
                      : null,
                  label: const Text('Send'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  controller.dispose();
}

Future<void> _openAssignTemplateSheet(
  BuildContext context,
  WidgetRef ref,
  CoachClientWorkspaceEntity workspace,
) async {
  final templates = await ref.read(coachProgramTemplatesProvider.future);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Assign program template',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (templates.isEmpty)
            const _SimplePanel(
              icon: Icons.library_add_outlined,
              title: 'No templates available',
              body: 'Create templates first in the program library.',
            )
          else
            ...templates
                .take(8)
                .map(
                  (template) => _ListPanel(
                    icon: Icons.fitness_center_outlined,
                    title: template.title,
                    subtitle:
                        '${template.goalType.replaceAll('_', ' ')} · ${template.durationWeeks} weeks',
                    actionLabel: 'Assign',
                    onTap: () async {
                      try {
                        await ref
                            .read(coachRepositoryProvider)
                            .assignProgramTemplate(
                              subscriptionId: workspace.client.subscriptionId,
                              templateId: template.id,
                            );
                        ref.invalidate(
                          coachClientWorkspaceProvider(
                            workspace.client.subscriptionId,
                          ),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          _showWorkspaceSnack(context, 'Program assigned.');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          _showWorkspaceSnack(
                            context,
                            'Program could not be assigned: $error',
                          );
                        }
                      }
                    },
                  ),
                ),
        ],
      ),
    ),
  );
}

Future<void> _openAssignHabitSheet(
  BuildContext context,
  WidgetRef ref,
  CoachClientWorkspaceEntity workspace,
) async {
  final titleController = TextEditingController(text: 'Daily steps');
  final targetController = TextEditingController(text: '8000');
  final unitController = TextEditingController(text: 'steps');
  String unit = 'steps';
  String frequency = 'daily';

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
      child: StatefulBuilder(
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Assign habit',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Habit title'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Target'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: unitController,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    onChanged: (value) =>
                        unit = value.trim().isEmpty ? 'steps' : value.trim(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              ],
              onChanged: (value) =>
                  setSheetState(() => frequency = value ?? 'daily'),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(coachRepositoryProvider)
                        .assignHabits(
                          subscriptionId: workspace.client.subscriptionId,
                          habits: <Map<String, dynamic>>[
                            <String, dynamic>{
                              'title': titleController.text.trim(),
                              'habit_type': 'accountability',
                              'target_value': double.tryParse(
                                targetController.text,
                              ),
                              'target_unit': unit,
                              'frequency': frequency,
                            },
                          ],
                        );
                    ref.invalidate(
                      coachClientWorkspaceProvider(
                        workspace.client.subscriptionId,
                      ),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      _showWorkspaceSnack(context, 'Habit assigned.');
                    }
                  } catch (error) {
                    if (context.mounted) {
                      _showWorkspaceSnack(
                        context,
                        'Habit could not be assigned: $error',
                      );
                    }
                  }
                },
                child: const Text('Assign habit'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  titleController.dispose();
  targetController.dispose();
  unitController.dispose();
}

Future<void> _openAssignResourceSheet(
  BuildContext context,
  WidgetRef ref,
  CoachClientWorkspaceEntity workspace,
) async {
  final resources = await ref.read(coachResourcesProvider.future);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Assign resource',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (resources.isEmpty)
            const _SimplePanel(
              icon: Icons.folder_outlined,
              title: 'No resources available',
              body: 'Upload or create resources first in the resource library.',
            )
          else
            ...resources
                .take(8)
                .map(
                  (resource) => _ListPanel(
                    icon: Icons.attach_file,
                    title: resource.title,
                    subtitle: resource.description.isEmpty
                        ? resource.resourceType
                        : resource.description,
                    actionLabel: 'Assign',
                    onTap: () async {
                      try {
                        await ref
                            .read(coachRepositoryProvider)
                            .assignResourceToClient(
                              subscriptionId: workspace.client.subscriptionId,
                              resourceId: resource.id,
                            );
                        ref.invalidate(
                          coachClientWorkspaceProvider(
                            workspace.client.subscriptionId,
                          ),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          _showWorkspaceSnack(context, 'Resource assigned.');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          _showWorkspaceSnack(
                            context,
                            'Resource could not be assigned: $error',
                          );
                        }
                      }
                    },
                  ),
                ),
        ],
      ),
    ),
  );
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String _dateTimeInput(DateTime value) {
  final local = value.toLocal();
  return '${_date(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

DateTime? _parseDateTimeInput(String value) {
  final normalized = value.trim().replaceFirst(' ', 'T');
  if (normalized.isEmpty) return null;
  return DateTime.tryParse(normalized);
}

Future<DateTime?> _pickDateTime(
  BuildContext context, {
  required DateTime initial,
}) async {
  final now = DateTime.now();
  final initialDate = initial.isBefore(now) ? now : initial;
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: DateTime(now.year + 2),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDate),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String? _textOrNull(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

void _showWorkspaceSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
