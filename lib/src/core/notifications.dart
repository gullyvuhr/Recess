import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'bell_audio.dart';
import 'models.dart';

abstract interface class BellNotifications {
  Stream<String> get openedPayloads;

  String? takeInitialPayload();

  Future<bool> requestPermission();

  Future<bool> scheduleCadenceBell(
    int sessionId,
    DateTime scheduledAt, {
    BellSound sound = BellSound.schoolBell,
  });

  Future<bool> scheduleDeferredBell(
    int sessionId,
    DateTime scheduledAt, {
    BellSound sound = BellSound.schoolBell,
  });

  Future<void> cancelDeferredBell();

  Future<void> cancelCadenceBell({Set<int> retaining = const {}});

  Future<List<PendingCadenceBell>> pendingCadenceBells();

  Future<bool> ringBells(
    int sessionId, {
    required bool deferred,
    BellSound sound = BellSound.schoolBell,
  });
}

class PendingCadenceBell {
  const PendingCadenceBell({required this.id, required this.scheduledAt});

  final int id;
  final DateTime scheduledAt;
}

class NotificationService implements BellNotifications {
  static const immediateBellNotificationId = 1;
  static const legacyCadenceBellNotificationId = 100;
  static const deferredBellNotificationId = 200;
  static const _cadenceNotificationIdBase = 10000;

  final _plugin = FlutterLocalNotificationsPlugin();
  final _openedPayloads = StreamController<String>.broadcast();
  String? _initialPayload;

  @override
  Stream<String> get openedPayloads => _openedPayloads.stream;

  Future<void> initialize() async {
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
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
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final notificationsAllowed =
            await android.requestNotificationsPermission() ?? false;
        if (!notificationsAllowed) return false;
        final exactAlarmsAllowed =
            await android.canScheduleExactNotifications() ?? true;
        if (exactAlarmsAllowed) return true;
        return await android.requestExactAlarmsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      return true;
    } catch (_) {
      return false;
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

  static NotificationDetails detailsFor(BellSound sound) => NotificationDetails(
        android: AndroidNotificationDetails(
          sound.definition.androidChannelId,
          'Recess reminders',
          channelDescription: 'Gentle reminders to take a recess',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound(
            sound.definition.androidResourceName,
          ),
        ),
        iOS: DarwinNotificationDetails(sound: sound.definition.iosFileName),
      );

  @override
  Future<bool> scheduleCadenceBell(
    int sessionId,
    DateTime scheduledAt, {
    BellSound sound = BellSound.schoolBell,
  }) async {
    return _safeSchedule(
      id: cadenceNotificationId(scheduledAt),
      sessionId: sessionId,
      scheduledAt: scheduledAt,
      deferred: false,
      repeatsDaily: false,
      sound: sound,
    );
  }

  @override
  Future<bool> scheduleDeferredBell(
    int sessionId,
    DateTime scheduledAt, {
    BellSound sound = BellSound.schoolBell,
  }) async {
    return _safeSchedule(
      id: deferredBellNotificationId,
      sessionId: sessionId,
      scheduledAt: scheduledAt,
      deferred: true,
      repeatsDaily: false,
      sound: sound,
    );
  }

  Future<bool> _safeSchedule({
    required int id,
    required int sessionId,
    required DateTime scheduledAt,
    required bool deferred,
    required bool repeatsDaily,
    required BellSound sound,
  }) async {
    try {
      if (!await _canNotify()) return false;
      await _plugin.zonedSchedule(
        id,
        'Bells',
        'It might be a good moment for recess.',
        tz.TZDateTime.from(scheduledAt, tz.local),
        detailsFor(sound),
        payload: deferred ? 'bell:deferred:$sessionId' : 'bell:$sessionId',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: repeatsDaily ? DateTimeComponents.time : null,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (_) {
      return false;
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
  Future<void> cancelCadenceBell({Set<int> retaining = const {}}) async {
    try {
      await _plugin.cancel(legacyCadenceBellNotificationId);
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (_isCadenceNotificationId(request.id) &&
            !retaining.contains(request.id)) {
          await _plugin.cancel(request.id);
        }
      }
    } catch (_) {
      // Session state remains authoritative when cancellation is unavailable.
    }
  }

  @override
  Future<List<PendingCadenceBell>> pendingCadenceBells() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending
          .where((request) => _isCadenceNotificationId(request.id))
          .map(
            (request) => PendingCadenceBell(
              id: request.id,
              scheduledAt: cadenceTimeFromNotificationId(request.id),
            ),
          )
          .toList(growable: false)
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unable to inspect pending cadence Bells: $error');
      }
      return const [];
    }
  }

  static bool _isCadenceNotificationId(int id) =>
      id >= _cadenceNotificationIdBase &&
      id < deferredBellNotificationId * 10000000;

  static int cadenceNotificationId(DateTime scheduledAt) =>
      _cadenceNotificationIdBase +
      scheduledAt.millisecondsSinceEpoch ~/ Duration.millisecondsPerMinute;

  static DateTime cadenceTimeFromNotificationId(int id) =>
      DateTime.fromMillisecondsSinceEpoch(
        (id - _cadenceNotificationIdBase) * Duration.millisecondsPerMinute,
      );

  @override
  Future<bool> ringBells(
    int sessionId, {
    required bool deferred,
    BellSound sound = BellSound.schoolBell,
  }) async {
    try {
      if (!await _canNotify()) return false;
      await _plugin.show(
        immediateBellNotificationId,
        'Bells',
        'It might be a good moment for recess.',
        detailsFor(sound),
        payload:
            deferred ? 'bell:deferred:$sessionId' : 'bell:immediate:$sessionId',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _canNotify() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return (await ios.checkPermissions())?.isEnabled ?? false;
    }
    return true;
  }
}
