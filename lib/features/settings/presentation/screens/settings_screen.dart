import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Settings screen â€” dark theme, grouped menu items.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // â”€â”€ Header â”€â”€
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Settings',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // â”€â”€ Account â”€â”€
              _sectionTitle('Account'),
              const SizedBox(height: 10),
              _SettingsGroup(
                ref: ref,
                items: const [
                  _SettingsItem(
                    icon: Icons.person_outline,
                    label: 'Edit Profile',
                  ),
                  _SettingsItem(
                    icon: Icons.lock_outline,
                    label: 'Change Password',
                  ),
                  _SettingsItem(icon: Icons.language, label: 'Language'),
                ],
              ),
              const SizedBox(height: 24),

              // â”€â”€ Preferences â”€â”€
              _sectionTitle('Preferences'),
              const SizedBox(height: 10),
              _SettingsGroup(
                ref: ref,
                items: const [
                  _SettingsItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                  ),
                  _SettingsItem(
                    icon: Icons.dark_mode_outlined,
                    label: 'Dark Mode',
                  ),
                  _SettingsItem(
                    icon: Icons.straighten,
                    label: 'Units (Metric/Imperial)',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // â”€â”€ Support â”€â”€
              _sectionTitle('Support'),
              const SizedBox(height: 10),
              _SettingsGroup(
                ref: ref,
                items: const [
                  _SettingsItem(
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                  ),
                  _SettingsItem(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                  ),
                  _SettingsItem(
                    icon: Icons.description_outlined,
                    label: 'Terms of Service',
                  ),
                  _SettingsItem(icon: Icons.star_outline, label: 'Rate App'),
                ],
              ),
              const SizedBox(height: 24),

              // â”€â”€ Danger â”€â”€
              _SettingsGroup(
                ref: ref,
                items: const [
                  _SettingsItem(
                    icon: Icons.logout,
                    label: 'Log Out',
                    isDestructive: true,
                  ),
                  _SettingsItem(
                    icon: Icons.delete_outline,
                    label: 'Delete Account',
                    isDestructive: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // â”€â”€ Version â”€â”€
              Center(
                child: Text(
                  'GymUnity v1.0.0',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 1,
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });
  final IconData icon;
  final String label;
  final bool isDestructive;
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.items, required this.ref});
  final List<_SettingsItem> items;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          return Column(
            children: [
              ListTile(
                leading: Icon(
                  item.icon,
                  color: item.isDestructive
                      ? Colors.red
                      : AppColors.textSecondary,
                  size: 22,
                ),
                title: Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: item.isDestructive
                        ? Colors.red
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: item.isDestructive
                      ? Colors.red.withValues(alpha: 0.5)
                      : AppColors.textMuted,
                  size: 20,
                ),
                onTap: () {
                  switch (item.label) {
                    case 'Edit Profile':
                      Navigator.pushNamed(context, AppRoutes.editProfile);
                      break;
                    case 'Change Password':
                      Navigator.pushNamed(context, AppRoutes.forgotPassword);
                      break;
                    case 'Language':
                      showAppFeedback(
                        context,
                        'Language preferences will be added with localization support.',
                      );
                      break;
                    case 'Notifications':
                      Navigator.pushNamed(context, AppRoutes.notifications);
                      break;
                    case 'Dark Mode':
                      showAppFeedback(
                        context,
                        'Dark mode is already active in the current app theme.',
                      );
                      break;
                    case 'Units (Metric/Imperial)':
                      showAppFeedback(
                        context,
                        'Measurement units will be configurable once profile preferences are connected.',
                      );
                      break;
                    case 'Help & Support':
                      Navigator.pushNamed(context, AppRoutes.helpSupport);
                      break;
                    case 'Privacy Policy':
                      Navigator.pushNamed(context, AppRoutes.privacyPolicy);
                      break;
                    case 'Terms of Service':
                      Navigator.pushNamed(context, AppRoutes.terms);
                      break;
                    case 'Rate App':
                      showAppFeedback(
                        context,
                        'App rating will open the store listing once publishing is configured.',
                      );
                      break;
                    case 'Log Out':
                      ref.read(authControllerProvider.notifier).logout().then((
                        _,
                      ) {
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (route) => false,
                        );
                      });
                      break;
                    case 'Delete Account':
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Account'),
                          content: const Text(
                            'Account deletion needs backend confirmation and is not enabled yet.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                      break;
                  }
                },
              ),
              if (i < items.length - 1)
                Divider(
                  color: AppColors.border,
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                ),
            ],
          );
        }),
      ),
    );
  }
}
