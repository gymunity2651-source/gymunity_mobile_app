import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../user/domain/entities/profile_entity.dart';

class MemberHomeContent extends ConsumerWidget {
  const MemberHomeContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final aiPremiumEnabled = AppConfig.current.enableAiPremium;

    return SafeArea(
      child: RefreshIndicator.adaptive(
        onRefresh: () => ref.refresh(currentUserProfileProvider.future),
        child: profileAsync.when(
          loading: () => const _HomeStateScaffold(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.orange),
            ),
          ),
          error: (error, stackTrace) => _HomeStateScaffold(
            child: _StatusCard(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load your account',
              description:
                  'GymUnity could not refresh your account details right now.',
              actionLabel: 'Retry',
              onTap: () => ref.refresh(currentUserProfileProvider),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return _HomeStateScaffold(
                child: _StatusCard(
                  icon: Icons.person_search_outlined,
                  title: 'Finish setting up your account',
                  description:
                      'Your GymUnity member profile is signed in, but the in-app profile is not complete yet.',
                  actionLabel: 'Choose role',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.roleSelection),
                ),
              );
            }

            return _MemberHomeLoaded(
              profile: profile,
              aiPremiumEnabled: aiPremiumEnabled,
            );
          },
        ),
      ),
    );
  }
}

class _MemberHomeLoaded extends StatelessWidget {
  const _MemberHomeLoaded({
    required this.profile,
    required this.aiPremiumEnabled,
  });

  final ProfileEntity profile;
  final bool aiPremiumEnabled;

  @override
  Widget build(BuildContext context) {
    final fullName = profile.fullName?.trim().isNotEmpty == true
        ? profile.fullName!.trim()
        : 'GymUnity Member';
    final firstName = fullName.split(' ').first;
    final email = profile.email?.trim().isNotEmpty == true
        ? profile.email!.trim()
        : 'No email available';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [
        Text(
          'Welcome back, $firstName',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This member dashboard only shows live account-backed entry points that are ready for review.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                email,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Pill(
                    label: profile.onboardingCompleted
                        ? 'Member profile ready'
                        : 'Onboarding pending',
                    accent: profile.onboardingCompleted
                        ? AppColors.limeGreen
                        : AppColors.orange,
                  ),
                  const _Pill(
                    label: 'Submission-safe navigation',
                    accent: AppColors.electricBlue,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(title: 'Quick Actions'),
        const SizedBox(height: 12),
        _QuickActionCard(
          icon: Icons.auto_awesome_outlined,
          title: aiPremiumEnabled ? 'Open AI Premium' : 'Open AI Assistant',
          description:
              aiPremiumEnabled
              ? 'Review the store-billed AI Premium path or open your verified AI conversations.'
              : 'Send a real prompt, view real sessions, and handle backend failures explicitly.',
          onTap: () => Navigator.pushNamed(context, AppRoutes.aiChatHome),
        ),
        const SizedBox(height: 12),
        _QuickActionCard(
          icon: Icons.storefront_outlined,
          title: 'Browse Store',
          description:
              'Review the current product catalog without fake checkout or preview purchases.',
          onTap: () => Navigator.pushNamed(context, AppRoutes.storeHome),
        ),
        const SizedBox(height: 12),
        _QuickActionCard(
          icon: Icons.groups_outlined,
          title: 'Browse Coaches',
          description:
              'Compare listed coaches without demo package requests or fake checkout.',
          onTap: () => Navigator.pushNamed(context, AppRoutes.coaches),
        ),
        const SizedBox(height: 12),
        _QuickActionCard(
          icon: Icons.settings_outlined,
          title: 'Account Settings',
          description:
              'Manage legal links, notifications, support channels, logout, and account deletion.',
          onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
        ),
      ],
    );
  }
}

class _HomeStateScaffold extends StatelessWidget {
  const _HomeStateScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      children: [const SizedBox(height: 20), child],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
        border: Border.all(color: AppColors.border),
      ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.orange.withValues(alpha: 0.16),
              child: Icon(icon, color: AppColors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}
