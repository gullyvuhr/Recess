import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/database.dart';
import 'package:recess/src/core/models.dart';

void main() {
  test('preferences have calm defaults', () async {
    final database = RecessDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final preferences = await database.preferences();

    expect(preferences.durationMinutes, 5);
    expect(preferences.exerciseDifficulty, ExerciseDifficulty.standard);
    expect(preferences.bellSound, BellSound.schoolBell);
    expect(preferences.quietHoursEnabled, isFalse);
    expect(preferences.quietHoursStartMinutes, 22 * 60);
    expect(preferences.quietHoursEndMinutes, 7 * 60);
    expect(preferences.notificationsEnabled, isTrue);
  });

  test('all preferences survive a database restart', () async {
    final directory = await Directory.systemTemp.createTemp('recess-settings');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}recess.sqlite');
    final first = RecessDatabase(NativeDatabase(file));
    await first.savePreferences(
      const RecessPreferences(
        durationMinutes: 15,
        exerciseDifficulty: ExerciseDifficulty.challenging,
        bellSound: BellSound.gentleChime,
        quietHoursEnabled: true,
        quietHoursStartMinutes: 21 * 60 + 30,
        quietHoursEndMinutes: 6 * 60 + 45,
        notificationsEnabled: false,
      ),
    );
    await first.close();

    final second = RecessDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final restored = await second.preferences();

    expect(restored.durationMinutes, 15);
    expect(restored.exerciseDifficulty, ExerciseDifficulty.challenging);
    expect(restored.bellSound, BellSound.gentleChime);
    expect(restored.quietHoursEnabled, isTrue);
    expect(restored.quietHoursStartMinutes, 21 * 60 + 30);
    expect(restored.quietHoursEndMinutes, 6 * 60 + 45);
    expect(restored.notificationsEnabled, isFalse);
  });

  test('unsupported persisted values fall back safely', () async {
    final database = RecessDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.setSetting('recess_duration', '99');
    await database.setSetting('exercise_difficulty', 'extreme');
    await database.setSetting('bell_sound', 'air_horn');

    final restored = await database.preferences();

    expect(restored.durationMinutes, 5);
    expect(restored.exerciseDifficulty, ExerciseDifficulty.standard);
    expect(restored.bellSound, BellSound.schoolBell);
  });
}
