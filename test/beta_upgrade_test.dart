import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/database.dart';
import 'package:recess/src/core/models.dart';

void main() {
  test('beta upgrade preserves settings, schedule, and completed history',
      () async {
    final directory = await Directory.systemTemp.createTemp('recess-upgrade');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}recess.sqlite');
    final scheduledAt = DateTime(2026, 7, 20, 10);

    final beforeUpgrade = RecessDatabase(NativeDatabase(file));
    await beforeUpgrade.saveSchedule(
      const WorkSchedule(
        startMinutes: 8 * 60,
        endMinutes: 17 * 60,
        cadenceMinutes: 90,
      ),
    );
    await beforeUpgrade.savePreferences(
      const RecessPreferences(
        durationMinutes: 10,
        exerciseDifficulty: ExerciseDifficulty.challenging,
        bellSound: BellSound.gentleChime,
        quietHoursEnabled: true,
        quietHoursStartMinutes: 21 * 60,
        quietHoursEndMinutes: 7 * 60,
        notificationsEnabled: false,
      ),
    );
    final session = await beforeUpgrade.createSession(
      scheduledAt: scheduledAt,
      createdAt: scheduledAt.subtract(const Duration(minutes: 5)),
      cadenceMinutes: 90,
    );
    await beforeUpgrade.startSession(
      session.id,
      scheduledAt.add(const Duration(minutes: 1)),
      'air-squats',
    );
    await beforeUpgrade.completeSession(
      session.id,
      scheduledAt.add(const Duration(minutes: 11)),
    );
    await beforeUpgrade.close();

    final afterUpgrade = RecessDatabase(NativeDatabase(file));
    addTearDown(afterUpgrade.close);
    final schedule = await afterUpgrade.schedule();
    final preferences = await afterUpgrade.preferences();
    final history = await afterUpgrade.completedSessions();

    expect(schedule?.startMinutes, 8 * 60);
    expect(schedule?.endMinutes, 17 * 60);
    expect(schedule?.cadenceMinutes, 90);
    expect(preferences.durationMinutes, 10);
    expect(preferences.exerciseDifficulty, ExerciseDifficulty.challenging);
    expect(preferences.bellSound, BellSound.gentleChime);
    expect(preferences.quietHoursEnabled, isTrue);
    expect(preferences.notificationsEnabled, isFalse);
    expect(history, hasLength(1));
    expect(history.single.exerciseId, 'air-squats');
    expect(history.single.completedDuration, const Duration(minutes: 10));
  });
}
