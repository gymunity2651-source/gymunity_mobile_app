import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/atelier_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/theme/atelier_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../coach/domain/entities/subscription_entity.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../store/domain/entities/order_entity.dart';
import '../../../user/domain/entities/app_role.dart';
import '../../../user/domain/entities/profile_entity.dart';
import '../../../user/presentation/widgets/profile_avatar.dart';
import '../../domain/entities/coaching_engagement_entity.dart';
import '../providers/member_providers.dart';

class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final subscriptions = ref.watch(memberSubscriptionsProvider).valueOrNull ?? const <SubscriptionEntity>[];
    final threads = ref.watch(memberCoachingThreadsProvider).valueOrNull ?? const <CoachingThreadEntity>[];
    final orders = ref.watch(memberOrdersProvider).valueOrNull ?? const <OrderEntity>[];
    final unreadNotifications = ref.watch(unreadNotificationsCountProvider);

    return Theme(
      data: AtelierTheme.light,
      child: Scaffold(
        backgroundColor: AtelierColors.surface,
        body: Stack(
          children: [
            const Positioned.fill(child: _ProfileBackdrop()),
            SafeArea(
              bottom: false,
              child: profileAsync.when(
                loading: () => const _ProfileLoadingView(),
                error: (error, _) => _ProfileStateCard(
                  title: 'Your sanctuary is temporarily unavailable',
                  message:
                      'We could not load your profile at the moment. Pull to refresh or try the curation again.',
                  actionLabel: 'Retry Profile',
                  onAction: () => _refreshProfile(ref),
                ),
                data: (profile) {
                  return RefreshIndicator.adaptive(
                    color: AtelierColors.primary,
                    onRefresh: () => _refreshProfile(ref),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 156),
                      children: [
                        _ProfileTopBar(
                          profile: profile,
                          onMenuTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                          onAvatarTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
                        ),
                        const SizedBox(height: 30),
                        _ProfileHero(
                          profile: profile,
                          fullName: _profileName(profile),
                          email: _profileEmail(profile),
                        ),
                        const SizedBox(height: 46),
                        const _SectionLabel('WELLNESS JOURNEY'),
                        const SizedBox(height: 14),
                        _ProfileActionCard(
                          icon: Icons.person_outline_rounded,
                          title: 'Edit Profile',
                          subtitle: 'Personal details & preferences',
                          onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
                        ),
                        _ProfileActionCard(
                          icon: Icons.spa_outlined,
                          title: 'My Coaching',
                          subtitle: _coachingSubtitle(subscriptions),
                          onTap: () => Navigator.pushNamed(context, AppRoutes.mySubscriptions),
                        ),
                        _ProfileActionCard(
                          icon: Icons.calendar_month_outlined,
                          title: 'Weekly Check-ins',
                          subtitle: _checkinsSubtitle(subscriptions),
                          onTap: () => Navigator.pushNamed(context, AppRoutes.memberCheckins),
                        ),
                        _ProfileActionCard(
                          icon: Icons.trending_up_rounded,
                          title: 'Progress',
                          subtitle: 'View your transformation map',
                          onTap: () => Navigator.pushNamed(context, AppRoutes.progress),
                        ),
                        const SizedBox(height: 34),
                        const _SectionLabel('ENGAGEMENT'),
                        const SizedBox(height: 14),
                        _ProfileActionCard(
                          icon: Icons.forum_outlined,
                          title: 'Messages',
                          subtitle: _messagesSubtitle(threads, unreadNotifications),
                          trailingDot: unreadNotifications > 0,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.memberMessages),
                        ),
                        _ProfileActionCard(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notifications',
                          subtitle: unreadNotifications > 0
                              ? '$unreadNotifications unread alert${unreadNotifications == 1 ? '' : 's'}'
                              : 'Configure alerts',
                          onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
                        ),
                        const SizedBox(height: 34),
                        const _SectionLabel('ACCOUNT & SUPPORT'),
                        const SizedBox(height: 14),
                        _ProfileActionGroup(
                          items: [
                            _ProfileGroupItem(
                              icon: Icons.shopping_bag_outlined,
                              label: 'My Orders',
                              onTap: () => Navigator.pushNamed(context, AppRoutes.orders),
                              detail: orders.isNotEmpty ? '${orders.length}' : null,
                            ),
                            _ProfileGroupItem(
                              icon: Icons.settings_outlined,
                              label: 'Settings',
                              onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                            ),
                            _ProfileGroupItem(
                              icon: Icons.help_outline_rounded,
                              label: 'Help & Support',
                              onTap: () => Navigator.pushNamed(context, AppRoutes.helpSupport),
                            ),
                          ],
                        ),
                        const SizedBox(height: 34),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: _LogoutPillButton(
                            onTap: () async {
                              await ref.read(authControllerProvider.notifier).logout();
                              if (!context.mounted) {
                                return;
                              }
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.login,
                                (route) => false,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _refreshProfile(WidgetRef ref) async {
  ref.invalidate(currentUserProfileProvider);
  ref.invalidate(memberSubscriptionsProvider);
  ref.invalidate(memberCoachingThreadsProvider);
  ref.invalidate(memberOrdersProvider);
  ref.invalidate(notificationsProvider);

  await Future.wait([
    ref.read(currentUserProfileProvider.future),
    ref.read(memberSubscriptionsProvider.future),
    ref.read(memberCoachingThreadsProvider.future),
    ref.read(memberOrdersProvider.future),
  ]);
}

class _ProfileBackdrop extends StatelessWidget {
  const _ProfileBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AtelierColors.surface),
        Positioned(
          top: 68,
          left: -90,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AtelierColors.primaryContainer.withValues(alpha: 0.08),
                  AtelierColors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: -80,
          bottom: 140,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFDEC0B6).withValues(alpha: 0.12),
                  AtelierColors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({
    required this.profile,
    required this.onMenuTap,
    required this.onAvatarTap,
  });

  final ProfileEntity? profile;
  final VoidCallback onMenuTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: const BoxDecoration(
        color: AtelierColors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: AtelierColors.navShadow,
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _RoundTopButton(
            icon: Icons.menu_rounded,
            onTap: onMenuTap,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Curated Sanctuary',
              style: GoogleFonts.notoSerif(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: AtelierColors.primary,
              ),
            ),
          ),
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AtelierColors.surfaceContainerLowest,
              ),
              child: ProfileAvatar(
                size: 34,
                avatarPath: profile?.avatarPath,
                fullName: _profileName(profile),
                backgroundColor: AtelierColors.primary,
                foregroundColor: AtelierColors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.fullName,
    required this.email,
  });

  final ProfileEntity? profile;
  final String fullName;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AtelierColors.surfaceContainerLowest,
              boxShadow: [
                BoxShadow(
                  color: AtelierColors.navShadow,
                  blurRadius: 28,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ProfileAvatar(
              size: 126,
              avatarPath: profile?.avatarPath,
              fullName: fullName,
              backgroundColor: AtelierColors.primary,
              foregroundColor: AtelierColors.onPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _heroName(fullName),
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerif(
              fontSize: 34,
              height: 1.08,
              fontWeight: FontWeight.w700,
              color: AtelierColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            email,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AtelierColors.onSurface,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroTag(label: _primaryMembershipLabel(profile)),
              _HeroTag(
                label: _secondaryProfileLabel(profile),
                highlighted: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? AtelierColors.primaryContainer.withValues(alpha: 0.22)
            : AtelierColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: highlighted ? AtelierColors.primary : AtelierColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.8,
          color: AtelierColors.textMuted,
        ),
      ),
    );
  }
}

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingDot = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool trailingDot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AtelierColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AtelierColors.surfaceContainerLow,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: AtelierColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AtelierColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AtelierColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailingDot
                    ? Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AtelierColors.primary,
                        ),
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        color: AtelierColors.outlineVariant.withValues(alpha: 0.9),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileActionGroup extends StatelessWidget {
  const _ProfileActionGroup({required this.items});

  final List<_ProfileGroupItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AtelierColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _ProfileGroupRow(item: items[index]),
              if (index != items.length - 1) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileGroupItem {
  const _ProfileGroupItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? detail;
}

class _ProfileGroupRow extends StatelessWidget {
  const _ProfileGroupRow({required this.item});

  final _ProfileGroupItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: AtelierColors.onSurface),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AtelierColors.onSurface,
                  ),
                ),
              ),
              if (item.detail != null) ...[
                Text(
                  item.detail!,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AtelierColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: AtelierColors.outlineVariant.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutPillButton extends StatelessWidget {
  const _LogoutPillButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AtelierColors.surfaceContainerLowest,
            border: Border.all(
              color: const Color(0xFFDEC0B6).withValues(alpha: 0.75),
            ),
          ),
          child: Center(
            child: Text(
              'LOG OUT OF SANCTUARY',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: AtelierColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AtelierColors.surfaceContainerLowest,
            border: Border.all(
              color: const Color(0xFFDEC0B6).withValues(alpha: 0.75),
            ),
          ),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: AtelierColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStateCard extends StatelessWidget {
  const _ProfileStateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          decoration: BoxDecoration(
            color: AtelierColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.notoSerif(
                  fontSize: 30,
                  height: 1.08,
                  fontWeight: FontWeight.w700,
                  color: AtelierColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.7,
                  color: AtelierColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _OutlineActionButton(
                label: actionLabel,
                onTap: () {
                  onAction();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 150),
      children: [
        Container(
          height: 70,
          color: AtelierColors.surfaceContainerLowest,
        ),
        const SizedBox(height: 30),
        Center(
          child: Container(
            width: 138,
            height: 138,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AtelierColors.surfaceContainerLowest,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Container(
            height: 74,
            decoration: BoxDecoration(
              color: AtelierColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 88),
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              color: AtelierColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 110),
          child: Container(
            height: 30,
            decoration: BoxDecoration(
              color: AtelierColors.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 46),
        const _SectionLabel('WELLNESS JOURNEY'),
        const SizedBox(height: 14),
        for (var index = 0; index < 6; index++)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Container(
              height: 82,
              decoration: BoxDecoration(
                color: AtelierColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
      ],
    );
  }
}

class _RoundTopButton extends StatelessWidget {
  const _RoundTopButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AtelierColors.surfaceContainerLowest,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 18, color: AtelierColors.primary),
        ),
      ),
    );
  }
}

String _profileName(ProfileEntity? profile) {
  final fullName = profile?.fullName?.trim();
  if (fullName != null && fullName.isNotEmpty) {
    return fullName;
  }
  return 'Curated Member';
}

String _profileEmail(ProfileEntity? profile) {
  final email = profile?.email?.trim();
  if (email != null && email.isNotEmpty) {
    return email;
  }
  return 'your.email@sanctuary.com';
}

String _heroName(String fullName) {
  final parts = fullName
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.length < 2) {
    return fullName;
  }
  final midpoint = (parts.length / 2).ceil();
  return '${parts.take(midpoint).join(' ')}\n${parts.skip(midpoint).join(' ')}';
}

String _primaryMembershipLabel(ProfileEntity? profile) {
  return profile?.onboardingCompleted == true ? 'Premium Member' : 'Wellness Member';
}

String _secondaryProfileLabel(ProfileEntity? profile) {
  final country = profile?.country?.trim();
  if (country != null && country.isNotEmpty) {
    return country;
  }
  return switch (profile?.role) {
    AppRole.coach => 'Coach',
    AppRole.seller => 'Seller',
    _ => 'Member',
  };
}

String _coachingSubtitle(List<SubscriptionEntity> subscriptions) {
  final count = subscriptions
      .where((subscription) =>
          subscription.isActive ||
          subscription.isPaused ||
          subscription.isCheckoutPending)
      .length;
  if (count <= 0) {
    return 'Explore your coaching space';
  }
  return '$count active program${count == 1 ? '' : 's'}';
}

String _checkinsSubtitle(List<SubscriptionEntity> subscriptions) {
  final hasCoaching = subscriptions.any(
    (subscription) =>
        subscription.isActive ||
        subscription.isPaused ||
        subscription.isCheckoutPending,
  );
  return hasCoaching
      ? 'Keep your weekly rhythm in view'
      : 'Open your reflection archive';
}

String _messagesSubtitle(
  List<CoachingThreadEntity> threads,
  int unreadNotifications,
) {
  if (unreadNotifications > 0) {
    return '$unreadNotifications new notification${unreadNotifications == 1 ? '' : 's'}';
  }
  if (threads.isNotEmpty) {
    return '${threads.length} active conversation${threads.length == 1 ? '' : 's'}';
  }
  return 'Open your conversation archive';
}
