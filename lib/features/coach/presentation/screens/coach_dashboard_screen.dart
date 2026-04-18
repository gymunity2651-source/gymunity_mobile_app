import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_shell_background.dart';
import '../../../user/presentation/widgets/profile_avatar.dart';
import '../../domain/entities/coach_entity.dart';
import '../providers/coach_providers.dart';

class CoachDashboardScreen extends ConsumerWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(coachProfileProvider);
    final summaryAsync = ref.watch(coachDashboardSummaryProvider);
    final clientsAsync = ref.watch(coachClientsProvider);
    final packagesAsync = ref.watch(coachPackagesProvider);

    Future<void> refreshDashboard() async {
      ref.invalidate(coachProfileProvider);
      ref.invalidate(coachDashboardSummaryProvider);
      ref.invalidate(coachClientsProvider);
      ref.invalidate(coachPackagesProvider);
      try {
        await Future.wait<dynamic>([
          ref.read(coachProfileProvider.future),
          ref.read(coachDashboardSummaryProvider.future),
          ref.read(coachClientsProvider.future),
          ref.read(coachPackagesProvider.future),
        ]);
      } catch (_) {
        // Section-level async states already handle their own retry messaging.
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppShellBackground(
          topGlowColor: AppColors.glowOrange,
          bottomGlowColor: AppColors.glowBlue,
          child: RefreshIndicator.adaptive(
            onRefresh: refreshDashboard,
            child: profileAsync.when(
              loading: () => const _DashboardStateScroll(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.orange),
                ),
              ),
              error: (error, stackTrace) => _DashboardStateScroll(
                child: _DashboardStateCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to load your coach dashboard',
                  description:
                      'GymUnity could not refresh your coach workspace right now.',
                  actionLabel: 'Retry',
                  onTap: refreshDashboard,
                ),
              ),
              data: (profile) {
                if (profile == null) {
                  return _DashboardStateScroll(
                    child: _DashboardStateCard(
                      icon: Icons.sports_gymnastics_outlined,
                      title: 'Finish your coach setup',
                      description:
                          'Your account is signed in, but the live coach profile is not ready yet.',
                      actionLabel: 'Open onboarding',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.coachOnboarding,
                      ),
                    ),
                  );
                }

                return _CoachDashboardContent(
                  profile: profile,
                  summaryAsync: summaryAsync,
                  clientsAsync: clientsAsync,
                  packagesAsync: packagesAsync,
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _CoachBottomNavigation(),
    );
  }
}

class _CoachDashboardContent extends StatelessWidget {
  const _CoachDashboardContent({
    required this.profile,
    required this.summaryAsync,
    required this.clientsAsync,
    required this.packagesAsync,
  });

  final CoachEntity profile;
  final AsyncValue<CoachDashboardSummaryEntity> summaryAsync;
  final AsyncValue<List<CoachClientEntity>> clientsAsync;
  final AsyncValue<List<CoachPackageEntity>> packagesAsync;

  @override
  Widget build(BuildContext context) {
    final summary = summaryAsync.valueOrNull;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.lg,
        AppSizes.screenPadding,
        116,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coach dashboard',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    'Run your coaching space',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.02,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            IconButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.notifications),
              icon: const Icon(Icons.notifications_outlined),
            ),
            const SizedBox(width: AppSizes.sm),
            IconButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.xl),
        _CoachHeroCard(profile: profile, summary: summary),
        const SizedBox(height: AppSizes.xxl),
        const _SectionHeading(
          title: 'Overview',
          subtitle:
              'Live numbers from the coach account, not placeholder dashboard stats.',
        ),
        const SizedBox(height: AppSizes.md),
        _SummarySection(summaryAsync: summaryAsync),
        const SizedBox(height: AppSizes.xxl),
        const _SectionHeading(
          title: 'Quick Actions',
          subtitle:
              'Jump straight into the flows that shape the public coach experience.',
        ),
        const SizedBox(height: AppSizes.md),
        const _QuickActionGrid(),
        const SizedBox(height: AppSizes.xxl),
        const _SectionHeading(
          title: 'Client Momentum',
          subtitle:
              'See who is active, who needs follow-up, and where the coaching load is moving.',
        ),
        const SizedBox(height: AppSizes.md),
        _ClientsSection(clientsAsync: clientsAsync),
        const SizedBox(height: AppSizes.xxl),
        const _SectionHeading(
          title: 'Published Packages',
          subtitle:
              'These package cards mirror the offers members can request from your public profile.',
        ),
        const SizedBox(height: AppSizes.md),
        _PackagesSection(
          packagesAsync: packagesAsync,
          pricingCurrency: profile.pricingCurrency,
        ),
      ],
    );
  }
}

class _CoachHeroCard extends StatelessWidget {
  const _CoachHeroCard({required this.profile, required this.summary});

  final CoachEntity profile;
  final CoachDashboardSummaryEntity? summary;

  @override
  Widget build(BuildContext context) {
    final description = profile.serviceSummary.trim().isNotEmpty
        ? profile.serviceSummary.trim()
        : profile.bio.trim().isNotEmpty
        ? profile.bio.trim()
        : 'Keep your live packages, client pipeline, and coach profile aligned from one focused dashboard.';
    final reviewValue = summary == null
        ? '--'
        : summary!.ratingCount == 0
        ? 'New'
        : summary!.ratingAvg.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
        border: Border.all(color: AppColors.borderSoft.withValues(alpha: 0.55)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardDark.withValues(alpha: 0.97),
            AppColors.surfacePanel.withValues(alpha: 0.96),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              _InfoPill(
                label: profile.badge,
                accent: profile.isVerified
                    ? AppColors.limeGreen
                    : AppColors.orangeLight,
              ),
              _InfoPill(
                label: _deliveryModeLabel(profile.deliveryMode),
                accent: AppColors.electricBlue,
              ),
              _InfoPill(label: profile.specialty, accent: AppColors.orange),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileAvatar(
                size: 64,
                avatarPath: profile.avatarPath,
                fullName: profile.name,
                backgroundColor: AppColors.orange,
              ),
              const SizedBox(width: AppSizes.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.02,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.55,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'Active clients',
                  value: '${summary?.activeClients ?? 0}',
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: _HeroMetric(
                  label: 'Plans live',
                  value: '${summary?.activePlans ?? 0}',
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: _HeroMetric(label: 'Reviews', value: reviewValue),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.addPackage),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: AppColors.white,
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Create Package'),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.clients),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('Open clients'),
                ),
              ),
            ],
          ),
          if ((summary?.pendingRequests ?? 0) > 0) ...[
            const SizedBox(height: AppSizes.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.lg),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(
                  color: AppColors.orangeLight.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      color: AppColors.orangeLight,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Text(
                      '${summary!.pendingRequests} pending lead${summary!.pendingRequests == 1 ? '' : 's'} waiting for plan assignment or activation.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummarySection extends ConsumerWidget {
  const _SummarySection({required this.summaryAsync});

  final AsyncValue<CoachDashboardSummaryEntity> summaryAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _DashboardPanel(
      child: summaryAsync.when(
        loading: () => const _PanelLoading(),
        error: (error, stackTrace) => _PanelState(
          icon: Icons.insights_outlined,
          title: 'Metrics are unavailable right now',
          description: 'Pull to refresh or retry the coach summary request.',
          actionLabel: 'Retry',
          onTap: () => ref.invalidate(coachDashboardSummaryProvider),
        ),
        data: (summary) => LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 920
                ? 4
                : constraints.maxWidth >= 580
                ? 2
                : 1;
            final itemWidth =
                (constraints.maxWidth - ((columns - 1) * AppSizes.md)) /
                columns;

            return Wrap(
              spacing: AppSizes.md,
              runSpacing: AppSizes.md,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _MetricCard(
                    label: 'Active clients',
                    value: '${summary.activeClients}',
                    accent: AppColors.limeGreen,
                    note: 'Members with an active coaching relationship.',
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _MetricCard(
                    label: 'Pending requests',
                    value: '${summary.pendingRequests}',
                    accent: AppColors.orange,
                    note:
                        'Paid leads or pending activations waiting for coach action.',
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _MetricCard(
                    label: 'Active plans',
                    value: '${summary.activePlans}',
                    accent: AppColors.electricBlue,
                    note: 'Live workout plans currently assigned by a coach.',
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _MetricCard(
                    label: 'Package rating',
                    value: summary.ratingCount == 0
                        ? 'New'
                        : summary.ratingAvg.toStringAsFixed(1),
                    accent: AppColors.orangeLight,
                    note: summary.ratingCount == 0
                        ? 'No member reviews have been submitted yet.'
                        : '${summary.ratingCount} review${summary.ratingCount == 1 ? '' : 's'} on the public coach profile.',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid();

  @override
  Widget build(BuildContext context) {
    final actions = <_DashboardAction>[
      _DashboardAction(
        icon: Icons.add_card_outlined,
        title: 'Create a new package',
        description:
            'Add a pricing offer that members can browse and request from your coach profile.',
        accent: AppColors.orange,
        onTap: () => Navigator.pushNamed(context, AppRoutes.addPackage),
      ),
      _DashboardAction(
        icon: Icons.groups_outlined,
        title: 'Review client roster',
        description:
            'Open the coaching pipeline, inspect active members, and handle follow-up actions.',
        accent: AppColors.limeGreen,
        onTap: () => Navigator.pushNamed(context, AppRoutes.clients),
      ),
      _DashboardAction(
        icon: Icons.inventory_2_outlined,
        title: 'Manage package library',
        description:
            'Check the package set connected to the public coach marketplace and future edits.',
        accent: AppColors.electricBlue,
        onTap: () => Navigator.pushNamed(context, AppRoutes.packages),
      ),
      _DashboardAction(
        icon: Icons.person_outline,
        title: 'Open coach profile',
        description:
            'Review the public-facing coach profile details, specialties, and visibility settings.',
        accent: AppColors.aqua,
        onTap: () => Navigator.pushNamed(context, AppRoutes.coachProfile),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 580 ? 2 : 1;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * AppSizes.md)) / columns;

        return Wrap(
          spacing: AppSizes.md,
          runSpacing: AppSizes.md,
          children: actions
              .map(
                (action) => SizedBox(
                  width: itemWidth,
                  child: _ActionCard(action: action),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _ClientsSection extends ConsumerWidget {
  const _ClientsSection({required this.clientsAsync});

  final AsyncValue<List<CoachClientEntity>> clientsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _DashboardPanel(
      child: clientsAsync.when(
        loading: () => const _PanelLoading(),
        error: (error, stackTrace) => _PanelState(
          icon: Icons.group_off_outlined,
          title: 'Client activity is unavailable',
          description:
              'GymUnity could not read the active coach roster from Supabase.',
          actionLabel: 'Retry',
          onTap: () => ref.invalidate(coachClientsProvider),
        ),
        data: (clients) {
          if (clients.isEmpty) {
            return _PanelState(
              icon: Icons.groups_2_outlined,
              title: 'No active clients yet',
              description:
                  'Publish a real package, keep the coach profile clear, and new client requests will start appearing here.',
              actionLabel: 'Create package',
              onTap: () => Navigator.pushNamed(context, AppRoutes.addPackage),
            );
          }

          final visibleClients = clients.take(4).toList(growable: false);
          return Column(
            children: [
              ...visibleClients.map(
                (client) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.md),
                  child: _ClientTile(client: client),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.clients),
                  icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                  label: const Text('View full client roster'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PackagesSection extends ConsumerWidget {
  const _PackagesSection({
    required this.packagesAsync,
    required this.pricingCurrency,
  });

  final AsyncValue<List<CoachPackageEntity>> packagesAsync;
  final String pricingCurrency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _DashboardPanel(
      child: packagesAsync.when(
        loading: () => const _PanelLoading(),
        error: (error, stackTrace) => _PanelState(
          icon: Icons.inventory_outlined,
          title: 'Package list is unavailable',
          description: 'GymUnity could not load your coach packages right now.',
          actionLabel: 'Retry',
          onTap: () => ref.invalidate(coachPackagesProvider),
        ),
        data: (packages) {
          if (packages.isEmpty) {
            return _PanelState(
              icon: Icons.add_business_outlined,
              title: 'No packages published yet',
              description:
                  'Create the first coaching offer so members have a real package to request.',
              actionLabel: 'Create package',
              onTap: () => Navigator.pushNamed(context, AppRoutes.addPackage),
            );
          }

          final visiblePackages = packages.take(3).toList(growable: false);
          return Column(
            children: [
              ...visiblePackages.map(
                (package) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.md),
                  child: _PackageTile(
                    package: package,
                    pricingCurrency: pricingCurrency,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.packages),
                  icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                  label: const Text('Manage package library'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CoachBottomNavigation extends StatelessWidget {
  const _CoachBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.borderSoft.withValues(alpha: 0.46),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.cardDark.withValues(alpha: 0.96),
              AppColors.surfacePanel.withValues(alpha: 0.96),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.26),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  return;
                case 1:
                  Navigator.pushNamed(context, AppRoutes.clients);
                  return;
                case 2:
                  Navigator.pushNamed(context, AppRoutes.packages);
                  return;
                case 3:
                  Navigator.pushNamed(context, AppRoutes.coachProfile);
                  return;
                case 4:
                  Navigator.pushNamed(context, AppRoutes.settings);
                  return;
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Clients',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Packages',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardStateScroll extends StatelessWidget {
  const _DashboardStateScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        96,
        AppSizes.screenPadding,
        140,
      ),
      children: [child],
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardDark.withValues(alpha: 0.97),
            AppColors.surfacePanel.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
        border: Border.all(color: AppColors.borderSoft.withValues(alpha: 0.52)),
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        if (subtitle != null) ...[
          const SizedBox(height: AppSizes.xs),
          Text(
            subtitle!,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.note,
  });

  final String label;
  final String value;
  final Color accent;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            note,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final _DashboardAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cardDark.withValues(alpha: 0.97),
                AppColors.surfacePanel.withValues(alpha: 0.94),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            border: Border.all(
              color: AppColors.borderSoft.withValues(alpha: 0.52),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: action.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(action.icon, color: action.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      action.description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: const Icon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client});

  final CoachClientEntity client;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.orangeLight,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.memberName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      client.packageTitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              _StatusChip(
                label: _statusLabel(client.status),
                color: _statusColor(client.status),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              _InlineInfoChip(
                label:
                    '${client.activePlanCount} active plan${client.activePlanCount == 1 ? '' : 's'}',
              ),
              _InlineInfoChip(label: 'Started ${_timeAgo(client.startedAt)}'),
              if (client.lastSessionAt != null)
                _InlineInfoChip(
                  label: 'Last session ${_timeAgo(client.lastSessionAt!)}',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({required this.package, required this.pricingCurrency});

  final CoachPackageEntity package;
  final String pricingCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _billingLabel(package.billingCycle),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(package.price, pricingCurrency),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.orangeLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatusChip(
                    label: _packageStatusLabel(package.visibilityStatus),
                    color: switch (package.visibilityStatus) {
                      'published' => AppColors.limeGreen,
                      'archived' => AppColors.textMuted,
                      _ => AppColors.orangeLight,
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            package.description.trim().isEmpty
                ? 'No public description has been written for this package yet.'
                : package.description.trim(),
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
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

String _packageStatusLabel(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'Draft';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

class _InlineInfoChip extends StatelessWidget {
  const _InlineInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _DashboardStateCard extends StatelessWidget {
  const _DashboardStateCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      child: Column(
        children: [
          Icon(icon, color: AppColors.orange, size: 36),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.white,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _PanelLoading extends StatelessWidget {
  const _PanelLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 160,
      child: Center(child: CircularProgressIndicator(color: AppColors.orange)),
    );
  }
}

class _PanelState extends StatelessWidget {
  const _PanelState({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.orange, size: 32),
        const SizedBox(height: AppSizes.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Text(
          description,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        OutlinedButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;
}

String _deliveryModeLabel(String? deliveryMode) {
  final normalized = deliveryMode?.trim();
  if (normalized == null || normalized.isEmpty) {
    return 'Delivery flexible';
  }

  return normalized
      .split('_')
      .map(
        (segment) => segment.isEmpty
            ? segment
            : '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _statusLabel(String status) {
  return status
      .split('_')
      .map(
        (segment) => segment.isEmpty
            ? segment
            : '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
      )
      .join(' ');
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'active':
    case 'completed':
      return AppColors.limeGreen;
    case 'pending':
    case 'pending_payment':
      return AppColors.orange;
    case 'cancelled':
    case 'expired':
      return AppColors.error;
    default:
      return AppColors.electricBlue;
  }
}

String _billingLabel(String billingCycle) {
  final normalized = billingCycle.trim().replaceAll('_', ' ');
  if (normalized.isEmpty) {
    return 'Billing cycle unavailable';
  }

  return normalized
      .split(' ')
      .map(
        (segment) => segment.isEmpty
            ? segment
            : '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _formatCurrency(double amount, String currency) {
  final code = currency.trim().toUpperCase();
  final symbol = switch (code) {
    'USD' => '\$',
    'EUR' => 'EUR ',
    'GBP' => 'GBP ',
    _ => code.isEmpty ? '\$' : '$code ',
  };
  final normalized = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '$symbol$normalized';
}

String _timeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 1) {
    return 'just now';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  }

  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) {
    return '${weeks}w ago';
  }

  final months = (diff.inDays / 30).floor();
  if (months < 12) {
    return '${months}mo ago';
  }

  final years = (diff.inDays / 365).floor();
  return '${years}y ago';
}
