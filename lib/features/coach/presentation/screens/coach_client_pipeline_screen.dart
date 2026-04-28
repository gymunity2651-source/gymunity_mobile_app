import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/coach_workspace_entity.dart';
import '../providers/coach_providers.dart';

class CoachClientWorkspaceArgs {
  const CoachClientWorkspaceArgs({required this.subscriptionId});

  final String subscriptionId;
}

class CoachClientPipelineScreen extends ConsumerStatefulWidget {
  const CoachClientPipelineScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<CoachClientPipelineScreen> createState() =>
      _CoachClientPipelineScreenState();
}

class _CoachClientPipelineScreenState
    extends ConsumerState<CoachClientPipelineScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'risk';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pipelineAsync = ref.watch(coachClientPipelineProvider);
    final filter = ref.watch(coachClientPipelineFilterProvider);

    final content = RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(coachClientPipelineProvider);
        await ref.read(coachClientPipelineProvider.future);
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
            'Client pipeline',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search client, package, goal',
              suffixIcon: IconButton(
                tooltip: 'Apply filters',
                icon: const Icon(Icons.tune),
                onPressed: () => _openFilters(context, filter),
              ),
            ),
            onSubmitted: (value) => _setFilter(search: value),
          ),
          const SizedBox(height: 12),
          _StageSelector(
            selected: filter.pipelineStage,
            onSelected: (stage) => _setFilter(pipelineStage: stage),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _FilterSummary(filter: filter)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sortBy,
                items: const [
                  DropdownMenuItem(value: 'risk', child: Text('Risk')),
                  DropdownMenuItem(value: 'start', child: Text('Start')),
                  DropdownMenuItem(value: 'renewal', child: Text('Renewal')),
                ],
                onChanged: (value) => setState(() => _sortBy = value ?? 'risk'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          pipelineAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _PipelineState(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load clients',
              body: error.toString(),
              actionLabel: 'Retry',
              onTap: () => ref.invalidate(coachClientPipelineProvider),
            ),
            data: (entries) {
              final sorted = entries.toList(growable: false)..sort(_sort);
              if (sorted.isEmpty) {
                return _PipelineState(
                  icon: Icons.people_outline,
                  title: 'No clients in this view',
                  body: 'New leads and managed subscriptions appear here.',
                  actionLabel: 'Clear filters',
                  onTap: () {
                    _searchController.clear();
                    ref.read(coachClientPipelineFilterProvider.notifier).state =
                        const CoachClientPipelineFilter();
                  },
                );
              }
              return Column(
                children: sorted
                    .map((entry) => _ClientPipelineCard(entry: entry))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Clients'),
        backgroundColor: AppColors.background,
      ),
      body: content,
    );
  }

  int _sort(CoachClientPipelineEntry a, CoachClientPipelineEntry b) {
    switch (_sortBy) {
      case 'start':
        return (b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      case 'renewal':
        return (a.nextRenewalAt ?? DateTime(9999)).compareTo(
          b.nextRenewalAt ?? DateTime(9999),
        );
      default:
        final riskRank = <String, int>{'critical': 0, 'at_risk': 1, 'none': 2};
        return (riskRank[a.riskStatus] ?? 3).compareTo(
          riskRank[b.riskStatus] ?? 3,
        );
    }
  }

  void _setFilter({
    Object? pipelineStage = _unset,
    Object? search = _unset,
    Object? goal = _unset,
    Object? packageId = _unset,
    Object? city = _unset,
    Object? gender = _unset,
    Object? language = _unset,
    Object? startDateFrom = _unset,
    Object? startDateTo = _unset,
    Object? renewalStatus = _unset,
    Object? riskStatus = _unset,
  }) {
    final current = ref.read(coachClientPipelineFilterProvider);
    ref
        .read(coachClientPipelineFilterProvider.notifier)
        .state = CoachClientPipelineFilter(
      pipelineStage: pipelineStage == _unset
          ? current.pipelineStage
          : pipelineStage as String?,
      search: search == _unset ? current.search : search as String?,
      goal: goal == _unset ? current.goal : goal as String?,
      packageId: packageId == _unset ? current.packageId : packageId as String?,
      city: city == _unset ? current.city : city as String?,
      gender: gender == _unset ? current.gender : gender as String?,
      language: language == _unset ? current.language : language as String?,
      startDateFrom: startDateFrom == _unset
          ? current.startDateFrom
          : startDateFrom as DateTime?,
      startDateTo: startDateTo == _unset
          ? current.startDateTo
          : startDateTo as DateTime?,
      renewalStatus: renewalStatus == _unset
          ? current.renewalStatus
          : renewalStatus as String?,
      riskStatus: riskStatus == _unset
          ? current.riskStatus
          : riskStatus as String?,
    );
  }

  Future<void> _openFilters(
    BuildContext context,
    CoachClientPipelineFilter current,
  ) async {
    final goalController = TextEditingController(text: current.goal ?? '');
    final packageController = TextEditingController(
      text: current.packageId ?? '',
    );
    final cityController = TextEditingController(text: current.city ?? '');
    final languageController = TextEditingController(
      text: current.language ?? '',
    );
    String? gender = current.gender;
    String? risk = current.riskStatus;
    String? renewal = current.renewalStatus;
    DateTime? startDateFrom = current.startDateFrom;
    DateTime? startDateTo = current.startDateTo;

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
                      'Filters',
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
                controller: goalController,
                decoration: const InputDecoration(labelText: 'Goal'),
              ),
              TextField(
                controller: packageController,
                decoration: const InputDecoration(
                  labelText: 'Package id or keyword',
                ),
              ),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              TextField(
                controller: languageController,
                decoration: const InputDecoration(labelText: 'Language'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.date_range_outlined, size: 18),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: startDateFrom ?? DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => startDateFrom = picked);
                        }
                      },
                      label: Text(
                        startDateFrom == null
                            ? 'Start from'
                            : _date(startDateFrom!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.event_available_outlined,
                        size: 18,
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: startDateTo ?? DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() => startDateTo = picked);
                        }
                      },
                      label: Text(
                        startDateTo == null ? 'Start to' : _date(startDateTo!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Any')),
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text('Female'),
                        ),
                      ],
                      onChanged: (value) => setSheetState(() => gender = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: risk,
                      decoration: const InputDecoration(labelText: 'Risk'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Any')),
                        DropdownMenuItem(
                          value: 'at_risk',
                          child: Text('At risk'),
                        ),
                        DropdownMenuItem(
                          value: 'critical',
                          child: Text('Critical'),
                        ),
                        DropdownMenuItem(value: 'none', child: Text('None')),
                      ],
                      onChanged: (value) => setSheetState(() => risk = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: renewal,
                decoration: const InputDecoration(labelText: 'Renewal'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any')),
                  DropdownMenuItem(value: 'due_soon', child: Text('Due soon')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                  DropdownMenuItem(value: 'none', child: Text('No date')),
                ],
                onChanged: (value) => setSheetState(() => renewal = value),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref
                                .read(
                                  coachClientPipelineFilterProvider.notifier,
                                )
                                .state =
                            const CoachClientPipelineFilter();
                        _searchController.clear();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _setFilter(
                          goal: _textOrNull(goalController.text),
                          packageId: _textOrNull(packageController.text),
                          city: _textOrNull(cityController.text),
                          language: _textOrNull(languageController.text),
                          gender: gender,
                          startDateFrom: startDateFrom,
                          startDateTo: startDateTo,
                          riskStatus: risk,
                          renewalStatus: renewal,
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageSelector extends StatelessWidget {
  const _StageSelector({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    const stages = <String?, String>{
      null: 'All',
      'lead': 'Leads',
      'pending_payment': 'Payment',
      'active': 'Active',
      'at_risk': 'At risk',
      'paused': 'Paused',
      'archived': 'Archived',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: stages.entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected == entry.key,
                  label: Text(entry.value),
                  onSelected: (_) => onSelected(entry.key),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({required this.filter});

  final CoachClientPipelineFilter filter;

  @override
  Widget build(BuildContext context) {
    final active = <String>[
      if (filter.goal != null) 'Goal: ${filter.goal}',
      if (filter.packageId != null) 'Pkg: ${filter.packageId}',
      if (filter.city != null) 'City: ${filter.city}',
      if (filter.gender != null) 'Gender: ${filter.gender}',
      if (filter.language != null) 'Lang: ${filter.language}',
      if (filter.startDateFrom != null) 'From: ${_date(filter.startDateFrom!)}',
      if (filter.startDateTo != null) 'To: ${_date(filter.startDateTo!)}',
      if (filter.renewalStatus != null) 'Renewal: ${filter.renewalStatus}',
      if (filter.riskStatus != null) 'Risk: ${filter.riskStatus}',
    ];
    return Text(
      active.isEmpty ? 'All live subscriptions' : active.join('  '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
    );
  }
}

class _ClientPipelineCard extends ConsumerWidget {
  const _ClientPipelineCard({required this.entry});

  final CoachClientPipelineEntry entry;

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
              CircleAvatar(
                backgroundColor: AppColors.orange.withValues(alpha: 0.12),
                child: Text(
                  entry.memberName.isEmpty
                      ? '?'
                      : entry.memberName.characters.first.toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.memberName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      entry.packageTitle ?? 'Coaching',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _PipelineBadge(label: entry.pipelineStage.replaceAll('_', ' ')),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(label: entry.status.replaceAll('_', ' ')),
              _MiniChip(label: 'Internal ${entry.internalStatus}'),
              if (entry.goal != null) _MiniChip(label: entry.goal!),
              if (entry.city != null) _MiniChip(label: entry.city!),
              if (entry.language != null) _MiniChip(label: entry.language!),
              if (entry.nextRenewalAt != null)
                _MiniChip(label: 'Renews ${_date(entry.nextRenewalAt!)}'),
              if (entry.unreadMessages > 0)
                _MiniChip(label: '${entry.unreadMessages} unread'),
              ...entry.tags.map((tag) => _MiniChip(label: '#$tag')),
            ],
          ),
          if (entry.riskFlags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.riskFlags
                  .map((flag) => _RiskChip(label: flag.replaceAll('_', ' ')))
                  .toList(growable: false),
            ),
          ],
          if (entry.coachNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              entry.coachNotes,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (entry.status == 'pending_payment' ||
              entry.status == 'pending_activation') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
                onPressed: () async {
                  await ref
                      .read(coachRepositoryProvider)
                      .activateSubscriptionWithStarterPlan(
                        subscriptionId: entry.subscriptionId,
                      );
                  ref.invalidate(coachClientPipelineProvider);
                  ref.invalidate(coachWorkspaceSummaryProvider);
                },
                label: const Text('Assign starter plan'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Manage CRM record',
                onPressed: () => _openManageSheet(context, ref, entry),
                icon: const Icon(Icons.edit_note_outlined),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.coachClientWorkspace,
                    arguments: CoachClientWorkspaceArgs(
                      subscriptionId: entry.subscriptionId,
                    ),
                  ),
                  label: const Text('Open client'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: entry.isPendingPayment
                    ? 'Review payment'
                    : 'Schedule call',
                onPressed: () => Navigator.pushNamed(
                  context,
                  entry.isPendingPayment
                      ? AppRoutes.coachBilling
                      : AppRoutes.coachCalendar,
                ),
                icon: Icon(
                  entry.isPendingPayment
                      ? Icons.receipt_long_outlined
                      : Icons.event_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openManageSheet(
    BuildContext context,
    WidgetRef ref,
    CoachClientPipelineEntry entry,
  ) async {
    final notesController = TextEditingController(text: entry.coachNotes);
    final tagsController = TextEditingController(text: entry.tags.join(', '));
    final languageController = TextEditingController(
      text: entry.language ?? '',
    );
    String pipelineStage = entry.pipelineStage;
    String internalStatus = entry.internalStatus;
    String riskStatus = entry.riskStatus;
    DateTime? followUpAt = entry.nextRenewalAt;

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
                      'Client CRM',
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
              DropdownButtonFormField<String>(
                initialValue: pipelineStage,
                decoration: const InputDecoration(labelText: 'Pipeline stage'),
                items: const [
                  DropdownMenuItem(value: 'lead', child: Text('Lead')),
                  DropdownMenuItem(
                    value: 'pending_payment',
                    child: Text('Pending payment'),
                  ),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'at_risk', child: Text('At risk')),
                  DropdownMenuItem(value: 'paused', child: Text('Paused')),
                  DropdownMenuItem(
                    value: 'archived',
                    child: Text('Completed / archived'),
                  ),
                ],
                onChanged: (value) =>
                    setSheetState(() => pipelineStage = value ?? 'lead'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: languageController,
                      decoration: const InputDecoration(
                        labelText: 'Preferred language',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: riskStatus,
                      decoration: const InputDecoration(labelText: 'Risk'),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None')),
                        DropdownMenuItem(
                          value: 'at_risk',
                          child: Text('At risk'),
                        ),
                        DropdownMenuItem(
                          value: 'critical',
                          child: Text('Critical'),
                        ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => riskStatus = value ?? 'none'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: internalStatus,
                decoration: const InputDecoration(labelText: 'Internal status'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'new', child: Text('New')),
                  DropdownMenuItem(
                    value: 'follow_up',
                    child: Text('Follow-up'),
                  ),
                  DropdownMenuItem(value: 'engaged', child: Text('Engaged')),
                  DropdownMenuItem(
                    value: 'watchlist',
                    child: Text('Watchlist'),
                  ),
                  DropdownMenuItem(
                    value: 'renewal_watch',
                    child: Text('Renewal watch'),
                  ),
                ],
                onChanged: (value) =>
                    setSheetState(() => internalStatus = value ?? 'new'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'fat loss, high touch, evening',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Coach notes',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_outlined, size: 18),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: followUpAt ?? DateTime.now(),
                    );
                    if (picked != null) {
                      setSheetState(() => followUpAt = picked);
                    }
                  },
                  label: Text(
                    followUpAt == null
                        ? 'Set follow-up date'
                        : 'Follow-up ${_date(followUpAt!)}',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(coachRepositoryProvider)
                        .saveClientRecord(
                          subscriptionId: entry.subscriptionId,
                          pipelineStage: pipelineStage,
                          internalStatus: internalStatus,
                          riskStatus: riskStatus,
                          tags: _tags(tagsController.text),
                          coachNotes: _textOrNull(notesController.text),
                          preferredLanguage: _textOrNull(
                            languageController.text,
                          ),
                          followUpAt: followUpAt,
                        );
                    ref.invalidate(coachClientPipelineProvider);
                    ref.invalidate(
                      coachClientWorkspaceProvider(entry.subscriptionId),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save CRM updates'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    notesController.dispose();
    tagsController.dispose();
    languageController.dispose();
  }
}

class _PipelineBadge extends StatelessWidget {
  const _PipelineBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.orange,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

class _RiskChip extends StatelessWidget {
  const _RiskChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.warning_amber_outlined, size: 16),
      label: Text(label),
      backgroundColor: AppColors.warning.withValues(alpha: 0.12),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PipelineState extends StatelessWidget {
  const _PipelineState({
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
    );
  }
}

const Object _unset = Object();

String? _textOrNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _tags(String value) => value
    .split(',')
    .map((tag) => tag.trim())
    .where((tag) => tag.isNotEmpty)
    .toList(growable: false);

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
