import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../user/domain/entities/app_role.dart';

/// Member profile screen.
class MemberProfileScreen extends ConsumerWidget {
  const MemberProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final fullName = profile?.fullName?.trim().isNotEmpty ?? false
        ? profile!.fullName!
        : 'Alex Johnson';
    final email = profile?.email?.trim().isNotEmpty ?? false
        ? profile!.email!
        : 'alex.johnson@email.com';
    final roleLabel = switch (profile?.role) {
      AppRole.coach => 'COACH',
      AppRole.seller => 'SELLER',
      _ => 'MEMBER',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // â”€â”€ Avatar â”€â”€
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.orange,
                child: const Icon(Icons.person, size: 48, color: AppColors.white),
              ),
              const SizedBox(height: 14),
              Text(fullName,
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(email,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.limeGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(roleLabel,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.limeGreen)),
              ),
              const SizedBox(height: 28),

              // â”€â”€ Stats row â”€â”€
              Row(
                children: const [
                  _StatTile(label: 'Workouts', value: '124'),
                  SizedBox(width: 12),
                  _StatTile(label: 'Streak', value: '15 days'),
                  SizedBox(width: 12),
                  _StatTile(label: 'Level', value: 'Gold'),
                ],
              ),
              const SizedBox(height: 28),

              // â”€â”€ Menu items â”€â”€
              _MenuItem(icon: Icons.person_outline, label: 'Edit Profile',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile)),
              _MenuItem(icon: Icons.trending_up, label: 'My Progress',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.progress)),
              _MenuItem(icon: Icons.fitness_center, label: 'Workout Plans',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.workoutPlan)),
              _MenuItem(icon: Icons.shopping_bag_outlined, label: 'My Orders',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.orders)),
              _MenuItem(icon: Icons.card_membership, label: 'Subscriptions',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.mySubscriptions)),
              _MenuItem(icon: Icons.notifications_outlined, label: 'Notifications',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.notifications)),
              _MenuItem(icon: Icons.settings_outlined, label: 'Settings',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.settings)),
              _MenuItem(icon: Icons.help_outline, label: 'Help & Support',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.helpSupport)),
              const SizedBox(height: 16),
              _MenuItem(
                icon: Icons.logout,
                label: 'Log Out',
                isDestructive: true,
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (!context.mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                      context, AppRoutes.login, (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withValues(alpha: 0.1)
                : AppColors.fieldFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: isDestructive ? Colors.red : AppColors.textSecondary,
              size: 22),
        ),
        title: Text(label,
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.red : AppColors.textPrimary)),
        trailing: Icon(Icons.chevron_right,
            color: isDestructive ? Colors.red : AppColors.textMuted, size: 20),
      ),
    );
  }
}

