import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/database.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/notifications.dart';
import 'package:recess/src/core/session_service.dart';

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
    await expectLater(service.start(scheduled.id), throwsStateError);
    expect(await _sessionCount(database), 1);
  });

  test('Give me a minute defers the same session for 5 minutes', () async {
    final scheduled = await _session(database, now);

    final deferred = await service.defer(
      scheduled.id,
      RecessDeferralType.fiveMinutes,
    );

    expect(deferred.id, scheduled.id);
    expect(deferred.status, RecessSessionStatus.deferred);
    expect(deferred.deferralType, RecessDeferralType.fiveMinutes);
    expect(deferred.scheduledAt, now.add(const Duration(minutes: 5)));
    expect(notifications.deferred.single.sessionId, scheduled.id);
    expect(notifications.deferred.single.scheduledAt, deferred.scheduledAt);
  });

  test('After this defers the same session for 15 minutes', () async {
    final scheduled = await _session(database, now);

    final deferred = await service.defer(
      scheduled.id,
      RecessDeferralType.afterThis,
    );

    expect(deferred.id, scheduled.id);
    expect(deferred.status, RecessSessionStatus.deferred);
    expect(deferred.deferralType, RecessDeferralType.afterThis);
    expect(deferred.scheduledAt, now.add(const Duration(minutes: 15)));
    expect(notifications.deferred.single.scheduledAt, deferred.scheduledAt);
  });

  test('Rain check is persisted and resumes normal Bell cadence', () async {
    final scheduled = await _session(database, now);

    final rainChecked = await service.rainCheck(scheduled.id);

    expect(rainChecked.id, scheduled.id);
    expect(rainChecked.status, RecessSessionStatus.rainChecked);
    expect(rainChecked.startedAt, isNull);
    expect(rainChecked.completedAt, isNull);
    expect(notifications.cadence.single.scheduledAt, DateTime(2026, 7, 19, 13));
    final progress = await database.todayProgress(now: now);
    expect(progress.started, 0);
    expect(progress.completed, 0);
    expect(progress.rainChecks, 1);
  });

  test('completion closes the active session lifecycle', () async {
    final scheduled = await _session(database, now);
    final active = await service.start(scheduled.id);
    now = now.add(const Duration(minutes: 20));

    final completed = await service.complete(active.id);

    expect(completed.id, scheduled.id);
    expect(completed.status, RecessSessionStatus.completed);
    expect(completed.startedAt, DateTime(2026, 7, 19, 10));
    expect(completed.completedAt, now);
    expect(notifications.cadence.single.scheduledAt, DateTime(2026, 7, 19, 13));
  });

  test("today's progress is derived from persisted session timestamps",
      () async {
    final first = await _session(database, DateTime(2026, 7, 19, 9));
    await database.startSession(first.id, DateTime(2026, 7, 19, 9, 5));
    await database.completeSession(first.id, DateTime(2026, 7, 19, 9, 25));

    final rain = await _session(database, DateTime(2026, 7, 19, 12));
    await database.rainCheckSession(rain.id);

    final yesterday = await _session(database, DateTime(2026, 7, 18, 12));
    await database.startSession(yesterday.id, DateTime(2026, 7, 18, 12));
    await database.completeSession(yesterday.id, DateTime(2026, 7, 18, 12, 10));

    final active = await _session(database, DateTime(2026, 7, 19, 11));
    await database.startSession(active.id, DateTime(2026, 7, 19, 11, 5));

    final progress = await database.todayProgress(now: now);

    expect(progress.started, 2);
    expect(progress.completed, 1);
    expect(progress.rainChecks, 1);
  });

  test('a returned deferred Bell cannot be deferred again', () async {
    final scheduled = await _session(database, now);
    final deferred = await service.defer(
      scheduled.id,
      RecessDeferralType.fiveMinutes,
    );

    final opened = await service.openBell('bell:deferred:${deferred.id}');

    expect(opened, isNotNull);
    expect(opened!.canDefer, isFalse);
    await expectLater(
      service.defer(deferred.id, RecessDeferralType.afterThis),
      throwsStateError,
    );
    expect(notifications.deferred, hasLength(1));
  });

  test('restore and repeated notification taps reuse one session', () async {
    await service.restore();
    final original = await database.openSession();

    await service.restore();
    final firstOpen = await service.openBell('bell:${original!.id}');
    final secondOpen = await service.openBell('bell:${original.id}');
    final active = await service.start(original.id);
    final reopenedActive = await service.openBell('bell:${original.id}');

    expect(firstOpen?.id, original.id);
    expect(secondOpen?.id, original.id);
    expect(active.status, RecessSessionStatus.active);
    expect(reopenedActive, isNull);
    expect(await _sessionCount(database), 1);
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
    now = DateTime(2026, 3, 8, 14);

    await service.restore();

    final scheduled = await database.openSession();
    expect(scheduled!.scheduledAt, DateTime(2026, 3, 9, 13));
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
}

class FakeNotifications implements BellNotifications {
  final cadence = <ScheduledCall>[];
  final deferred = <ScheduledCall>[];
  final opened = StreamController<String>.broadcast();
  var deferredCancellationCount = 0;

  @override
  Stream<String> get openedPayloads => opened.stream;

  @override
  Future<void> cancelDeferredBell() async {
    deferredCancellationCount++;
  }

  @override
  Future<void> ringBells(int sessionId, {required bool deferred}) async {}

  @override
  Future<void> scheduleCadenceBell(
    int sessionId,
    DateTime scheduledAt,
  ) async {
    cadence.add(ScheduledCall(sessionId, scheduledAt));
  }

  @override
  Future<void> scheduleDeferredBell(
    int sessionId,
    DateTime scheduledAt,
  ) async {
    deferred.add(ScheduledCall(sessionId, scheduledAt));
  }

  @override
  String? takeInitialPayload() => null;
}
