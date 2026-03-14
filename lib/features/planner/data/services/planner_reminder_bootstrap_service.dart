import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/di/providers.dart';
import '../../domain/entities/planner_entities.dart';
import 'planner_notification_ids.dart';

class PlannerReminderBootstrapService {
  PlannerReminderBootstrapService(this._ref, this._plugin);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    await _initializeIfNeeded();
    await sync();
  }

  Future<void> dispose() async {
    _started = false;
  }

  Future<String> resolveCurrentTimeZone() => _resolveTimeZone();

  Future<void> sync({bool requestPermissions = false}) async {
    await _initializeIfNeeded();

    final session = _ref.read(authSessionProvider).valueOrNull;
    if (session == null || !session.isAuthenticated) {
      await _cancelAllPlannerNotifications();
      return;
    }

    final timeZone = await _resolveTimeZone();
    await _ref
        .read(plannerRepositoryProvider)
        .syncReminders(timeZone: timeZone, limit: 50);

    final preferences = await _ref
        .read(memberRepositoryProvider)
        .getPreferences();
    if (!preferences.pushNotificationsEnabled) {
      await _cancelAllPlannerNotifications();
      return;
    }

    final permissionsGranted = await _requestPermissions(
      requestPermissions: requestPermissions,
    );
    if (!permissionsGranted) {
      await _cancelAllPlannerNotifications();
      return;
    }

    final now = DateTime.now();
    final agenda = await _ref
        .read(plannerRepositoryProvider)
        .listPlanAgenda(
          dateFrom: now,
          dateTo: now.add(const Duration(days: 60)),
        );
    final schedulableTasks =
        agenda
            .where(
              (task) =>
                  task.planSource == 'ai' &&
                  task.reminderTime != null &&
                  task.completionStatus == TaskCompletionStatus.pending,
            )
            .toList(growable: false)
          ..sort((a, b) {
            final dateCompare = a.scheduledDate.compareTo(b.scheduledDate);
            if (dateCompare != 0) {
              return dateCompare;
            }
            return (a.reminderTime ?? '').compareTo(b.reminderTime ?? '');
          });

    final desiredIds = <int>{};
    final androidScheduleMode = await _resolveAndroidScheduleMode();

    for (final task in schedulableTasks.take(50)) {
      final reminderTime = task.reminderTime;
      if (reminderTime == null || reminderTime.isEmpty) {
        continue;
      }
      final scheduledAt = _scheduledDateTime(task: task, timeZone: timeZone);
      if (scheduledAt == null || scheduledAt.isBefore(now)) {
        continue;
      }

      final notificationId = buildPlannerNotificationId(
        taskId: task.taskId,
        scheduledDate: task.scheduledDate,
        reminderTime: reminderTime,
      );
      desiredIds.add(notificationId);

      await _plugin.zonedSchedule(
        notificationId,
        task.isToday ? 'Today\'s AI task' : 'Upcoming AI task',
        '${task.title} from ${task.planTitle}',
        scheduledAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'planner_tasks',
            'Planner Tasks',
            channelDescription: 'Daily reminders for AI workout plan tasks.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: 'planner-task:${task.taskId}:${task.planId}:${task.dayId}',
        androidScheduleMode: androidScheduleMode,
      );
    }

    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if ((notification.payload ?? '').startsWith('planner-task:') &&
          !desiredIds.contains(notification.id)) {
        await _plugin.cancel(notification.id);
      }
    }
  }

  Future<void> _initializeIfNeeded() async {
    if (_initialized) {
      return;
    }
    tz_data.initializeTimeZones();
    final timeZone = await _resolveTimeZone();
    tz.setLocalLocation(_locationFromName(timeZone));

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  Future<String> _resolveTimeZone() async {
    final value = await FlutterTimezone.getLocalTimezone();
    if (value.trim().isEmpty) {
      return 'UTC';
    }
    return value.trim();
  }

  tz.Location _locationFromName(String timeZone) {
    try {
      return tz.getLocation(timeZone);
    } catch (_) {
      return tz.UTC;
    }
  }

  tz.TZDateTime? _scheduledDateTime({
    required PlanTaskEntity task,
    required String timeZone,
  }) {
    final reminderTime = task.reminderTime;
    if (reminderTime == null || reminderTime.isEmpty) {
      return null;
    }
    final parts = reminderTime.split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    final location = _locationFromName(timeZone);
    return tz.TZDateTime(
      location,
      task.scheduledDate.year,
      task.scheduledDate.month,
      task.scheduledDate.day,
      hour,
      minute,
    );
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exactPermission = await androidPlugin?.canScheduleExactNotifications();
    if (exactPermission ?? false) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<bool> _requestPermissions({required bool requestPermissions}) async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final darwinPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    if (requestPermissions) {
      final androidAllowed =
          await androidPlugin?.requestNotificationsPermission() ?? true;
      final iosAllowed =
          await darwinPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
      return androidAllowed && iosAllowed;
    }
    return true;
  }

  Future<void> _cancelAllPlannerNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if ((notification.payload ?? '').startsWith('planner-task:')) {
        await _plugin.cancel(notification.id);
      }
    }
  }
}
