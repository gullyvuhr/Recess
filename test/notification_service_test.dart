import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  setUp(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'areNotificationsEnabled' => true,
        'requestNotificationsPermission' => true,
        'canScheduleExactNotifications' => false,
        'requestExactAlarmsPermission' => true,
        _ => null,
      };
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('scheduled Bells use exact allow-while-idle mode on Android', () async {
    final service = NotificationService();

    final scheduled = await service.scheduleCadenceBell(
      42,
      DateTime.now().add(const Duration(hours: 1)),
    );

    expect(scheduled, isTrue);
    final call = calls.singleWhere((call) => call.method == 'zonedSchedule');
    final arguments = call.arguments as Map<Object?, Object?>;
    final platformSpecifics =
        arguments['platformSpecifics'] as Map<Object?, Object?>;
    expect(platformSpecifics['scheduleMode'], 'exactAllowWhileIdle');
  });

  test('Android permission flow requests exact-alarm access', () async {
    final service = NotificationService();

    expect(await service.requestPermission(), isTrue);
    expect(
      calls.map((call) => call.method),
      containsAllInOrder([
        'requestNotificationsPermission',
        'canScheduleExactNotifications',
        'requestExactAlarmsPermission',
      ]),
    );
  });
}
