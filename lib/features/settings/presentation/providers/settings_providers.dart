import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MeasurementUnit { metric, imperial }

enum AppLanguage { english, arabic }

enum NotificationCategory { coaching, orders, ai, system }

enum NotificationFilter { all, coaching, orders, ai, system }

class SettingsPreferences {
  const SettingsPreferences({
    this.pushNotificationsEnabled = true,
    this.aiTipsEnabled = true,
    this.orderUpdatesEnabled = true,
    this.measurementUnit = MeasurementUnit.metric,
    this.language = AppLanguage.english,
  });

  final bool pushNotificationsEnabled;
  final bool aiTipsEnabled;
  final bool orderUpdatesEnabled;
  final MeasurementUnit measurementUnit;
  final AppLanguage language;

  SettingsPreferences copyWith({
    bool? pushNotificationsEnabled,
    bool? aiTipsEnabled,
    bool? orderUpdatesEnabled,
    MeasurementUnit? measurementUnit,
    AppLanguage? language,
  }) {
    return SettingsPreferences(
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      aiTipsEnabled: aiTipsEnabled ?? this.aiTipsEnabled,
      orderUpdatesEnabled: orderUpdatesEnabled ?? this.orderUpdatesEnabled,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      language: language ?? this.language,
    );
  }
}

class SettingsPreferencesController extends StateNotifier<SettingsPreferences> {
  SettingsPreferencesController() : super(const SettingsPreferences());

  void setPushNotifications(bool value) {
    state = state.copyWith(pushNotificationsEnabled: value);
  }

  void setAiTips(bool value) {
    state = state.copyWith(aiTipsEnabled: value);
  }

  void setOrderUpdates(bool value) {
    state = state.copyWith(orderUpdatesEnabled: value);
  }

  void setMeasurementUnit(MeasurementUnit value) {
    state = state.copyWith(measurementUnit: value);
  }

  void setLanguage(AppLanguage value) {
    state = state.copyWith(language: value);
  }
}

final settingsPreferencesProvider =
    StateNotifierProvider<SettingsPreferencesController, SettingsPreferences>((
      ref,
    ) {
      return SettingsPreferencesController();
    });

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timeLabel,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final String timeLabel;
  final bool isRead;

  AppNotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    NotificationCategory? category,
    String? timeLabel,
    bool? isRead,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      timeLabel: timeLabel ?? this.timeLabel,
      isRead: isRead ?? this.isRead,
    );
  }
}

class NotificationsController extends StateNotifier<List<AppNotificationItem>> {
  NotificationsController()
    : super(
        const <AppNotificationItem>[
          AppNotificationItem(
            id: 'n1',
            title: 'Coach match found',
            body: 'Two high-rated strength coaches now match your current goals.',
            category: NotificationCategory.coaching,
            timeLabel: 'Just now',
          ),
          AppNotificationItem(
            id: 'n2',
            title: 'Order update',
            body: 'Your smart tracker order is packed and ready for shipment.',
            category: NotificationCategory.orders,
            timeLabel: '1h ago',
          ),
          AppNotificationItem(
            id: 'n3',
            title: 'AI suggestion ready',
            body: 'GymUnity AI built a shorter leg-day variation based on your last chat.',
            category: NotificationCategory.ai,
            timeLabel: 'Today',
          ),
          AppNotificationItem(
            id: 'n4',
            title: 'Streak milestone',
            body: 'You are one workout away from a 16-day streak.',
            category: NotificationCategory.system,
            timeLabel: 'Yesterday',
            isRead: true,
          ),
        ],
      );

  void markRead(String id) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
  }

  void markAllRead() {
    state = [for (final item in state) item.copyWith(isRead: true)];
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsController, List<AppNotificationItem>>((
      ref,
    ) {
      return NotificationsController();
    });

final notificationFilterProvider = StateProvider<NotificationFilter>(
  (ref) => NotificationFilter.all,
);

final filteredNotificationsProvider = Provider<List<AppNotificationItem>>((ref) {
  final filter = ref.watch(notificationFilterProvider);
  final notifications = ref.watch(notificationsProvider);

  if (filter == NotificationFilter.all) {
    return notifications;
  }

  final category = switch (filter) {
    NotificationFilter.coaching => NotificationCategory.coaching,
    NotificationFilter.orders => NotificationCategory.orders,
    NotificationFilter.ai => NotificationCategory.ai,
    NotificationFilter.system => NotificationCategory.system,
    NotificationFilter.all => null,
  };

  return notifications
      .where((notification) => notification.category == category)
      .toList();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref
      .watch(notificationsProvider)
      .where((notification) => !notification.isRead)
      .length;
});
