import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/admin_entities.dart';
import '../providers/admin_providers.dart';

class AdminAccessGate extends ConsumerWidget {
  const AdminAccessGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final adminAsync = ref.watch(currentAdminProvider);

    if (session == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _CenteredState(
          icon: Icons.lock_outline,
          title: 'Admin sign-in required',
          body: 'Sign in before opening the GymUnity admin dashboard.',
          actionLabel: 'Go to login',
          onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
        ),
      );
    }

    return adminAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: _CenteredState(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Access denied',
          body: error.toString(),
          actionLabel: 'Retry',
          onTap: () => ref.invalidate(currentAdminProvider),
        ),
      ),
      data: (admin) {
        if (admin == null || !admin.isActive) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: _CenteredState(
              icon: Icons.no_accounts_outlined,
              title: 'Access denied',
              body:
                  'This account is not a GymUnity admin. Admins are granted manually by Supabase.',
            ),
          );
        }
        return AdminDashboardShell(admin: admin);
      },
    );
  }
}

class AdminDashboardShell extends ConsumerStatefulWidget {
  const AdminDashboardShell({super.key, required this.admin});

  final AdminUserEntity admin;

  @override
  ConsumerState<AdminDashboardShell> createState() =>
      _AdminDashboardShellState();
}

class _AdminDashboardShellState extends ConsumerState<AdminDashboardShell> {
  var _index = 0;

  static const _sections = <_AdminSection>[
    _AdminSection('Overview', Icons.dashboard_outlined, shortLabel: 'Home'),
    _AdminSection('Payments', Icons.receipt_long_outlined, shortLabel: 'Pay'),
    _AdminSection(
      'Payouts',
      Icons.account_balance_wallet_outlined,
      shortLabel: 'Payouts',
    ),
    _AdminSection('Coaches', Icons.groups_outlined, shortLabel: 'Coaches'),
    _AdminSection('Subscriptions', Icons.link_outlined, shortLabel: 'Subs'),
    _AdminSection('Audit Log', Icons.history_outlined, shortLabel: 'Audit'),
    _AdminSection('Settings', Icons.tune_outlined, shortLabel: 'Config'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 860;
    final body = RefreshIndicator.adaptive(
      onRefresh: _refreshCurrent,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
              child: _Header(
                title: _sections[_index].label,
                adminRole: widget.admin.role,
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _sectionBody(),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('GymUnity Admin'),
      ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelType: NavigationRailLabelType.all,
              destinations: _sections
                  .map(
                    (section) => NavigationRailDestination(
                      icon: Icon(section.icon),
                      label: Text(section.label),
                    ),
                  )
                  .toList(growable: false),
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : _AdminMobileNav(
              sections: _sections,
              selectedIndex: _index,
              onSelected: (value) => setState(() => _index = value),
            ),
    );
  }

  Widget _sectionBody() {
    switch (_index) {
      case 0:
        return const _OverviewSection();
      case 1:
        return const _PaymentsSection();
      case 2:
        return _PayoutsSection(admin: widget.admin);
      case 3:
        return const _CoachesSection();
      case 4:
        return const _SubscriptionsSection();
      case 5:
        return const _AuditSection();
      case 6:
        return const _SettingsSection();
      default:
        return const _OverviewSection();
    }
  }

  Future<void> _refreshCurrent() async {
    switch (_index) {
      case 0:
        ref.invalidate(adminDashboardSummaryProvider);
      case 1:
        ref.invalidate(adminPaymentOrdersProvider);
      case 2:
        ref.invalidate(adminPayoutsProvider);
      case 3:
        ref.invalidate(adminCoachBalancesProvider);
      case 4:
        ref.invalidate(adminSubscriptionsProvider);
      case 5:
        ref.invalidate(adminAuditEventsProvider);
      case 6:
        ref.invalidate(adminSettingsProvider);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

class _AdminMobileNav extends StatelessWidget {
  const _AdminMobileNav({
    required this.sections,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_AdminSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < sections.length; i++)
                _AdminMobileNavItem(
                  section: sections[i],
                  selected: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminMobileNavItem extends StatelessWidget {
  const _AdminMobileNavItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _AdminSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.orange : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: selected
            ? AppColors.orange.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 74,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.orange.withValues(alpha: 0.32)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(section.icon, size: 20, color: color),
                const SizedBox(height: 4),
                Text(
                  section.shortLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                    height: 1.05,
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

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(adminDashboardSummaryProvider);
    return summaryAsync.when(
      loading: () => const _LoadingPanel(),
      error: (error, _) => _ErrorPanel(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminDashboardSummaryProvider),
      ),
      data: (summary) {
        final cards = <Widget>[
          _KpiCard(
            label: 'Total paid',
            value: formatAdminMoney(
              (summary.paymentKpis['total_paid_amount_cents'] ?? 0).toInt(),
            ),
          ),
          _KpiCard(
            label: 'Payments today',
            value: '${summary.paymentKpis['payments_today'] ?? 0}',
          ),
          _KpiCard(
            label: 'Pending payments',
            value: '${summary.paymentKpis['pending_payments'] ?? 0}',
          ),
          _KpiCard(
            label: 'Failed payments',
            value: '${summary.paymentKpis['failed_payments'] ?? 0}',
          ),
          _KpiCard(
            label: 'Pending payouts',
            value: '${summary.payoutKpis['pending_coach_payouts'] ?? 0}',
          ),
          _KpiCard(
            label: 'Coach net payable',
            value: formatAdminMoney(
              (summary.payoutKpis['total_coach_net_payable_cents'] ?? 0)
                  .toInt(),
            ),
          ),
          _KpiCard(
            label: 'Platform fees',
            value: formatAdminMoney(
              (summary.payoutKpis['platform_fees_earned_cents'] ?? 0).toInt(),
            ),
          ),
          _KpiCard(
            label: 'HMAC failures',
            value: '${summary.operationalKpis['hmac_failures'] ?? 0}',
          ),
        ];

        return ListView(
          children: [
            _ResponsiveGrid(children: cards),
            const SizedBox(height: 18),
            _Panel(
              title: 'Recent successful payments',
              child: _PaymentList(payments: summary.successfulPayments),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: 'Recent failed payments',
              child: _PaymentList(payments: summary.failedPayments),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: 'Alerts',
              child: Column(
                children: summary.alerts.entries
                    .map(
                      (entry) => ListTile(
                        dense: true,
                        leading: Icon(
                          entry.value.isEmpty
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_outlined,
                          color: entry.value.isEmpty
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                        title: Text(entry.key.replaceAll('_', ' ')),
                        trailing: Text('${entry.value.length}'),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PaymentsSection extends ConsumerWidget {
  const _PaymentsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(adminPaymentOrdersProvider);
    return Column(
      children: [
        _FilterBar(
          statusValue: ref.watch(adminPaymentStatusFilterProvider),
          statusOptions: const [
            'created',
            'pending',
            'paid',
            'failed',
            'cancelled',
            'refunded',
          ],
          searchHint: 'Search client, coach, package, reference',
          onStatusChanged: (value) =>
              ref.read(adminPaymentStatusFilterProvider.notifier).state = value,
          onSearchChanged: (value) =>
              ref.read(adminPaymentSearchProvider.notifier).state = value,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ordersAsync.when(
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: error.toString(),
              onRetry: () => ref.invalidate(adminPaymentOrdersProvider),
            ),
            data: (orders) => _PaymentList(
              payments: orders,
              onTap: (order) => _showPaymentDetails(context, ref, order.id),
            ),
          ),
        ),
      ],
    );
  }
}

class _PayoutsSection extends ConsumerWidget {
  const _PayoutsSection({required this.admin});

  final AdminUserEntity admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutsAsync = ref.watch(adminPayoutsProvider);
    return Column(
      children: [
        _FilterBar(
          statusValue: ref.watch(adminPayoutStatusFilterProvider),
          statusOptions: const [
            'pending',
            'on_hold',
            'ready',
            'processing',
            'paid',
            'failed',
            'cancelled',
          ],
          searchHint: 'Search coach or payout reference',
          onStatusChanged: (value) =>
              ref.read(adminPayoutStatusFilterProvider.notifier).state = value,
          onSearchChanged: (value) =>
              ref.read(adminPayoutSearchProvider.notifier).state = value,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: payoutsAsync.when(
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: error.toString(),
              onRetry: () => ref.invalidate(adminPayoutsProvider),
            ),
            data: (payouts) {
              if (payouts.isEmpty) {
                return const _EmptyPanel(title: 'No payouts found');
              }
              return ListView.builder(
                itemCount: payouts.length,
                itemBuilder: (context, index) {
                  final payout = payouts[index];
                  return _AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                payout.coachName,
                                style: _titleStyle(),
                              ),
                            ),
                            _StatusChip(label: payout.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(payout.amountLabel),
                            _InfoChip('${payout.itemCount} items'),
                            _InfoChip(payout.method),
                            if (payout.externalReference != null)
                              _InfoChip(payout.externalReference!),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _showPayoutDetails(context, ref, payout.id),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Details'),
                            ),
                            if (admin.canWritePayouts &&
                                payout.status == 'pending')
                              OutlinedButton(
                                onPressed: () => _confirmSimpleAction(
                                  context,
                                  title: 'Mark payout ready',
                                  label: 'Mark ready',
                                  onSubmit: (note) => ref
                                      .read(adminActionsControllerProvider)
                                      .markPayoutReady(payout.id, note: note),
                                ),
                                child: const Text('Mark ready'),
                              ),
                            if (admin.canWritePayouts &&
                                payout.status != 'paid' &&
                                payout.status != 'on_hold')
                              OutlinedButton(
                                onPressed: () => _confirmSimpleAction(
                                  context,
                                  title: 'Put payout on hold',
                                  label: 'Put on hold',
                                  requireText: true,
                                  onSubmit: (reason) => ref
                                      .read(adminActionsControllerProvider)
                                      .holdPayout(payout.id, reason),
                                ),
                                child: const Text('Hold'),
                              ),
                            if (admin.canWritePayouts &&
                                payout.status == 'on_hold')
                              OutlinedButton(
                                onPressed: () => ref
                                    .read(adminActionsControllerProvider)
                                    .releasePayout(payout.id),
                                child: const Text('Release hold'),
                              ),
                            if (admin.canWritePayouts &&
                                payout.status == 'ready')
                              OutlinedButton(
                                onPressed: () => ref
                                    .read(adminActionsControllerProvider)
                                    .markPayoutProcessing(payout.id),
                                child: const Text('Processing'),
                              ),
                            if (admin.canMarkPayoutPaid)
                              ElevatedButton.icon(
                                onPressed: payout.canMarkPaid
                                    ? () => _openMarkPaidDialog(
                                        context,
                                        ref,
                                        payout,
                                      )
                                    : null,
                                icon: const Icon(
                                  Icons.verified_outlined,
                                  size: 18,
                                ),
                                label: const Text('Mark paid'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CoachesSection extends ConsumerWidget {
  const _CoachesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(adminCoachBalancesProvider);
    return Column(
      children: [
        _SearchField(
          hint: 'Search coach',
          onChanged: (value) =>
              ref.read(adminCoachSearchProvider.notifier).state = value,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: balancesAsync.when(
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: error.toString(),
              onRetry: () => ref.invalidate(adminCoachBalancesProvider),
            ),
            data: (coaches) => ListView(
              children: coaches
                  .map(
                    (coach) => _AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(coach.coachName, style: _titleStyle()),
                          Text(
                            coach.coachEmail ?? '',
                            style: _secondaryStyle(),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _InfoChip(
                                '${coach.activeClientsCount} active clients',
                              ),
                              _InfoChip(
                                'Paid ${formatAdminMoney(coach.totalPaidClientPaymentsCents)}',
                              ),
                              _InfoChip(
                                'Net ${formatAdminMoney(coach.totalCoachNetEarnedCents)}',
                              ),
                              _InfoChip(
                                'Pending ${formatAdminMoney(coach.pendingPayoutAmountCents)}',
                              ),
                              _InfoChip(
                                'Account ${coach.payoutAccount['is_verified'] == true ? 'verified' : 'unverified'}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubscriptionsSection extends ConsumerWidget {
  const _SubscriptionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(adminSubscriptionsProvider);
    return Column(
      children: [
        _FilterBar(
          statusValue: ref.watch(adminSubscriptionStatusFilterProvider),
          statusOptions: const [
            'active',
            'checkout_pending',
            'paused',
            'completed',
            'cancelled',
          ],
          searchHint: 'Search subscription, coach, client, package',
          onStatusChanged: (value) =>
              ref.read(adminSubscriptionStatusFilterProvider.notifier).state =
                  value,
          onSearchChanged: (value) =>
              ref.read(adminSubscriptionSearchProvider.notifier).state = value,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: subscriptionsAsync.when(
            loading: () => const _LoadingPanel(),
            error: (error, _) => _ErrorPanel(
              message: error.toString(),
              onRetry: () => ref.invalidate(adminSubscriptionsProvider),
            ),
            data: (subscriptions) => ListView(
              children: subscriptions
                  .map(
                    (subscription) => _AdminCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subscription.packageTitle,
                                  style: _titleStyle(),
                                ),
                                Text(
                                  '${subscription.memberName} -> ${subscription.coachName}',
                                  style: _secondaryStyle(),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _StatusChip(label: subscription.status),
                                    _InfoChip(subscription.checkoutStatus),
                                    _InfoChip(
                                      subscription.threadExists
                                          ? 'Thread exists'
                                          : 'No thread',
                                    ),
                                    if (subscription.payoutStatus != null)
                                      _InfoChip(
                                        'Payout ${subscription.payoutStatus}',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed:
                                subscription.status == 'active' &&
                                    !subscription.threadExists
                                ? () => _confirmRepairThread(
                                    context,
                                    ref,
                                    subscription.subscriptionId,
                                  )
                                : null,
                            child: const Text('Ensure thread'),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditSection extends ConsumerWidget {
  const _AuditSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(adminAuditEventsProvider);
    return auditAsync.when(
      loading: () => const _LoadingPanel(),
      error: (error, _) => _ErrorPanel(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminAuditEventsProvider),
      ),
      data: (events) {
        if (events.isEmpty) return const _EmptyPanel(title: 'No audit events');
        return ListView(
          children: events
              .map(
                (event) => _AdminCard(
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(event.action.replaceAll('_', ' ')),
                    subtitle: Text(
                      '${event.actorName ?? 'Admin'} | ${event.targetType}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Copy event id',
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: event.id)),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          const JsonEncoder.withIndent(
                            '  ',
                          ).convert(event.metadata),
                          style: GoogleFonts.robotoMono(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(adminSettingsProvider);
    return settingsAsync.when(
      loading: () => const _LoadingPanel(),
      error: (error, _) => _ErrorPanel(
        message: error.toString(),
        onRetry: () => ref.invalidate(adminSettingsProvider),
      ),
      data: (settings) => ListView(
        children: [
          _Panel(
            title: 'Payment configuration',
            child: Column(
              children: [
                _DetailRow('Payment mode', settings.mode.toUpperCase()),
                _DetailRow('Currency', settings.currency),
                _DetailRow('Platform fee bps', '${settings.platformFeeBps}'),
                _DetailRow('Payout hold days', '${settings.payoutHoldDays}'),
                _DetailRow('Paymob API base URL', settings.apiBaseUrl),
                _DetailRow(
                  'Notification URL',
                  _yes(settings.notificationUrlConfigured),
                ),
                _DetailRow(
                  'Redirection URL',
                  _yes(settings.redirectionUrlConfigured),
                ),
                _DetailRow(
                  'Test integration IDs',
                  _yes(settings.testIntegrationIdsConfigured),
                ),
                _DetailRow(
                  'Secret key configured',
                  _yes(settings.secretKeyConfigured),
                ),
                _DetailRow(
                  'HMAC key configured',
                  _yes(settings.hmacKeyConfigured),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showPaymentDetails(
  BuildContext context,
  WidgetRef ref,
  String paymentOrderId,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PaymentDetailsSheet(paymentOrderId: paymentOrderId),
  );
}

class _PaymentDetailsSheet extends ConsumerWidget {
  const _PaymentDetailsSheet({required this.paymentOrderId});

  final String paymentOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(
      adminPaymentOrderDetailsProvider(paymentOrderId),
    );
    final admin = ref.watch(adminPermissionsProvider);
    return _SheetFrame(
      title: 'Payment details',
      child: detailsAsync.when(
        loading: () => const _LoadingPanel(),
        error: (error, _) => _ErrorPanel(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(adminPaymentOrderDetailsProvider(paymentOrderId)),
        ),
        data: (order) => ListView(
          shrinkWrap: true,
          children: [
            _DetailRow('Reference', order.specialReference ?? order.id),
            _DetailRow(
              'Client',
              '${order.memberName} ${order.memberEmail ?? ''}',
            ),
            _DetailRow('Coach', '${order.coachName} ${order.coachEmail ?? ''}'),
            _DetailRow('Package', order.packageTitle),
            _DetailRow('Amount', order.amountLabel),
            _DetailRow(
              'Platform fee',
              formatAdminMoney(order.platformFeeCents),
            ),
            _DetailRow('Coach net', formatAdminMoney(order.coachNetCents)),
            _DetailRow('Payment status', order.status),
            _DetailRow('Subscription status', order.subscriptionStatus ?? '-'),
            _DetailRow('Paymob order', order.paymobOrderId ?? '-'),
            _DetailRow('Paymob transaction', order.paymobTransactionId ?? '-'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(adminActionsControllerProvider)
                  .reconcilePayment(order.id),
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Refresh / reconcile'),
            ),
            if (admin?.canWritePayments == true &&
                (order.status == 'created' || order.status == 'pending')) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _confirmSimpleAction(
                  context,
                  title: 'Cancel unpaid checkout',
                  label: 'Cancel checkout',
                  requireText: true,
                  onSubmit: (reason) async {
                    await ref
                        .read(adminActionsControllerProvider)
                        .cancelUnpaidCheckout(order.id, reason);
                    ref.invalidate(
                      adminPaymentOrderDetailsProvider(paymentOrderId),
                    );
                  },
                ),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel checkout'),
              ),
            ],
            if (order.transactions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Webhook timeline', style: _titleStyle()),
              ...order.transactions.map(
                (transaction) => ListTile(
                  dense: true,
                  leading: Icon(
                    transaction.hmacVerified
                        ? Icons.verified_user_outlined
                        : Icons.gpp_bad_outlined,
                  ),
                  title: Text(transaction.processingResult ?? 'received'),
                  subtitle: Text(
                    'HMAC ${transaction.hmacVerified ? 'verified' : 'failed'}',
                  ),
                ),
              ),
            ],
            if (admin?.canViewRawPayload == true &&
                order.rawCreateIntentionResponse != null) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Raw Paymob payload'),
                children: [
                  SelectableText(
                    const JsonEncoder.withIndent(
                      '  ',
                    ).convert(order.rawCreateIntentionResponse),
                    style: GoogleFonts.robotoMono(fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showPayoutDetails(
  BuildContext context,
  WidgetRef ref,
  String payoutId,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PayoutDetailsSheet(payoutId: payoutId),
  );
}

class _PayoutDetailsSheet extends ConsumerWidget {
  const _PayoutDetailsSheet({required this.payoutId});

  final String payoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutAsync = ref.watch(adminPayoutDetailsProvider(payoutId));
    return _SheetFrame(
      title: 'Payout details',
      child: payoutAsync.when(
        loading: () => const _LoadingPanel(),
        error: (error, _) => _ErrorPanel(
          message: error.toString(),
          onRetry: () => ref.invalidate(adminPayoutDetailsProvider(payoutId)),
        ),
        data: (payout) => ListView(
          shrinkWrap: true,
          children: [
            _DetailRow('Coach', payout.coachName),
            _DetailRow('Amount', payout.amountLabel),
            _DetailRow('Status', payout.status),
            _DetailRow('Method', payout.method),
            _DetailRow('External reference', payout.externalReference ?? '-'),
            _DetailRow('Admin note', payout.adminNote ?? '-'),
            _DetailRow(
              'Payout account',
              payout.account.isEmpty
                  ? 'Missing'
                  : 'Masked ${payout.account['method'] ?? 'manual'} | verified ${payout.account['is_verified'] == true ? 'yes' : 'no'}',
            ),
            const SizedBox(height: 12),
            Text('Included payments', style: _titleStyle()),
            ...payout.items.map(
              (item) => ListTile(
                dense: true,
                title: Text(
                  item.paymentOrder?.packageTitle ?? item.paymentOrderId,
                ),
                subtitle: Text(
                  'Gross ${formatAdminMoney(item.grossCents)} | Net ${formatAdminMoney(item.coachNetCents)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openMarkPaidDialog(
  BuildContext context,
  WidgetRef ref,
  AdminPayoutEntity payout,
) async {
  final referenceController = TextEditingController();
  final noteController = TextEditingController();
  var method = payout.method == 'manual' ? 'instapay' : payout.method;
  var confirmed = false;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Mark payout paid'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('I confirm this coach has been paid outside GymUnity.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: const [
                  DropdownMenuItem(value: 'manual', child: Text('Manual')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                  DropdownMenuItem(value: 'instapay', child: Text('Instapay')),
                ],
                onChanged: (value) => setState(() => method = value ?? method),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'External reference',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Admin note'),
              ),
              CheckboxListTile(
                value: confirmed,
                contentPadding: EdgeInsets.zero,
                title: const Text('Coach was paid outside GymUnity'),
                onChanged: (value) =>
                    setState(() => confirmed = value ?? false),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: confirmed && referenceController.text.trim().isNotEmpty
                ? () async {
                    await ref
                        .read(adminActionsControllerProvider)
                        .markPayoutPaid(
                          payoutId: payout.id,
                          method: method,
                          externalReference: referenceController.text.trim(),
                          adminNote: noteController.text.trim(),
                        );
                    if (context.mounted) Navigator.pop(context);
                  }
                : null,
            child: const Text('Mark paid'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _confirmSimpleAction(
  BuildContext context, {
  required String title,
  required String label,
  required Future<void> Function(String note) onSubmit,
  bool requireText = false,
}) async {
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(labelText: requireText ? 'Reason' : 'Note'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final text = controller.text.trim();
            if (requireText && text.isEmpty) return;
            await onSubmit(text);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(label),
        ),
      ],
    ),
  );
}

Future<void> _confirmRepairThread(
  BuildContext context,
  WidgetRef ref,
  String subscriptionId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ensure missing thread'),
      content: const Text(
        'This will re-run the server-side thread creation for an active subscription and write an audit event.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Ensure thread'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref
        .read(adminActionsControllerProvider)
        .ensureSubscriptionThread(subscriptionId);
  }
}

class _PaymentList extends StatelessWidget {
  const _PaymentList({required this.payments, this.onTap});

  final List<AdminPaymentOrderEntity> payments;
  final ValueChanged<AdminPaymentOrderEntity>? onTap;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) return const _EmptyPanel(title: 'No payments found');
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        return _AdminCard(
          child: InkWell(
            onTap: onTap == null ? null : () => onTap!(payment),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(payment.packageTitle, style: _titleStyle()),
                      const SizedBox(height: 4),
                      Text(
                        '${payment.memberName} -> ${payment.coachName}',
                        style: _secondaryStyle(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        payment.specialReference ?? payment.id,
                        style: _secondaryStyle(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusChip(label: payment.status),
                    const SizedBox(height: 6),
                    Text(payment.amountLabel),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.statusValue,
    required this.statusOptions,
    required this.searchHint,
    required this.onStatusChanged,
    required this.onSearchChanged,
  });

  final String? statusValue;
  final List<String> statusOptions;
  final String searchHint;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<String?>(
            initialValue: statusValue,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All statuses'),
              ),
              ...statusOptions.map(
                (status) => DropdownMenuItem<String?>(
                  value: status,
                  child: Text(status.replaceAll('_', ' ')),
                ),
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ),
        SizedBox(
          width: 360,
          child: _SearchField(hint: searchHint, onChanged: onSearchChanged),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hint,
      ),
      onChanged: onChanged,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.adminRole});

  final String title;
  final String adminRole;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Admin role: ${adminRole.replaceAll('_', ' ')}',
                style: _secondaryStyle(),
              ),
            ],
          ),
        ),
        const _ModeBadge(label: 'TEST MODE'),
      ],
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final count = width >= 1200
        ? 4
        : width >= 760
        ? 3
        : 2;
    return GridView.count(
      crossAxisCount: count,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.65,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: _secondaryStyle()),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle()),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: _titleStyle())),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 170, child: Text(label, style: _secondaryStyle())),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'paid' || 'active' || 'ready' => AppColors.success,
      'failed' || 'cancelled' => AppColors.error,
      'on_hold' => AppColors.warning,
      _ => AppColors.orange,
    };
    return Chip(
      label: Text(label.replaceAll('_', ' ').toUpperCase()),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.10),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.fieldFill,
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          color: AppColors.warning,
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: Icons.cloud_off_outlined,
      title: 'Admin data unavailable',
      body: message,
      actionLabel: 'Retry',
      onTap: onRetry,
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: Icons.inbox_outlined,
      title: title,
      body: 'No matching admin records were found.',
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.orange),
            const SizedBox(height: 12),
            Text(title, style: _titleStyle(), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, style: _secondaryStyle(), textAlign: TextAlign.center),
            if (actionLabel != null && onTap != null) ...[
              const SizedBox(height: 14),
              ElevatedButton(onPressed: onTap, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminSection {
  const _AdminSection(this.label, this.icon, {String? shortLabel})
      : shortLabel = shortLabel ?? label;

  final String label;
  final IconData icon;
  final String shortLabel;
}

TextStyle _titleStyle() {
  return GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
}

TextStyle _secondaryStyle() {
  return GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary);
}

String _yes(bool value) => value ? 'Yes' : 'No';
