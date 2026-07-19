import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

class NotificationService {
  static const bellNotificationId = 100;
  static const immediateBellNotificationId = 1;

  final _plugin = FlutterLocalNotificationsPlugin();

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
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('recess_reminders', 'Recess reminders',
        channelDescription: 'Gentle reminders to take a recess',
        importance: Importance.high,
        priority: Priority.high),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> scheduleBell(WorkSchedule schedule) async {
    final now = tz.TZDateTime.now(tz.local);
    final hour = schedule.bellMinutes ~/ 60;
    final minute = schedule.bellMinutes % 60;
    var nextBell = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!nextBell.isAfter(now)) {
      nextBell = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }

    await _plugin.cancel(bellNotificationId);
    await _plugin.zonedSchedule(
      bellNotificationId,
      'Bells',
      'It might be a good moment for recess.',
      nextBell,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> ringBells() => _plugin.show(immediateBellNotificationId, 'Bells',
      'It might be a good moment for recess.', _details);

  Future<void> remindIn(Duration delay, {required String label}) =>
      _plugin.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        'Recess is ready',
        label,
        tz.TZDateTime.now(tz.local).add(delay),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
}
