import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/cadence_schedule.dart';
import 'package:recess/src/core/database.dart';
import 'package:recess/src/core/models.dart';

void main() {
  const base = WorkSchedule(
    startMinutes: 9 * 60,
    endMinutes: 12 * 60,
    cadenceMinutes: 60,
  );

  test('Mon-Fri is the default and weekends are excluded', () {
    expect(base.workDays, WorkSchedule.defaultWorkDays);
    final times = scheduledBellTimesInRange(
      schedule: base,
      preferences: const RecessPreferences(),
      start: DateTime(2026, 7, 20),
      end: DateTime(2026, 7, 27),
    );
    expect(times, hasLength(10));
    expect(times.any((time) => time.weekday > DateTime.friday), isFalse);
  });

  test('weekend-only schedules skip directly to Saturday', () {
    const schedule = WorkSchedule(
      startMinutes: 9 * 60,
      endMinutes: 12 * 60,
      workDays: {DateTime.saturday, DateTime.sunday},
    );
    final times = cadenceBellTimes(
      schedule: schedule,
      now: DateTime(2026, 7, 20, 9),
    );
    expect(times.first, DateTime(2026, 7, 25, 10));
    expect(times.every((time) => time.weekday >= DateTime.saturday), isTrue);
  });

  test('four-day schedules omit the unselected weekday', () {
    const schedule = WorkSchedule(
      startMinutes: 9 * 60,
      endMinutes: 11 * 60,
      workDays: {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
      },
    );
    final times = scheduledBellTimesInRange(
      schedule: schedule,
      preferences: const RecessPreferences(),
      start: DateTime(2026, 7, 20),
      end: DateTime(2026, 7, 27),
    );
    expect(times, hasLength(4));
    expect(times.any((time) => time.weekday == DateTime.friday), isFalse);
  });

  test('changing work days recalculates the next Bell', () {
    final weekday = cadenceBellTimes(
      schedule: base,
      now: DateTime(2026, 7, 24, 11),
    );
    const weekend = WorkSchedule(
      startMinutes: 9 * 60,
      endMinutes: 12 * 60,
      workDays: {DateTime.saturday},
    );
    final changed = cadenceBellTimes(
      schedule: weekend,
      now: DateTime(2026, 7, 24, 11),
    );
    expect(weekday.first, DateTime(2026, 7, 27, 10));
    expect(changed.first, DateTime(2026, 7, 25, 10));
  });

  test('existing installs migrate to the Mon-Fri default', () async {
    final directory = await Directory.systemTemp.createTemp('recess-work-days');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}recess.sqlite');
    final database = RecessDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          raw.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          raw.execute(
            "INSERT INTO settings(key, value) VALUES('work_start', '540'), ('work_end', '1020')",
          );
          raw.userVersion = 4;
        },
      ),
    );
    addTearDown(database.close);

    final schedule = await database.schedule();

    expect(schedule!.workDays, WorkSchedule.defaultWorkDays);
    expect(await database.setting('work_days'), '1,2,3,4,5');
  });
}
