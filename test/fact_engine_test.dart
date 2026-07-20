import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/database.dart';
import 'package:recess/src/core/models.dart';

void main() {
  late RecessDatabase database;

  setUp(() {
    database = RecessDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('completed sessions remain after future Bells are scheduled', () async {
    final completed = await _completedSession(
      database,
      scheduledAt: DateTime(2026, 7, 19, 9),
      startedAt: DateTime(2026, 7, 19, 9, 5),
      completedAt: DateTime(2026, 7, 19, 9, 15),
    );

    final future = await database.createSession(
      scheduledAt: DateTime(2026, 7, 19, 11),
      createdAt: DateTime(2026, 7, 19, 10),
      cadenceMinutes: 60,
    );

    expect((await database.session(completed.id))!.status,
        RecessSessionStatus.completed);
    expect((await database.completedSessions()).single.id, completed.id);
    expect(future.id, isNot(completed.id));
    expect(await _sessionCount(database), 2);
  });

  test('rain-checked sessions remain available', () async {
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 19, 9),
      createdAt: DateTime(2026, 7, 19, 8),
    );
    final rainTime = DateTime(2026, 7, 19, 9, 2);
    final rainChecked = await database.rainCheckSession(session.id, rainTime);
    await database.createSession(
      scheduledAt: DateTime(2026, 7, 19, 10),
      createdAt: DateTime(2026, 7, 19, 9, 3),
    );

    expect(rainChecked.rainCheckedAt, rainTime);
    expect((await database.rainCheckedSessions()).single.id, session.id);
  });

  test('original schedule and cumulative deferrals are preserved', () async {
    final original = DateTime(2026, 7, 19, 10);
    final session = await database.createSession(
      scheduledAt: original,
      createdAt: DateTime(2026, 7, 19, 9),
      cadenceMinutes: 45,
    );
    await database.deferSession(
      session.id,
      RecessDeferralType.fiveMinutes,
      DateTime(2026, 7, 19, 10, 6),
      DateTime(2026, 7, 19, 10, 1),
    );
    final twiceDeferred = await database.deferSession(
      session.id,
      RecessDeferralType.afterThis,
      DateTime(2026, 7, 19, 10, 17),
      DateTime(2026, 7, 19, 10, 2),
    );

    expect(twiceDeferred.originalScheduledAt, original);
    expect(twiceDeferred.scheduledAt, DateTime(2026, 7, 19, 10, 17));
    expect(twiceDeferred.deferralType, RecessDeferralType.afterThis);
    expect(twiceDeferred.deferralCount, 2);
    expect(twiceDeferred.lastDeferredAt, DateTime(2026, 7, 19, 10, 2));
    expect(twiceDeferred.cadenceMinutes, 45);
    expect((await database.deferredSessions()).single.id, session.id);
  });

  test('acknowledgement, response delay, and duration remain queryable',
      () async {
    final scheduled = DateTime(2026, 7, 19, 10);
    final session = await database.createSession(
      scheduledAt: scheduled,
      createdAt: DateTime(2026, 7, 19, 9),
    );
    await database.markBellOpened(session.id, DateTime(2026, 7, 19, 10, 1));
    await database.markBellOpened(session.id, DateTime(2026, 7, 19, 10, 2));
    await database.startSession(
      session.id,
      DateTime(2026, 7, 19, 10, 5),
      'shoulder-rolls',
    );
    final completed = await database.completeSession(
      session.id,
      DateTime(2026, 7, 19, 10, 20),
    );

    expect(completed.originalScheduledAt, scheduled);
    expect(completed.acknowledgedAt, DateTime(2026, 7, 19, 10, 1));
    expect(completed.responseDelay, const Duration(minutes: 5));
    expect(completed.completedDuration, const Duration(minutes: 15));
    expect(completed.workdayDate, DateTime(2026, 7, 19));
  });

  test('date-range and local-day queries use original Bell time', () async {
    await _completedSession(
      database,
      scheduledAt: DateTime(2026, 7, 18, 9),
      startedAt: DateTime(2026, 7, 18, 9, 5),
      completedAt: DateTime(2026, 7, 18, 9, 10),
    );
    final nineteenth = await _completedSession(
      database,
      scheduledAt: DateTime(2026, 7, 19, 10),
      startedAt: DateTime(2026, 7, 19, 10, 5),
      completedAt: DateTime(2026, 7, 19, 10, 15),
    );
    final twentieth = await _completedSession(
      database,
      scheduledAt: DateTime(2026, 7, 20, 11),
      startedAt: DateTime(2026, 7, 20, 11, 5),
      completedAt: DateTime(2026, 7, 20, 11, 20),
    );

    expect(
      (await database.sessionsForDay(DateTime(2026, 7, 19)))
          .map((session) => session.id),
      [nineteenth.id],
    );
    expect(
      (await database.sessionsInRange(
        DateTime(2026, 7, 19),
        DateTime(2026, 7, 21),
      ))
          .map((session) => session.id),
      [twentieth.id, nineteenth.id],
    );
  });

  test('status aggregates and averages summarize persisted facts', () async {
    final first = await _completedSession(
      database,
      scheduledAt: DateTime(2026, 7, 18, 9),
      startedAt: DateTime(2026, 7, 18, 9, 5),
      completedAt: DateTime(2026, 7, 18, 9, 15),
    );
    final second = await _completedSession(
      database,
      scheduledAt: DateTime(2026, 7, 19, 9),
      startedAt: DateTime(2026, 7, 19, 9, 15),
      completedAt: DateTime(2026, 7, 19, 9, 35),
    );
    final rain = await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 9),
      createdAt: DateTime(2026, 7, 20, 8),
    );
    await database.rainCheckSession(rain.id, DateTime(2026, 7, 20, 9, 1));

    final counts = await database.sessionCountsByStatus();
    expect(counts[RecessSessionStatus.completed], 2);
    expect(counts[RecessSessionStatus.rainChecked], 1);
    expect(counts[RecessSessionStatus.scheduled], 0);
    expect(await database.averageCompletedRecessDuration(),
        const Duration(minutes: 15));
    expect(await database.averageResponseDelay(), const Duration(minutes: 10));
    expect((await database.mostRecentCompletedSession())!.id, second.id);
    expect((await database.completedSessions()).map((session) => session.id),
        [second.id, first.id]);
  });

  test('terminal historical sessions reject further mutation', () async {
    final completed = await _completedSession(
      database,
      scheduledAt: DateTime(2026, 7, 19, 9),
      startedAt: DateTime(2026, 7, 19, 9, 1),
      completedAt: DateTime(2026, 7, 19, 9, 5),
    );

    expect(
      await database.markBellOpened(completed.id, DateTime(2026, 7, 19, 10)),
      isNull,
    );
    await expectLater(
      database.rainCheckSession(completed.id, DateTime(2026, 7, 19, 10)),
      throwsStateError,
    );
    expect((await database.session(completed.id))!.completedAt,
        DateTime(2026, 7, 19, 9, 5));
  });

  test('schema v4 migrates existing facts and preserves settings', () async {
    await database.close();
    final scheduled = DateTime(2026, 7, 19, 10, 5);
    final migrated = RecessDatabase(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          rawDatabase.execute(
            "INSERT INTO settings(key, value) VALUES('work_start', '540'), ('work_end', '1020'), ('cadence_minutes', '90')",
          );
          rawDatabase.execute('''
            CREATE TABLE recess_sessions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              scheduled_at INTEGER NOT NULL,
              started_at INTEGER,
              completed_at INTEGER,
              status TEXT NOT NULL,
              deferral_type TEXT,
              exercise_id TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          rawDatabase.execute(
            "INSERT INTO recess_sessions(scheduled_at, status, deferral_type, created_at) VALUES(?, 'deferred', 'fiveMinutes', ?)",
            [
              scheduled.millisecondsSinceEpoch,
              DateTime(2026, 7, 19, 9).millisecondsSinceEpoch,
            ],
          );
          rawDatabase.userVersion = 3;
        },
      ),
    );
    addTearDown(migrated.close);

    final session = await migrated.session(1);
    final schedule = await migrated.schedule();

    expect(session!.status, RecessSessionStatus.deferred);
    expect(session.originalScheduledAt, scheduled);
    expect(session.scheduledAt, scheduled);
    expect(session.deferralCount, 1);
    expect(session.lastDeferredAt, scheduled);
    expect(session.cadenceMinutes, 90);
    expect(schedule!.startMinutes, 540);
    expect(schedule.endMinutes, 1020);
    expect(schedule.cadenceMinutes, 90);
  });
}

Future<RecessSession> _completedSession(
  RecessDatabase database, {
  required DateTime scheduledAt,
  required DateTime startedAt,
  required DateTime completedAt,
}) async {
  final session = await database.createSession(
    scheduledAt: scheduledAt,
    createdAt: scheduledAt.subtract(const Duration(hours: 1)),
  );
  await database.startSession(session.id, startedAt, 'shoulder-rolls');
  return database.completeSession(session.id, completedAt);
}

Future<int> _sessionCount(RecessDatabase database) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS total FROM recess_sessions')
      .getSingle();
  return row.read<int>('total');
}
