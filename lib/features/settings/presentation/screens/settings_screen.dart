import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/ai_branding.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../monetization/presentation/providers/monetization_providers.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencesAsync = ref.watch(settingsPreferencesProvider);
    final controller = ref.read(settingsPreferencesProvider.notifier);
    final config = AppConfig.current;
    final showSubscriptionSettings = ref.watch(
      shouldShowSubscriptionSettingsProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Settings'),
      ),
      body: preferencesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GymUnity could not load your settings right now.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: controller.refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (preferences) {
          Future<void> updatePreference(Future<void> Function() action) async {
            try {
              await action();
            } catch (_) {
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('GymUnity could not save that preference.'),
                ),
              );
            }
          }

          return ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              _SectionTitle(title: 'Account'),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.person_outline,
                label: 'Edit Profile',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.editProfile),
              ),
              _ActionTile(
                icon: Icons.lock_outline,
                label: 'Change Password',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.forgotPassword),
              ),
              if (showSubscriptionSettings)
                _ActionTile(
                  icon: Icons.workspace_premium_outlined,
                  label: AiBranding.premiumName,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.subscriptionManagement,
                  ),
                ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Preferences'),
              const SizedBox(height: 10),
              _PreferenceCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: preferences.pushNotificationsEnabled,
                      onChanged: (value) => updatePreference(
                        () => controller.setPushNotifications(value),
                      ),
                      title: const Text('Push Notifications'),
                      subtitle: const Text(
                        'Send key updates outside the app when possible.',
                      ),
                      activeThumbColor: AppColors.orange,
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    SwitchListTile(
                      value: preferences.aiTipsEnabled,
                      onChanged: (value) =>
                          updatePreference(() => controller.setAiTips(value)),
                      title: const Text(AiBranding.suggestionsLabel),
                      subtitle: const Text(
                        'Highlight new coaching or workout ideas from TAIYO.',
                      ),
                      activeThumbColor: AppColors.orange,
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    SwitchListTile(
                      value: preferences.orderUpdatesEnabled,
                      onChanged: (value) => updatePreference(
                        () => controller.setOrderUpdates(value),
                      ),
                      title: const Text('Order Updates'),
                      subtitle: const Text(
                        'Keep store order and delivery status visible in notifications.',
                      ),
                      activeThumbColor: AppColors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PreferenceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Measurement Units',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<MeasurementUnit>(
                      segments: const [
                        ButtonSegment(
                          value: MeasurementUnit.metric,
                          label: Text('Metric'),
                        ),
                        ButtonSegment(
                          value: MeasurementUnit.imperial,
                          label: Text('Imperial'),
                        ),
                      ],
                      selected: {preferences.measurementUnit},
                      onSelectionChanged: (selection) {
                        updatePreference(
                          () => controller.setMeasurementUnit(selection.first),
                        );
                      },
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Language',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<AppLanguage>(
                      segments: const [
                        ButtonSegment(
                          value: AppLanguage.english,
                          label: Text('English'),
                        ),
                        ButtonSegment(
                          value: AppLanguage.arabic,
                          label: Text('Arabic'),
                        ),
                      ],
                      selected: {preferences.language},
                      onSelectionChanged: (selection) {
                        updatePreference(
                          () => controller.setLanguage(selection.first),
                        );
                      },
                      showSelectedIcon: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Support'),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.notifications_outlined,
                label: 'Notifications Center',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
              ),
              _ActionTile(
                icon: Icons.help_outline,
                label: 'Help & Support',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.helpSupport),
              ),
              if (config.privacyPolicyUrl.trim().isNotEmpty)
                _ActionTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.privacyPolicy),
                ),
              if (config.termsUrl.trim().isNotEmpty)
                _ActionTile(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
                ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Account Actions'),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.logout,
                label: 'Log Out',
                destructive: true,
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
              _ActionTile(
                icon: Icons.delete_outline,
                label: 'Delete Account',
                destructive: true,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.deleteAccount);
                },
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'GymUnity v1.0.0',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          );
        },
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
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1,
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? Colors.red : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          side: BorderSide(
            color: destructive ? Colors.red.shade200 : AppColors.border,
          ),
        ),
        tileColor: AppColors.cardDark,
        leading: Icon(icon, color: foreground),
        title: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: foreground),
      ),
    );
  }
}
