import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../member/domain/entities/member_profile_entity.dart';
import '../../../member/presentation/providers/member_providers.dart';

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

  UserPreferencesEntity toMemberPreferences() {
    return UserPreferencesEntity(
      pushNotificationsEnabled: pushNotificationsEnabled,
      aiTipsEnabled: aiTipsEnabled,
      orderUpdatesEnabled: orderUpdatesEnabled,
      measurementUnit: measurementUnit == MeasurementUnit.metric
          ? 'metric'
          : 'imperial',
      language: language == AppLanguage.arabic ? 'arabic' : 'english',
    );
  }

  static SettingsPreferences fromMemberPreferences(
    UserPreferencesEntity value,
  ) {
    return SettingsPreferences(
      pushNotificationsEnabled: value.pushNotificationsEnabled,
      aiTipsEnabled: value.aiTipsEnabled,
      orderUpdatesEnabled: value.orderUpdatesEnabled,
      measurementUnit: value.measurementUnit == 'imperial'
          ? MeasurementUnit.imperial
          : MeasurementUnit.metric,
      language: value.language == 'arabic'
          ? AppLanguage.arabic
          : AppLanguage.english,
    );
  }
}

class SettingsPreferencesController
    extends StateNotifier<AsyncValue<SettingsPreferences>> {
  SettingsPreferencesController(this._ref)
    : super(const AsyncValue<SettingsPreferences>.loading()) {
    unawaited(refresh());
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final memberPreferences = await _ref
          .read(memberRepositoryProvider)
          .getPreferences();
      return SettingsPreferences.fromMemberPreferences(memberPreferences);
    });
  }

  Future<void> setPushNotifications(bool value) async {
    await _persist(
      (current) => current.copyWith(pushNotificationsEnabled: value),
    );
  }

  Future<void> setAiTips(bool value) async {
    await _persist((current) => current.copyWith(aiTipsEnabled: value));
  }

  Future<void> setOrderUpdates(bool value) async {
    await _persist((current) => current.copyWith(orderUpdatesEnabled: value));
  }

  Future<void> setMeasurementUnit(MeasurementUnit value) async {
    await _persist((current) => current.copyWith(measurementUnit: value));
  }

  Future<void> setLanguage(AppLanguage value) async {
    await _persist((current) => current.copyWith(language: value));
  }

  Future<void> _persist(
    SettingsPreferences Function(SettingsPreferences current) transform,
  ) async {
    final current = state.valueOrNull ?? const SettingsPreferences();
    final next = transform(current);
    state = AsyncValue<SettingsPreferences>.data(next);
    try {
      await _ref
          .read(memberRepositoryProvider)
          .upsertPreferences(next.toMemberPreferences());
      _ref.invalidate(memberPreferencesProvider);
    } catch (error, stackTrace) {
      state = AsyncValue<SettingsPreferences>.error(error, stackTrace);
      state = AsyncValue<SettingsPreferences>.data(current);
      rethrow;
    }
  }
}

final settingsPreferencesProvider =
    StateNotifierProvider<
      SettingsPreferencesController,
      AsyncValue<SettingsPreferences>
    >((ref) {
      return SettingsPreferencesController(ref);
    });

final resolvedSettingsPreferencesProvider = Provider<SettingsPreferences>((
  ref,
) {
  return ref.watch(settingsPreferencesProvider).valueOrNull ??
      const SettingsPreferences();
});

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timeLabel,
    this.isRead = false,
    this.availableAt,
  });

  final String id;
  final String title;
  final String body;
  final NotificationCategory category;
  final String timeLabel;
  final bool isRead;
  final DateTime? availableAt;

  AppNotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    NotificationCategory? category,
    String? timeLabel,
    bool? isRead,
    DateTime? availableAt,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      timeLabel: timeLabel ?? this.timeLabel,
      isRead: isRead ?? this.isRead,
      availableAt: availableAt ?? this.availableAt,
    );
  }

  factory AppNotificationItem.fromMap(Map<String, dynamic> map) {
    final availableAt = DateTime.tryParse(map['available_at'] as String? ?? '');
    final createdAt = DateTime.tryParse(map['created_at'] as String? ?? '');
    final displayTime = availableAt ?? createdAt;
    return AppNotificationItem(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      category: _categoryFromType(map['type'] as String?),
      timeLabel: _timeLabel(displayTime),
      isRead: map['is_read'] as bool? ?? false,
      availableAt: availableAt,
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

  static String _timeLabel(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Recently';
    }

    final difference = DateTime.now().difference(dateTime);
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
        final now = DateTime.now();
        final notifications =
            rows
                .map((dynamic row) => AppNotificationItem.fromMap(row))
                .where(
                  (notification) =>
                      notification.availableAt == null ||
                      !notification.availableAt!.isAfter(now),
                )
                .toList(growable: false)
              ..sort((a, b) {
                final aTime = a.availableAt;
                final bTime = b.availableAt;
                if (aTime == null && bTime == null) {
                  return 0;
                }
                if (aTime == null) {
                  return 1;
                }
                if (bTime == null) {
                  return -1;
                }
                return bTime.compareTo(aTime);
              });
        return notifications;
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
      ref.watch(notificationsProvider).valueOrNull ??
      const <AppNotificationItem>[];

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
      .toList(growable: false);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref
          .watch(notificationsProvider)
          .valueOrNull
          ?.where((notification) => !notification.isRead)
          .length ??
      0;
});
