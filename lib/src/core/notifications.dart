import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

abstract interface class BellNotifications {
  Stream<String> get openedPayloads;

  String? takeInitialPayload();

  Future<void> scheduleCadenceBell(int sessionId, DateTime scheduledAt);

  Future<void> scheduleDeferredBell(int sessionId, DateTime scheduledAt);

  Future<void> cancelDeferredBell();

  Future<void> ringBells(int sessionId, {required bool deferred});
}

class NotificationService implements BellNotifications {
  static const immediateBellNotificationId = 1;
  static const cadenceBellNotificationId = 100;
  static const deferredBellNotificationId = 200;

  final _plugin = FlutterLocalNotificationsPlugin();
  final _openedPayloads = StreamController<String>.broadcast();
  String? _initialPayload;

  @override
  Stream<String> get openedPayloads => _openedPayloads.stream;

  Future<void> initialize() async {
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _initialPayload = launchDetails?.notificationResponse?.payload;
    }
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
    } catch (_) {
      // Notification permission is optional; the offline app remains usable.
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      _openedPayloads.add(payload);
    }
  }

  @override
  String? takeInitialPayload() {
    final payload = _initialPayload;
    _initialPayload = null;
    return payload;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'recess_reminders',
      'Recess reminders',
      channelDescription: 'Gentle reminders to take a recess',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> scheduleCadenceBell(
    int sessionId,
    DateTime scheduledAt,
  ) async {
    await _safeSchedule(
      id: cadenceBellNotificationId,
      sessionId: sessionId,
      scheduledAt: scheduledAt,
      deferred: false,
    );
  }

  @override
  Future<void> scheduleDeferredBell(
    int sessionId,
    DateTime scheduledAt,
  ) async {
    await _safeSchedule(
      id: deferredBellNotificationId,
      sessionId: sessionId,
      scheduledAt: scheduledAt,
      deferred: true,
    );
  }

  Future<void> _safeSchedule({
    required int id,
    required int sessionId,
    required DateTime scheduledAt,
    required bool deferred,
  }) async {
    try {
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        'Bells',
        'It might be a good moment for recess.',
        tz.TZDateTime.from(scheduledAt, tz.local),
        _details,
        payload: deferred ? 'bell:deferred:$sessionId' : 'bell:$sessionId',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Denied or unavailable notifications must not block session state.
    }
  }

  @override
  Future<void> cancelDeferredBell() async {
    try {
      await _plugin.cancel(deferredBellNotificationId);
    } catch (_) {
      // Keep lifecycle transitions available when notifications are unavailable.
    }
  }

  @override
  Future<void> ringBells(int sessionId, {required bool deferred}) async {
    try {
      await _plugin.show(
        immediateBellNotificationId,
        'Bells',
        'It might be a good moment for recess.',
        _details,
        payload:
            deferred ? 'bell:deferred:$sessionId' : 'bell:immediate:$sessionId',
      );
    } catch (_) {
      // The test Bell is best-effort when permission is denied.
    }
  }
}
