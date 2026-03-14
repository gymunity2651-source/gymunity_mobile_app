import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../providers/settings_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(resolvedSettingsPreferencesProvider);
    final filter = ref.watch(notificationFilterProvider);
    final notificationsAsync = ref.watch(notificationsProvider);
    final notifications = ref.watch(filteredNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                await ref
                    .read(notificationsControllerProvider)
                    .markAllRead(
                      notifications
                          .where((notification) => !notification.isRead)
                          .map((notification) => notification.id)
                          .toList(growable: false),
                    );
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!preferences.pushNotificationsEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                0,
                AppSizes.screenPadding,
                12,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  'Push notifications are turned off in Settings, so these updates stay inside the app only.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.screenPadding,
              ),
              children: NotificationFilter.values.map((value) {
                final isSelected = value == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(_filterLabel(value)),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(notificationFilterProvider.notifier).state =
                          value;
                    },
                    selectedColor: AppColors.orange.withValues(alpha: 0.18),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.orange
                          : AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: notificationsAsync.when(
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
                        'GymUnity could not load notifications right now.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.refresh(notificationsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (_) {
                if (notifications.isEmpty) {
                  return Center(
                    child: Text(
                      'No notifications matched the current filter.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                  ),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return InkWell(
                      onTap: () async {
                        await ref
                            .read(notificationsControllerProvider)
                            .markRead(notification.id);
                      },
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusLg,
                          ),
                          border: Border.all(
                            color: notification.isRead
                                ? AppColors.border
                                : AppColors.orange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: _categoryColor(
                                notification.category,
                              ).withValues(alpha: 0.18),
                              child: Icon(
                                _categoryIcon(notification.category),
                                color: _categoryColor(notification.category),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notification.title,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        notification.timeLabel,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    notification.body,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!notification.isRead) ...[
                              const SizedBox(width: 10),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemCount: notifications.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _filterLabel(NotificationFilter filter) {
    switch (filter) {
      case NotificationFilter.all:
        return 'All';
      case NotificationFilter.coaching:
        return 'Coaching';
      case NotificationFilter.orders:
        return 'Orders';
      case NotificationFilter.ai:
        return 'AI';
      case NotificationFilter.system:
        return 'System';
    }
  }

  static IconData _categoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.coaching:
        return Icons.groups_outlined;
      case NotificationCategory.orders:
        return Icons.local_shipping_outlined;
      case NotificationCategory.ai:
        return Icons.auto_awesome;
      case NotificationCategory.system:
        return Icons.notifications_active_outlined;
    }
  }

  static Color _categoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.coaching:
        return AppColors.orange;
      case NotificationCategory.orders:
        return AppColors.electricBlue;
      case NotificationCategory.ai:
        return AppColors.limeGreen;
      case NotificationCategory.system:
        return AppColors.textSecondary;
    }
  }
}
