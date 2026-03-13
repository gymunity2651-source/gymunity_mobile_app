import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';

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

  factory AppNotificationItem.fromMap(Map<String, dynamic> map) {
    return AppNotificationItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      category: _categoryFromType(map['type'] as String?),
      timeLabel: _timeLabel(map['created_at'] as String?),
      isRead: map['is_read'] as bool? ?? false,
    );
  }

  static NotificationCategory _categoryFromType(String? rawType) {
    switch (rawType?.trim().toLowerCase()) {
      case 'coaching':
        return NotificationCategory.coaching;
      case 'orders':
        return NotificationCategory.orders;
      case 'ai':
        return NotificationCategory.ai;
      default:
        return NotificationCategory.system;
    }
  }

  static String _timeLabel(String? rawDate) {
    final createdAt = DateTime.tryParse(rawDate ?? '');
    if (createdAt == null) {
      return 'Recently';
    }

    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }
}

class NotificationsController {
  NotificationsController(this._ref);

  final Ref _ref;

  Future<void> markRead(String id) async {
    await _ref
        .read(supabaseClientProvider)
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('id', id);
  }

  Future<void> markAllRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) {
      return;
    }
    await _ref
        .read(supabaseClientProvider)
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .inFilter('id', notificationIds);
  }
}

final notificationsControllerProvider = Provider<NotificationsController>((
  ref,
) {
  return NotificationsController(ref);
});

final notificationsProvider = StreamProvider<List<AppNotificationItem>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) {
    return Stream<List<AppNotificationItem>>.value(
      const <AppNotificationItem>[],
    );
  }

  return client
      .from('notifications')
      .stream(primaryKey: <String>['id'])
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .map((rows) {
        return rows
            .map((row) => AppNotificationItem.fromMap(row))
            .toList(growable: false);
      });
});

final notificationFilterProvider = StateProvider<NotificationFilter>(
  (ref) => NotificationFilter.all,
);

final filteredNotificationsProvider = Provider<List<AppNotificationItem>>((
  ref,
) {
  final filter = ref.watch(notificationFilterProvider);
  final notifications =
      ref.watch(notificationsProvider).valueOrNull ?? const [];

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
          .valueOrNull
          ?.where((notification) => !notification.isRead)
          .length ??
      0;
});
