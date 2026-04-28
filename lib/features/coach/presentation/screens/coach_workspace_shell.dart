import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/coach_workspace_entity.dart';
import '../providers/coach_providers.dart';
import 'coach_calendar_screen.dart';
import 'coach_checkin_inbox_screen.dart';
import 'coach_client_pipeline_screen.dart';
import 'coach_program_library_screen.dart';

class CoachWorkspaceShell extends ConsumerStatefulWidget {
  const CoachWorkspaceShell({super.key});

  @override
  ConsumerState<CoachWorkspaceShell> createState() =>
      _CoachWorkspaceShellState();
}

class _CoachWorkspaceShellState extends ConsumerState<CoachWorkspaceShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final titles = <String>[
      'Today',
      'Clients',
      'Check-ins',
      'Calendar',
      'Library',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(titles[_index]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (route) => Navigator.pushNamed(context, route),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: AppRoutes.coachProfile,
                child: Text('Profile'),
              ),
              PopupMenuItem(value: AppRoutes.packages, child: Text('Packages')),
              PopupMenuItem(
                value: AppRoutes.coachBilling,
                child: Text('Billing'),
              ),
              PopupMenuItem(
                value: AppRoutes.coachResources,
                child: Text('Resources'),
              ),
              PopupMenuItem(
                value: AppRoutes.coachOnboardingFlows,
                child: Text('Onboarding'),
              ),
              PopupMenuItem(value: AppRoutes.settings, child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          _CoachTodayWorkspace(),
          CoachClientPipelineScreen(embedded: true),
          CoachCheckinInboxScreen(embedded: true),
          CoachCalendarScreen(embedded: true),
          CoachProgramLibraryScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Check-ins',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}

class _CoachTodayWorkspace extends ConsumerWidget {
  const _CoachTodayWorkspace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(coachWorkspaceSummaryProvider);
    final actionsAsync = ref.watch(coachActionItemsProvider);
    final bookingsAsync = ref.watch(coachBookingsProvider);

    Future<void> refresh() async {
      ref.invalidate(coachWorkspaceSummaryProvider);
      ref.invalidate(coachActionItemsProvider);
      ref.invalidate(coachBookingsProvider);
      await Future.wait<dynamic>([
        ref.read(coachWorkspaceSummaryProvider.future),
        ref.read(coachActionItemsProvider.future),
        ref.read(coachBookingsProvider.future),
      ]);
    }

    return RefreshIndicator.adaptive(
      onRefresh: refresh,
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
            'Coach workspace',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Live coaching operations for today.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_business_outlined, size: 18),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.addPackage),
                  label: const Text('Create Package'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.clients),
                  label: const Text('Open Clients'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          summaryAsync.when(
            loading: () => const _LoadingCard(),
            error: (error, _) => _StateCard(
              icon: Icons.cloud_off_outlined,
              title: 'Workspace unavailable',
              body: error.toString(),
              actionLabel: 'Retry',
              onTap: () => ref.invalidate(coachWorkspaceSummaryProvider),
            ),
            data: (summary) => _WorkspaceSummaryGrid(summary: summary),
          ),
          summaryAsync.maybeWhen(
            data: (summary) => summary.packagePerformance.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      const SizedBox(height: 18),
                      _SectionTitle(
                        title: 'Package performance',
                        actionLabel: 'Open billing',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.coachBilling,
                        ),
                      ),
                      ...summary.packagePerformance
                          .take(4)
                          .map(
                            (item) => _ScheduleTile(
                              title: item.title,
                              subtitle:
                                  '${item.activeClients} active · ${item.pendingClients} pending · EGP ${item.revenue.toStringAsFixed(0)}',
                              status: 'Revenue',
                            ),
                          ),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'Today schedule',
            actionLabel: 'Open calendar',
            onTap: () => Navigator.pushNamed(context, AppRoutes.coachCalendar),
          ),
          bookingsAsync.when(
            loading: () => const _LoadingCard(),
            error: (error, _) => _StateCard(
              icon: Icons.event_busy_outlined,
              title: 'Schedule unavailable',
              body: error.toString(),
              actionLabel: 'Retry',
              onTap: () => ref.invalidate(coachBookingsProvider),
            ),
            data: (bookings) {
              final today = DateTime.now();
              final todayBookings = bookings
                  .where(
                    (booking) =>
                        booking.startsAt.year == today.year &&
                        booking.startsAt.month == today.month &&
                        booking.startsAt.day == today.day,
                  )
                  .toList(growable: false);
              if (todayBookings.isEmpty) {
                return _StateCard(
                  icon: Icons.event_available_outlined,
                  title: 'No sessions today',
                  body: 'Availability and bookings stay ready in Calendar.',
                  actionLabel: 'Schedule call',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.coachCalendar),
                );
              }
              return Column(
                children: todayBookings
                    .map(
                      (booking) => _ScheduleTile(
                        title: booking.title,
                        subtitle:
                            '${_time(booking.startsAt)} - ${_time(booking.endsAt)}',
                        status: booking.status.replaceAll('_', ' '),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 18),
          _SectionTitle(
            title: 'Coach alerts',
            actionLabel: 'Clients',
            onTap: () => Navigator.pushNamed(context, AppRoutes.clients),
          ),
          actionsAsync.when(
            loading: () => const _LoadingCard(),
            error: (error, _) => _StateCard(
              icon: Icons.warning_amber_outlined,
              title: 'Alerts unavailable',
              body: error.toString(),
              actionLabel: 'Retry',
              onTap: () => ref.invalidate(coachActionItemsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const _StateCard(
                  icon: Icons.check_circle_outline,
                  title: 'No open alerts',
                  body:
                      'Risk, payment, renewal, and check-in warnings appear here.',
                );
              }
              return Column(
                children: items
                    .map((item) => _ActionItemCard(item: item))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WorkspaceSummaryGrid extends StatelessWidget {
  const _WorkspaceSummaryGrid({required this.summary});

  final CoachWorkspaceEntity summary;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricCardData>[
      _MetricCardData(
        'Today',
        '${summary.todaySessions}',
        'Schedule',
        AppRoutes.coachCalendar,
        Icons.calendar_today_outlined,
      ),
      _MetricCardData(
        'Leads',
        '${summary.newLeads}',
        'Review',
        AppRoutes.clients,
        Icons.person_add_alt_outlined,
      ),
      _MetricCardData(
        'Payments',
        '${summary.pendingPaymentVerifications}',
        'Approve',
        AppRoutes.coachBilling,
        Icons.receipt_long_outlined,
      ),
      _MetricCardData(
        'Active',
        '${summary.activeClients}',
        'Open',
        AppRoutes.clients,
        Icons.groups_outlined,
      ),
      _MetricCardData(
        'At risk',
        '${summary.atRiskClients}',
        'Intervene',
        AppRoutes.clients,
        Icons.troubleshoot_outlined,
      ),
      _MetricCardData(
        'Overdue',
        '${summary.overdueCheckins}',
        'Review',
        AppRoutes.coachCheckins,
        Icons.fact_check_outlined,
      ),
      _MetricCardData(
        'Unread',
        '${summary.unreadMessages}',
        'Messages',
        AppRoutes.clients,
        Icons.mark_chat_unread_outlined,
      ),
      _MetricCardData(
        'Renewals',
        '${summary.renewalsDueSoon}',
        'Renew',
        AppRoutes.clients,
        Icons.autorenew_outlined,
      ),
      _MetricCardData(
        'Revenue',
        'EGP ${summary.revenueMonth.toStringAsFixed(0)}',
        'Billing',
        AppRoutes.coachBilling,
        Icons.payments_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 3 ? 1.55 : 1.25,
          ),
          itemBuilder: (context, index) => _MetricCard(data: cards[index]),
        );
      },
    );
  }
}

class _MetricCardData {
  const _MetricCardData(
    this.label,
    this.value,
    this.action,
    this.route,
    this.icon,
  );

  final String label;
  final String value;
  final String action;
  final String route;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, size: 20, color: AppColors.orange),
          const Spacer(),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, data.route),
              child: Text(data.action),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItemCard extends ConsumerWidget {
  const _ActionItemCard({required this.item});

  final CoachActionItemEntity item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = switch (item.eventType) {
      'payment_pending_too_long' => AppRoutes.coachBilling,
      'missed_checkin' || 'no_recent_checkin' => AppRoutes.coachCheckins,
      'renewal_soon' => AppRoutes.clients,
      _ => AppRoutes.clients,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
              Icon(
                _severityIcon(item.severity),
                color: _severityColor(item.severity),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (item.body.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.body,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (item.subscriptionId != null &&
                        route == AppRoutes.clients) {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.coachClientWorkspace,
                        arguments: CoachClientWorkspaceArgs(
                          subscriptionId: item.subscriptionId!,
                        ),
                      );
                      return;
                    }
                    Navigator.pushNamed(context, route);
                  },
                  child: Text(item.ctaLabel),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: item.id.isEmpty
                    ? null
                    : () async {
                        await ref
                            .read(coachRepositoryProvider)
                            .dismissAutomationEvent(item.id);
                        ref.invalidate(coachActionItemsProvider);
                        ref.invalidate(coachWorkspaceSummaryProvider);
                      },
                icon: const Icon(Icons.done),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

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
          const Icon(Icons.event_available_outlined, color: AppColors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(status, style: GoogleFonts.inter(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onTap});

  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onTap, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
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
      width: double.infinity,
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
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
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
    );
  }
}

String _time(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

IconData _severityIcon(String severity) {
  return switch (severity) {
    'critical' || 'high' => Icons.priority_high,
    'low' => Icons.info_outline,
    _ => Icons.warning_amber_outlined,
  };
}

Color _severityColor(String severity) {
  return switch (severity) {
    'critical' || 'high' => AppColors.error,
    'low' => AppColors.info,
    _ => AppColors.warning,
  };
}
