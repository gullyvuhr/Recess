import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/database.dart';
import 'package:recess/src/core/history.dart';
import 'package:recess/src/core/insights.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/notifications.dart';
import 'package:recess/src/core/session_service.dart';
import 'package:recess/src/exercises/exercise.dart';
import 'package:recess/src/exercises/exercise_repository.dart';
import 'package:recess/src/exercises/exercise_service.dart';

void main() {
  late RecessDatabase database;
  late _Notifications notifications;
  late DateTime now;
  late RecessSessionService sessions;
  late InsightService insights;
  late HistoryService history;

  setUp(() async {
    database = RecessDatabase(NativeDatabase.memory());
    notifications = _Notifications();
    now = DateTime(2026, 7, 20, 10, 30);
    sessions = RecessSessionService(
      database: database,
      notifications: notifications,
      exercises: const ExerciseService(catalog: _Catalog()),
      clock: () => now,
    );
    insights = InsightService(database: database, exercises: const _Catalog());
    history = HistoryService(database: database, exercises: const _Catalog());
    await database.saveSchedule(
      const WorkSchedule(
        startMinutes: 9 * 60,
        endMinutes: 17 * 60,
        cadenceMinutes: 60,
        workDays: {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        },
      ),
    );
  });

  tearDown(() async {
    await notifications.close();
    await database.close();
  });

  test(
    'Dashboard manual start without a scheduled row is origin-safe',
    () async {
      final before = await insights.load(now);

      final manual = await sessions.startNow();
      now = now.add(const Duration(minutes: 5));
      await sessions.complete(manual.id);

      final after = await insights.load(now);
      final historyData = await history.load(HistoryPeriod.current(now));
      expect(manual.origin, RecessSessionOrigin.manual);
      expect(after.today.completed, before.today.completed + 1);
      expect(_scheduledCompletions(after), _scheduledCompletions(before));
      expect(historyData.summary.completed, 1);
      expect(await database.completedSessions(), hasLength(1));
    },
  );

  test(
    'Dashboard manual start preserves a future scheduled occurrence',
    () async {
      final scheduled = (await sessions.restore()).value!;
      final pendingBefore = notifications.pendingFor(scheduled.id);

      final manual = await sessions.startNow();
      final resumedManual = await sessions.startNow();

      expect(manual.origin, RecessSessionOrigin.manual);
      expect(resumedManual.id, manual.id);
      expect(manual.id, isNot(scheduled.id));
      expect(
        (await database.session(scheduled.id))!.status,
        RecessSessionStatus.scheduled,
      );
      expect(
        (await database.session(scheduled.id))!.scheduledAt,
        scheduled.scheduledAt,
      );
      expect(notifications.pendingFor(scheduled.id), pendingBefore);
    },
  );

  test(
    'manual completion then scheduled Bell produces two completions',
    () async {
      final scheduled = (await sessions.restore()).value!;
      final adherenceBefore = _scheduledCompletions(await insights.load(now));
      final manual = await sessions.startNow();
      now = DateTime(2026, 7, 20, 10, 55);
      await sessions.complete(manual.id);

      expect(
        notifications.pendingFor(scheduled.id),
        contains(DateTime(2026, 7, 20, 11)),
      );
      now = DateTime(2026, 7, 20, 11);
      notifications.deliver(now);
      final opened = await sessions.openBell('bell:${scheduled.id}');
      final activeScheduled = await sessions.startScheduled(opened!.id);
      now = now.add(const Duration(minutes: 5));
      await sessions.complete(activeScheduled.id);

      final completed = await database.completedSessions();
      final after = await insights.load(now);
      final historyData = await history.load(HistoryPeriod.current(now));
      expect(completed.map((session) => session.id).toSet(), {
        manual.id,
        scheduled.id,
      });
      expect(historyData.summary.completed, 2);
      expect(after.today.completed, 2);
      expect(_scheduledCompletions(after), adherenceBefore + 1);
    },
  );

  test(
    'scheduled Bell starts its persisted row without a manual extra',
    () async {
      final scheduled = (await sessions.restore()).value!;
      now = scheduled.scheduledAt;
      notifications.deliver(now);

      final opened = await sessions.openBell('bell:${scheduled.id}');
      final active = await sessions.startScheduled(opened!.id);
      now = now.add(const Duration(minutes: 5));
      await sessions.complete(active.id);

      final all = await database.sessionsInRange(
        DateTime(2026, 7, 20),
        DateTime(2026, 7, 21),
      );
      expect(active.id, scheduled.id);
      expect(active.origin, RecessSessionOrigin.scheduled);
      expect(all.where((session) => session.isManual), isEmpty);
      expect(await database.completedSessions(), hasLength(1));
    },
  );

  test(
    'abandoned manual is not counted and preserves future schedule',
    () async {
      final scheduled = (await sessions.restore()).value!;
      final adherenceBefore = _scheduledCompletions(await insights.load(now));
      final manual = await sessions.startNow();

      final summary = await insights.load(now);
      final historyData = await history.load(HistoryPeriod.current(now));
      expect(
        (await database.session(manual.id))!.status,
        RecessSessionStatus.active,
      );
      expect(summary.today.completed, 0);
      expect(_scheduledCompletions(summary), adherenceBefore);
      expect(historyData.summary.completed, 0);
      expect(
        (await database.session(scheduled.id))!.status,
        RecessSessionStatus.scheduled,
      );
      expect(notifications.pendingFor(scheduled.id), isNotEmpty);
    },
  );

  test(
    'repeated manual completion is rejected without double counting',
    () async {
      final manual = await sessions.startNow();
      now = now.add(const Duration(minutes: 5));
      await sessions.complete(manual.id);

      await expectLater(sessions.complete(manual.id), throwsStateError);

      expect(await database.completedSessions(), hasLength(1));
      expect(
        (await history.load(HistoryPeriod.current(now))).summary.completed,
        1,
      );
    },
  );

  test(
    'restart reconciliation retains future Bell after manual completion',
    () async {
      final scheduled = (await sessions.restore()).value!;
      final manual = await sessions.startNow();
      now = DateTime(2026, 7, 20, 10, 55);
      await sessions.complete(manual.id);
      notifications.clearPending();

      final restarted = RecessSessionService(
        database: database,
        notifications: notifications,
        exercises: const ExerciseService(catalog: _Catalog()),
        clock: () => now,
      );
      final restored = await restarted.restore();

      expect(restored.value!.id, scheduled.id);
      expect(restored.value!.origin, RecessSessionOrigin.scheduled);
      expect(restored.value!.scheduledAt, DateTime(2026, 7, 20, 11));
      expect(
        notifications.pendingFor(scheduled.id),
        contains(DateTime(2026, 7, 20, 11)),
      );
      expect(
        (await database.session(manual.id))!.status,
        RecessSessionStatus.completed,
      );
    },
  );
}

int _scheduledCompletions(InsightSummary summary) {
  final observation = summary.observations.singleWhere(
    (item) => item.type == InsightObservationType.weeklyCompletion,
  );
  return int.parse(observation.description.split(' ')[2]);
}

class _Notifications implements BellNotifications {
  final _opened = StreamController<String>.broadcast();
  final _pending = <int, List<DateTime>>{};

  List<DateTime> pendingFor(int sessionId) =>
      List.unmodifiable(_pending[sessionId] ?? const []);

  void deliver(DateTime scheduledAt) {
    for (final times in _pending.values) {
      times.remove(scheduledAt);
    }
  }

  void clearPending() => _pending.clear();

  Future<void> close() => _opened.close();

  @override
  Stream<String> get openedPayloads => _opened.stream;

  @override
  Future<void> cancelCadenceBell({Set<int> retaining = const {}}) async {
    for (final times in _pending.values) {
      times.removeWhere(
        (time) => !retaining.contains(
          NotificationService.cadenceNotificationId(time),
        ),
      );
    }
  }

  @override
  Future<void> cancelDeferredBell() async {}

  @override
  Future<List<PendingCadenceBell>> pendingCadenceBells() async =>
      _pending.values
          .expand((times) => times)
          .map(
            (time) => PendingCadenceBell(
              id: NotificationService.cadenceNotificationId(time),
              scheduledAt: time,
            ),
          )
          .toList(growable: false);

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> ringBells(
    int sessionId, {
    required bool deferred,
    BellSound sound = BellSound.schoolBell,
  }) async =>
      true;

  @override
  Future<bool> scheduleCadenceBell(
    int sessionId,
    DateTime scheduledAt, {
    BellSound sound = BellSound.schoolBell,
  }) async {
    final times = _pending.putIfAbsent(sessionId, () => []);
    times.remove(scheduledAt);
    times.add(scheduledAt);
    return true;
  }

  @override
  Future<bool> scheduleDeferredBell(
    int sessionId,
    DateTime scheduledAt, {
    BellSound sound = BellSound.schoolBell,
  }) async =>
      true;

  @override
  String? takeInitialPayload() => null;
}

class _Catalog implements ExerciseCatalog {
  const _Catalog();

  @override
  Future<List<Exercise>> load() async => const [
        Exercise(
          id: 'shoulder-rolls',
          title: 'Shoulder Rolls',
          instruction: 'Roll your shoulders.',
          durationMinutes: 2,
          category: ExerciseCategory.movement,
          availableIndoors: true,
          availableOutdoors: true,
        ),
        Exercise(
          id: 'long-exhale',
          title: 'Long Exhale',
          instruction: 'Breathe out slowly.',
          durationMinutes: 2,
          category: ExerciseCategory.breathing,
          availableIndoors: true,
          availableOutdoors: true,
        ),
      ];
}
