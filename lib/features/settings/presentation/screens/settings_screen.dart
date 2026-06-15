import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/ai_branding.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/localization/app_localization_extension.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../monetization/presentation/providers/monetization_providers.dart';
import '../../../user/domain/entities/app_role.dart';
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
    final admin = ref.watch(currentAdminProvider).valueOrNull;
    final role = ref.watch(appRoleProvider);
    final editProfileRoute = _editProfileRouteForRole(role);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(leading: const BackButton(), title: Text(l10n.settings)),
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
                  l10n.settingsLoadError,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: controller.refresh,
                  child: Text(l10n.retry),
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.settingsSaveError)));
            }
          }

          return ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              _SectionTitle(title: l10n.account),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.person_outline,
                label: _editProfileLabelForRole(context, role),
                onTap: () => Navigator.pushNamed(context, editProfileRoute),
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
              if (admin != null && admin.isActive)
                _ActionTile(
                  icon: Icons.admin_panel_settings_outlined,
                  label: l10n.adminDashboard,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.adminDashboard),
                ),
              const SizedBox(height: 24),
              _SectionTitle(title: l10n.preferences),
              const SizedBox(height: 10),
              _PreferenceCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: preferences.pushNotificationsEnabled,
                      onChanged: (value) => updatePreference(
                        () => controller.setPushNotifications(value),
                      ),
                      title: Text(l10n.pushNotifications),
                      subtitle: Text(l10n.pushNotificationsSubtitle),
                      activeThumbColor: AppColors.orange,
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    SwitchListTile(
                      value: preferences.aiTipsEnabled,
                      onChanged: (value) =>
                          updatePreference(() => controller.setAiTips(value)),
                      title: Text(l10n.taiyoSuggestions),
                      subtitle: Text(l10n.taiyoSuggestionsSubtitle),
                      activeThumbColor: AppColors.orange,
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    SwitchListTile(
                      value: preferences.orderUpdatesEnabled,
                      onChanged: (value) => updatePreference(
                        () => controller.setOrderUpdates(value),
                      ),
                      title: Text(l10n.orderUpdates),
                      subtitle: Text(l10n.orderUpdatesSubtitle),
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
                      l10n.measurementUnits,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<MeasurementUnit>(
                      segments: [
                        ButtonSegment(
                          value: MeasurementUnit.metric,
                          label: Text(l10n.metric),
                        ),
                        ButtonSegment(
                          value: MeasurementUnit.imperial,
                          label: Text(l10n.imperial),
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
                      l10n.language,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<AppLanguage>(
                      segments: [
                        ButtonSegment(
                          value: AppLanguage.english,
                          label: Text(l10n.english),
                        ),
                        ButtonSegment(
                          value: AppLanguage.arabic,
                          label: Text(l10n.arabic),
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
              _SectionTitle(title: l10n.support),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.notifications_outlined,
                label: l10n.notificationsCenter,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
              ),
              _ActionTile(
                icon: Icons.help_outline,
                label: l10n.helpSupport,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.helpSupport),
              ),
              if (config.privacyPolicyUrl.trim().isNotEmpty)
                _ActionTile(
                  icon: Icons.privacy_tip_outlined,
                  label: l10n.privacyPolicy,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.privacyPolicy),
                ),
              if (config.termsUrl.trim().isNotEmpty)
                _ActionTile(
                  icon: Icons.description_outlined,
                  label: l10n.termsOfService,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
                ),
              const SizedBox(height: 24),
              _SectionTitle(title: l10n.accountActions),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.logout,
                label: l10n.logOut,
                destructive: true,
                onTap: () => _confirmLogout(context, ref),
              ),
              _ActionTile(
                icon: Icons.delete_outline,
                label: l10n.deleteAccount,
                destructive: true,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.deleteAccount);
                },
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  l10n.appVersion,
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

String _editProfileRouteForRole(AppRole? role) {
  switch (role) {
    case AppRole.seller:
      return AppRoutes.sellerProfile;
    case AppRole.coach:
      return AppRoutes.coachProfile;
    case AppRole.member:
    case null:
      return AppRoutes.editProfile;
  }
}

String _editProfileLabelForRole(BuildContext context, AppRole? role) {
  final l10n = context.l10n;
  switch (role) {
    case AppRole.seller:
      return l10n.storeProfile;
    case AppRole.coach:
      return l10n.coachProfile;
    case AppRole.member:
    case null:
      return l10n.editProfile;
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.logOutQuestion),
        content: Text(l10n.logoutReturnMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout, size: 18),
            label: Text(l10n.logOut),
          ),
        ],
      );
    },
  );

  if (shouldLogout != true || !context.mounted) {
    return;
  }

  final navigator = Navigator.of(context);
  await ref.read(authControllerProvider.notifier).logout();

  final authState = ref.read(authControllerProvider);
  if (authState.errorMessage != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authState.errorMessage!)));
    }
  }

  final binding = WidgetsBinding.instance;
  binding.addPostFrameCallback((_) {
    navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (route) => false);
  });
  binding.scheduleFrame();
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
      padding: const EdgeInsetsDirectional.only(bottom: 8),
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
        trailing: Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.chevron_left
              : Icons.chevron_right,
          color: foreground,
        ),
      ),
    );
  }
}
