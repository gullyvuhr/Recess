import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/cadence_schedule.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/notifications.dart';

void main() {
  const hourly = WorkSchedule(
    startMinutes: 9 * 60,
    endMinutes: 17 * 60,
    cadenceMinutes: 60,
  );

  test('generates every cadence time inside a workday', () {
    final times = cadenceBellTimes(
      schedule: hourly,
      now: DateTime(2026, 7, 19, 8),
      days: 1,
    );

    expect(
      times,
      [for (var hour = 10; hour < 17; hour++) DateTime(2026, 7, 19, hour)],
    );
  });

  test('excludes bells in the past and at the current instant', () {
    final times = cadenceBellTimes(
      schedule: hourly,
      now: DateTime(2026, 7, 19, 13),
      days: 1,
    );

    expect(times.first, DateTime(2026, 7, 19, 14));
    expect(times, isNot(contains(DateTime(2026, 7, 19, 13))));
  });

  test('excludes work start and end boundaries', () {
    const schedule = WorkSchedule(
      startMinutes: 9 * 60,
      endMinutes: 10 * 60,
      cadenceMinutes: 30,
    );

    expect(
      cadenceBellTimes(
        schedule: schedule,
        now: DateTime(2026, 7, 19, 8),
        days: 1,
      ),
      [DateTime(2026, 7, 19, 9, 30)],
    );
  });

  test('honors non-hour cadence intervals across calendar days', () {
    const schedule = WorkSchedule(
      startMinutes: 9 * 60 + 15,
      endMinutes: 11 * 60,
      cadenceMinutes: 35,
    );

    final times = cadenceBellTimes(
      schedule: schedule,
      now: DateTime(2026, 7, 19, 8),
      days: 2,
    );

    expect(times, [
      DateTime(2026, 7, 19, 9, 50),
      DateTime(2026, 7, 19, 10, 25),
      DateTime(2026, 7, 20, 9, 50),
      DateTime(2026, 7, 20, 10, 25),
    ]);
  });

  test('caps the rolling window to the platform-safe limit', () {
    final times = cadenceBellTimes(
      schedule: hourly,
      now: DateTime(2026, 7, 19, 8),
      limit: 5,
    );

    expect(times, hasLength(5));
    expect(times.last, DateTime(2026, 7, 19, 14));
  });

  test('cadence notification IDs are stable and unique per Bell time', () {
    final first = DateTime(2026, 7, 19, 10);
    final second = DateTime(2026, 7, 19, 11);

    expect(
      NotificationService.cadenceNotificationId(first),
      NotificationService.cadenceNotificationId(first),
    );
    expect(
      NotificationService.cadenceNotificationId(first),
      isNot(NotificationService.cadenceNotificationId(second)),
    );
    expect(
      NotificationService.cadenceTimeFromNotificationId(
        NotificationService.cadenceNotificationId(first),
      ),
      first,
    );
  });
}
