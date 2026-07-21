import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/database.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/notifications.dart';
import 'package:recess/src/core/session_service.dart';
import 'package:recess/src/exercises/exercise.dart';
import 'package:recess/src/exercises/exercise_repository.dart';
import 'package:recess/src/exercises/exercise_service.dart';

void main() {
  late RecessDatabase database;
  late FakeNotifications notifications;
  late DateTime now;
  late RecessSessionService service;

  setUp(() async {
    database = RecessDatabase(NativeDatabase.memory());
    notifications = FakeNotifications();
    now = DateTime(2026, 7, 19, 10);
    service = RecessSessionService(
      database: database,
      notifications: notifications,
      exercises: ExerciseService(
        catalog: StaticCatalog(_testExercises),
        random: Random(1),
      ),
      clock: () => now,
    );
    await database.saveSchedule(
      const WorkSchedule(startMinutes: 9 * 60, endMinutes: 17 * 60),
    );
  });

  tearDown(() => database.close());

  test('Start Recess begins one persisted session', () async {
    final scheduled = await _session(database, now);

    final active = await service.start(scheduled.id);

    expect(active.id, scheduled.id);
    expect(active.status, RecessSessionStatus.active);
    expect(active.startedAt, now);
    expect(active.completedAt, isNull);
    expect(active.exerciseId, isNotNull);
    final assignedExerciseId = active.exerciseId;
    await expectLater(service.start(scheduled.id), throwsStateError);
    expect(await _sessionCount(database), 1);
    expect(
        (await database.session(scheduled.id))!.exerciseId, assignedExerciseId);
  });

  test('persisted difficulty controls the assigned exercise', () async {
    await database.savePreferences(
      const RecessPreferences(
        exerciseDifficulty: ExerciseDifficulty.challenging,
      ),
    );
    service = RecessSessionService(
      database: database,
      notifications: notifications,
      exercises: const ExerciseSelector(
        catalog: StaticCatalog([
          Exercise(
            id: 'easy-option',
            title: 'Easy Option',
            description: 'Move gently.',
            category: ExerciseCategory.mobility,
            difficulty: ExerciseDifficulty.easy,
            estimatedDuration: 3,
          ),
          Exercise(
            id: 'challenging-option',
            title: 'Challenging Option',
            description: 'Move with purpose.',
            category: ExerciseCategory.strength,
            difficulty: ExerciseDifficulty.challenging,
            estimatedDuration: 5,
            requiresStanding: true,
          ),
        ]),
      ),
      clock: () => now,
    );
    final scheduled = await _session(database, now);

    final active = await service.start(scheduled.id);

    expect(active.status, RecessSessionStatus.active);
    expect(active.exerciseId, 'challenging-option');
  });

  test('manual Bell uses the persisted Bell sound', () async {
    await database.savePreferences(
      const RecessPreferences(bellSound: BellSound.gentleChime),
    );
    await _session(database, now);

    await service.ringBellNow();

    expect(notifications.manualSounds, [BellSound.gentleChime]);
  });

  test('scheduled Bells use the persisted Bell sound', () async {
    await database.savePreferences(
      const RecessPreferences(bellSound: BellSound.coachWhistle),
    );
    await _session(database, now);
    notifications.cadenceSounds.clear();

    await service.refreshBellSound();

    expect(notifications.cadenceSounds, isNotEmpty);
    expect(
      notifications.cadenceSounds,
      everyElement(BellSound.coachWhistle),
    );
  });

  test('Give me a minute defers the same session for 5 minutes', () async {
    final scheduled = await _session(database, now);

    final deferred = (await service.defer(
      scheduled.id,
      RecessDeferralType.fiveMinutes,
    ))
        .value;

    expect(deferred.id, scheduled.id);
    expect(deferred.status, RecessSessionStatus.deferred);
    expect(deferred.deferralType, RecessDeferralType.fiveMinutes);
    expect(deferred.scheduledAt, now.add(const Duration(minutes: 5)));
    expect(notifications.deferred.single.sessionId, scheduled.id);
    expect(notifications.deferred.single.scheduledAt, deferred.scheduledAt);
    expect(
        notifications.cadence.every((call) => call.sessionId == scheduled.id),
        isTrue);
    expect(notifications.cadence.first.scheduledAt, DateTime(2026, 7, 19, 11));
  });

  test('After this defers the same session for 15 minutes', () async {
    final scheduled = await _session(database, now);

    final deferred = (await service.defer(
      scheduled.id,
      RecessDeferralType.afterThis,
    ))
        .value;

    expect(deferred.id, scheduled.id);
    expect(deferred.status, RecessSessionStatus.deferred);
    expect(deferred.deferralType, RecessDeferralType.afterThis);
    expect(deferred.scheduledAt, now.add(const Duration(minutes: 15)));
    expect(notifications.deferred.single.scheduledAt, deferred.scheduledAt);
    expect(notifications.cadence.first.scheduledAt, DateTime(2026, 7, 19, 11));
  });

  test('notification failure is reported without losing the deferral',
      () async {
    notifications.succeeds = false;
    final scheduled = await _session(database, now);

    final result = await service.defer(
      scheduled.id,
      RecessDeferralType.fiveMinutes,
    );

    expect(result.notificationSucceeded, isFalse);
    expect(result.value.status, RecessSessionStatus.deferred);
    expect((await database.session(scheduled.id))!.status,
        RecessSessionStatus.deferred);
  });

  test('Rain check is persisted and resumes normal Bell cadence', () async {
    final scheduled = await _session(database, now);

    final rainChecked = (await service.rainCheck(scheduled.id)).value;

    expect(rainChecked.id, scheduled.id);
    expect(rainChecked.status, RecessSessionStatus.rainChecked);
    expect(rainChecked.startedAt, isNull);
    expect(rainChecked.completedAt, isNull);
    expect(rainChecked.exerciseId, isNull);
    expect(notifications.cadence.first.scheduledAt, DateTime(2026, 7, 19, 11));
    final progress = await database.todayProgress(now: now);
    expect(progress.started, 0);
    expect(progress.completed, 0);
    expect(progress.rainChecks, 1);
  });

  test('completion closes the active session lifecycle', () async {
    final scheduled = await _session(database, now);
    final active = await service.start(scheduled.id);
    now = now.add(const Duration(minutes: 20));

    final completed = (await service.complete(active.id)).value;

    expect(completed.id, scheduled.id);
    expect(completed.status, RecessSessionStatus.completed);
    expect(completed.startedAt, DateTime(2026, 7, 19, 10));
    expect(completed.completedAt, now);
    expect(completed.exerciseId, active.exerciseId);
    expect(notifications.cadence.first.scheduledAt, DateTime(2026, 7, 19, 11));
  });

  test('10:00 completion at 10:06 preserves the work-start cadence', () async {
    now = DateTime(2026, 7, 19, 9, 50);
    final restored = (await service.restore()).value!;
    expect(restored.scheduledAt, DateTime(2026, 7, 19, 10));

    now = DateTime(2026, 7, 19, 10);
    notifications.deliver(now);
    expect((await service.openBell('bell:${restored.id}'))!.id, restored.id);
    await service.start(restored.id);
    expect(
      notifications.pendingTimes,
      contains(DateTime(2026, 7, 19, 11)),
    );

    now = DateTime(2026, 7, 19, 10, 6);
    final result = await service.complete(restored.id);
    final next = await database.openSession();

    expect(result.notificationSucceeded, isTrue);
    expect(next, isNotNull);
    expect(next!.id, isNot(restored.id));
    expect(next.scheduledAt, DateTime(2026, 7, 19, 11));
    expect(notifications.pendingTimes.first, DateTime(2026, 7, 19, 11));
    expect(
      notifications.cadence
          .singleWhere(
            (call) => call.scheduledAt == DateTime(2026, 7, 19, 11),
          )
          .sessionId,
      next.id,
    );
    expect(notifications.pendingTimes,
        isNot(contains(DateTime(2026, 7, 19, 10, 6))));
    expect(notifications.pendingIds.toSet(),
        hasLength(notifications.pendingIds.length));
  });

  test('repeated cycles preserve noon and later cadence Bells', () async {
    now = DateTime(2026, 7, 19, 9, 50);
    final ten = (await service.restore()).value!;
    now = DateTime(2026, 7, 19, 10);
    notifications.deliver(now);
    await service.start(ten.id);
    now = DateTime(2026, 7, 19, 10, 6);
    await service.complete(ten.id);

    final eleven = (await database.openSession())!;
    now = DateTime(2026, 7, 19, 11);
    notifications.deliver(now);
    await service.openBell('bell:${eleven.id}');
    await service.start(eleven.id);
    now = DateTime(2026, 7, 19, 11, 6);
    await service.complete(eleven.id);

    expect(notifications.pendingTimes.first, DateTime(2026, 7, 19, 12));
    expect(notifications.pendingTimes, contains(DateTime(2026, 7, 19, 16)));
    expect(notifications.pendingIds.toSet(),
        hasLength(notifications.pendingIds.length));
  });

  test('limited cancellation cannot silently remove the next Bell', () async {
    now = DateTime(2026, 7, 19, 9, 50);
    await service.restore();
    notifications.limitNextCancellation = true;
    now = DateTime(2026, 7, 19, 10, 30);

    final result = await service.restore();

    expect(result.notificationSucceeded, isTrue);
    expect(notifications.pendingTimes, contains(DateTime(2026, 7, 19, 11)));
    expect(notifications.pendingIds.toSet(),
        hasLength(notifications.pendingIds.length));
  });

  test("today's progress is derived from persisted session timestamps",
      () async {
    final first = await _session(database, DateTime(2026, 7, 19, 9));
    await database.startSession(
      first.id,
      DateTime(2026, 7, 19, 9, 5),
      'shoulder-rolls',
    );
    await database.completeSession(first.id, DateTime(2026, 7, 19, 9, 25));

    final rain = await _session(database, DateTime(2026, 7, 19, 12));
    await database.rainCheckSession(rain.id, DateTime(2026, 7, 19, 12));

    final yesterday = await _session(database, DateTime(2026, 7, 18, 12));
    await database.startSession(
      yesterday.id,
      DateTime(2026, 7, 18, 12),
      'long-exhale',
    );
    await database.completeSession(yesterday.id, DateTime(2026, 7, 18, 12, 10));

    final active = await _session(database, DateTime(2026, 7, 19, 11));
    await database.startSession(
      active.id,
      DateTime(2026, 7, 19, 11, 5),
      'shoulder-rolls',
    );

    final progress = await database.todayProgress(now: now);

    expect(progress.started, 2);
    expect(progress.completed, 1);
    expect(progress.rainChecks, 1);
  });

  test('a returned deferred Bell cannot be deferred again', () async {
    final scheduled = await _session(database, now);
    final deferred = (await service.defer(
      scheduled.id,
      RecessDeferralType.fiveMinutes,
    ))
        .value;

    final opened = await service.openBell('bell:deferred:${deferred.id}');

    expect(opened, isNotNull);
    expect(opened!.canDefer, isFalse);
    await expectLater(
      service.defer(deferred.id, RecessDeferralType.afterThis),
      throwsStateError,
    );
    expect(notifications.deferred, hasLength(1));
  });

  test('session assignment persists one exercise and avoids the last one',
      () async {
    final firstScheduled = await _session(database, now);
    final first = await service.start(firstScheduled.id);
    now = now.add(const Duration(minutes: 5));
    await service.complete(first.id);
    final secondScheduled = await database.openSession();

    service = RecessSessionService(
      database: database,
      notifications: notifications,
      exercises: ExerciseService(
        catalog: StaticCatalog(_testExercises),
        random: Random(2),
      ),
      clock: () => now,
    );

    final second = await service.start(secondScheduled!.id);

    expect(first.exerciseId, isNotNull);
    expect(second.exerciseId, isNotNull);
    expect(second.exerciseId, isNot(first.exerciseId));
    expect((await database.session(second.id))!.exerciseId, second.exerciseId);
  });

  test('restore and repeated notification taps reuse one session', () async {
    await service.restore();
    final original = await database.openSession();
    final firstCadence = List<ScheduledCall>.of(notifications.cadence);

    await service.restore();
    expect(notifications.cadence, hasLength(firstCadence.length));
    final firstOpen = await service.openBell('bell:${original!.id}');
    final secondOpen = await service.openBell('bell:${original.id}');
    final active = await service.start(original.id);
    final reopenedActive = await service.openBell('bell:${original.id}');

    expect(firstOpen?.id, original.id);
    expect(secondOpen?.id, original.id);
    expect(active.status, RecessSessionStatus.active);
    expect(reopenedActive, isNull);
    expect(await _sessionCount(database), 1);
    expect(notifications.cadence, isNotEmpty);
    expect(notifications.cadenceCancellationCount, 2);
  });

  test('restore cancels obsolete cadence bells before rebuilding', () async {
    await service.restore();
    final initialTimes =
        notifications.cadence.map((call) => call.scheduledAt).toList();

    now = DateTime(2026, 7, 19, 14, 30);
    await service.restore();

    expect(notifications.cadenceCancellationCount, 2);
    expect(notifications.cadence.first.scheduledAt, DateTime(2026, 7, 19, 15));
    expect(
      notifications.cadence.any(
        (call) =>
            initialTimes.contains(call.scheduledAt) &&
            !call.scheduledAt.isAfter(now),
      ),
      isFalse,
    );
  });

  test('saved cadence interval controls rebuilt notification times', () async {
    await database.saveSchedule(
      const WorkSchedule(
        startMinutes: 9 * 60,
        endMinutes: 17 * 60,
        cadenceMinutes: 90,
      ),
    );

    await service.restore();

    expect(
      notifications.cadence.take(4).map((call) => call.scheduledAt),
      [
        DateTime(2026, 7, 19, 10, 30),
        DateTime(2026, 7, 19, 12),
        DateTime(2026, 7, 19, 13, 30),
        DateTime(2026, 7, 19, 15),
      ],
    );
  });

  test('completion without an active session is rejected safely', () async {
    final scheduled = await _session(database, now);

    await expectLater(service.complete(scheduled.id), throwsStateError);

    expect((await database.session(scheduled.id))!.status,
        RecessSessionStatus.scheduled);
    expect(await _sessionCount(database), 1);
  });

  test('missing and invalid notification session IDs are ignored', () async {
    expect(await service.openBell('bell:not-a-number'), isNull);
    expect(await service.openBell('bell:999999'), isNull);
    expect(await service.openBell('bell:deferred:999999'), isNull);
    expect(await service.openBell('bell:immediate:999999'), isNull);
    expect(await service.openBell('unrelated'), isNull);
  });

  test('cadence uses the next local calendar day at the scheduled time',
      () async {
    now = DateTime(2026, 3, 8, 17);

    await service.restore();

    final scheduled = await database.openSession();
    expect(scheduled!.scheduledAt, DateTime(2026, 3, 9, 10));
  });

  test('schema migration preserves legacy local progress rows', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('recess-migration');
    final file =
        File('${directory.path}${Platform.pathSeparator}recess.sqlite');
    addTearDown(() => directory.delete(recursive: true));
    final migrated = RecessDatabase(
      NativeDatabase(
        file,
        setup: (rawDatabase) {
          rawDatabase.execute('''
            CREATE TABLE recess_entries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              status TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          rawDatabase.execute(
            'INSERT INTO recess_entries(status, created_at) VALUES(?, ?)',
            ['completed', now.millisecondsSinceEpoch],
          );
          rawDatabase.userVersion = 1;
        },
      ),
    );

    final firstProgress = await migrated.todayProgress(now: now);
    final legacySession = await migrated.session(1);
    await migrated.close();

    final reopened = RecessDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final secondProgress = await reopened.todayProgress(now: now);

    expect(legacySession, isNotNull);
    expect(legacySession!.status, RecessSessionStatus.completed);
    expect(firstProgress.started, 1);
    expect(firstProgress.completed, 1);
    expect(secondProgress.started, 1);
    expect(secondProgress.completed, 1);
    expect(await _sessionCount(reopened), 1);
    final legacyCount = await reopened
        .customSelect('SELECT COUNT(*) AS total FROM recess_entries')
        .getSingle();
    expect(legacyCount.read<int>('total'), 1);
  });

  test('schema v3 migrates and repairs an active v2 session', () async {
    await database.close();
    final migrated = RecessDatabase(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          rawDatabase.execute(
            "INSERT INTO settings(key, value) VALUES('work_start', '540'), ('work_end', '1020')",
          );
          rawDatabase.execute('''
            CREATE TABLE recess_sessions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              scheduled_at INTEGER NOT NULL,
              started_at INTEGER,
              completed_at INTEGER,
              status TEXT NOT NULL,
              deferral_type TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          rawDatabase.execute(
            "INSERT INTO recess_sessions(scheduled_at, started_at, status, created_at) VALUES(?, ?, 'active', ?)",
            [
              now.millisecondsSinceEpoch,
              now.millisecondsSinceEpoch,
              now.millisecondsSinceEpoch,
            ],
          );
          rawDatabase.userVersion = 2;
        },
      ),
    );
    addTearDown(migrated.close);
    final migratedService = RecessSessionService(
      database: migrated,
      notifications: notifications,
      exercises: ExerciseService(
        catalog: StaticCatalog(_testExercises),
        random: Random(1),
      ),
      clock: () => now,
    );

    final restored = (await migratedService.restore()).value;
    final restoredAgain = (await migratedService.restore()).value;

    expect(restored!.status, RecessSessionStatus.active);
    expect(restored.exerciseId, isNotNull);
    expect(restoredAgain!.exerciseId, restored.exerciseId);
    expect(
        (await migrated.session(restored.id))!.exerciseId, restored.exerciseId);
  });
}

Future<RecessSession> _session(
  RecessDatabase database,
  DateTime scheduledAt,
) =>
    database.createSession(scheduledAt: scheduledAt, createdAt: scheduledAt);

Future<int> _sessionCount(RecessDatabase database) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS total FROM recess_sessions')
      .getSingle();
  return row.read<int>('total');
}

class ScheduledCall {
  const ScheduledCall(this.sessionId, this.scheduledAt);

  final int sessionId;
  final DateTime scheduledAt;

  int get id => NotificationService.cadenceNotificationId(scheduledAt);
}

class FakeNotifications implements BellNotifications {
  final cadence = <ScheduledCall>[];
  final deferred = <ScheduledCall>[];
  final opened = StreamController<String>.broadcast();
  final manualSounds = <BellSound>[];
  final cadenceSounds = <BellSound>[];
  final deferredSounds = <BellSound>[];
  var deferredCancellationCount = 0;
  var cadenceCancellationCount = 0;
  var succeeds = true;
  var limitNextCancellation = false;

  List<DateTime> get pendingTimes =>
      cadence.map((call) => call.scheduledAt).toList()..sort();
  List<int> get pendingIds => cadence.map((call) => call.id).toList()..sort();

  void deliver(DateTime scheduledAt) {
    cadence.removeWhere((call) => call.scheduledAt == scheduledAt);
  }

  @override
  Stream<String> get openedPayloads => opened.stream;

  @override
  Future<void> cancelDeferredBell() async {
    deferredCancellationCount++;
  }

  @override
  Future<void> cancelCadenceBell({Set<int> retaining = const {}}) async {
    cadenceCancellationCount++;
    if (limitNextCancellation) {
      limitNextCancellation = false;
      final obsolete =
          cadence.indexWhere((call) => !retaining.contains(call.id));
      if (obsolete >= 0) cadence.removeAt(obsolete);
      return;
    }
    cadence.removeWhere((call) => !retaining.contains(call.id));
  }

  @override
  Future<List<PendingCadenceBell>> pendingCadenceBells() async => cadence
      .map((call) =>
          PendingCadenceBell(id: call.id, scheduledAt: call.scheduledAt))
      .toList(growable: false);

  @override
  Future<bool> requestPermission() async => succeeds;

  @override
  Future<bool> ringBells(
    int sessionId, {
    required bool deferred,
    BellSound sound = BellSound.schoolBell,
  }) async {
    manualSounds.add(sound);
    return succeeds;
  }

  @override
  Future<bool> scheduleCadenceBell(
    int sessionId,
    DateTime scheduledAt, {
    BellSound sound = BellSound.schoolBell,
  }) async {
    cadenceSounds.add(sound);
    cadence.removeWhere(
      (call) =>
          call.id == NotificationService.cadenceNotificationId(scheduledAt),
    );
    cadence.add(ScheduledCall(sessionId, scheduledAt));
    return succeeds;
  }

  @override
  Future<bool> scheduleDeferredBell(
    int sessionId,
    DateTime scheduledAt, {
    BellSound sound = BellSound.schoolBell,
  }) async {
    deferredSounds.add(sound);
    deferred.add(ScheduledCall(sessionId, scheduledAt));
    return succeeds;
  }

  @override
  String? takeInitialPayload() => null;
}

class StaticCatalog implements ExerciseCatalog {
  const StaticCatalog(this.exercises);

  final List<Exercise> exercises;

  @override
  Future<List<Exercise>> load() async => exercises;
}

const _testExercises = [
  Exercise(
    id: 'shoulder-rolls',
    title: 'Shoulder Rolls',
    instruction: 'Roll your shoulders slowly.',
    durationMinutes: 2,
    category: ExerciseCategory.movement,
    availableIndoors: true,
    availableOutdoors: true,
  ),
  Exercise(
    id: 'long-exhale',
    title: 'Long Exhale',
    instruction: 'Let each exhale last a little longer.',
    durationMinutes: 2,
    category: ExerciseCategory.breathing,
    availableIndoors: true,
    availableOutdoors: true,
  ),
];
