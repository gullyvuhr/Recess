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

  group('Quiet Hours', () {
    const disabled = RecessPreferences(
      quietHoursStartMinutes: 9 * 60,
      quietHoursEndMinutes: 17 * 60,
    );
    const sameDay = RecessPreferences(
      quietHoursEnabled: true,
      quietHoursStartMinutes: 12 * 60,
      quietHoursEndMinutes: 14 * 60,
    );
    const overnight = RecessPreferences(
      quietHoursEnabled: true,
      quietHoursStartMinutes: 22 * 60,
      quietHoursEndMinutes: 7 * 60,
    );

    test('disabled preference never suppresses a Bell', () {
      expect(isDuringQuietHours(DateTime(2026, 7, 19, 12), disabled), isFalse);
    });

    test('same-day range preserves Bells before and after it', () {
      expect(
        isDuringQuietHours(DateTime(2026, 7, 19, 11, 59), sameDay),
        isFalse,
      );
      expect(
        isDuringQuietHours(DateTime(2026, 7, 19, 14), sameDay),
        isFalse,
      );
    });

    test('same-day range suppresses its start and interior', () {
      expect(isDuringQuietHours(DateTime(2026, 7, 19, 12), sameDay), isTrue);
      expect(
        isDuringQuietHours(DateTime(2026, 7, 19, 13, 59), sameDay),
        isTrue,
      );
    });

    test('overnight range crosses midnight with an exclusive end', () {
      expect(
        isDuringQuietHours(DateTime(2026, 7, 19, 21, 59), overnight),
        isFalse,
      );
      expect(
        isDuringQuietHours(DateTime(2026, 7, 19, 22), overnight),
        isTrue,
      );
      expect(
        isDuringQuietHours(DateTime(2026, 7, 20, 1), overnight),
        isTrue,
      );
      expect(
        isDuringQuietHours(DateTime(2026, 7, 20, 7), overnight),
        isFalse,
      );
    });

    test('uses local wall-clock fields across a DST transition date', () {
      expect(
        isDuringQuietHours(DateTime(2026, 3, 8, 6, 59), overnight),
        isTrue,
      );
      expect(
        isDuringQuietHours(DateTime(2026, 3, 8, 7), overnight),
        isFalse,
      );
    });
  });
}
