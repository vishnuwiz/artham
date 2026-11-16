import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'alert_engine.dart';

/// Shows and schedules notifications on this phone.
///
/// These are local notifications: Artham has no server, so nothing is "pushed"
/// from the internet and no account or token is involved. Every method fails
/// quietly (and does nothing on platforms without the plugin, such as unit
/// tests) so a notification problem can never break the app.
class NotificationService {
  NotificationService();

  static final NotificationService instance = NotificationService();

  static const String _channelId = 'artham_alerts';
  static const String _payload = 'alerts';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Called when the user taps a notification while the app is running.
  void Function()? onOpenAlerts;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Alerts',
      channelDescription:
          'Budget, recurring payment, backup and monthly summary reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  Future<bool> init() async {
    if (_ready) return true;
    if (!_supported) return false;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (_) => onOpenAlerts?.call(),
      );
      _ready = true;
    } catch (error) {
      debugPrint('Artham notifications unavailable: $error');
    }
    return _ready;
  }

  /// True when the app was cold-started by tapping one of its notifications.
  Future<bool> wasLaunchedByNotification() async {
    if (!await init()) return false;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      return details?.didNotificationLaunchApp ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the system for permission to show notifications. Returns whether
  /// notifications are allowed afterwards.
  Future<bool> requestPermission() async {
    if (!await init()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (error) {
      debugPrint('Artham notification permission error: $error');
    }
    return false;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!await init()) return;
    try {
      await _plugin.show(id, title, body, _details, payload: _payload);
    } catch (error) {
      debugPrint('Artham notification failed: $error');
    }
  }

  /// Replaces every pending scheduled notification with [notes].
  ///
  /// The notifications are inexact on purpose: they may arrive a few minutes
  /// late, which avoids the "alarms and reminders" special permission.
  Future<void> replaceSchedule(List<ScheduledNote> notes) async {
    if (!await init()) return;
    try {
      await _plugin.cancelAll();
      for (final note in notes) {
        await _plugin.zonedSchedule(
          note.id,
          note.title,
          note.body,
          // A UTC TZDateTime for the same instant: only the moment matters
          // for a one-off notification, so no time zone database is needed.
          tz.TZDateTime.from(note.when, tz.UTC),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: _payload,
        );
      }
    } catch (error) {
      debugPrint('Artham notification scheduling failed: $error');
    }
  }

  Future<void> cancelAll() async {
    if (!await init()) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
