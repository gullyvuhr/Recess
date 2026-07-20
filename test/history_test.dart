import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/history.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/core/providers.dart';
import 'package:recess/src/exercises/exercise.dart';
import 'package:recess/src/exercises/exercise_repository.dart';

void main() {
  group('HistoryPeriod', () {
    final now = DateTime(2026, 7, 20, 14);

    test('current period is the most recent seven local days', () {
      final period = HistoryPeriod.current(now);

      expect(period.start, DateTime(2026, 7, 14));
      expect(period.endInclusive, DateTime(2026, 7, 20));
      expect(period.endExclusive, DateTime(2026, 7, 21));
    });

    test('moves backward and forward without entering the future', () {
      final current = HistoryPeriod.current(now);
      final previous = current.previous();

      expect(previous.start, DateTime(2026, 7, 7));
      expect(previous.canMoveNext(now), isTrue);
      expect(previous.next(now), current);
      expect(current.canMoveNext(now), isFalse);
      expect(current.next(now), current);
    });

    test('controller loads current period and navigates', () {
      final controller = HistoryPeriodController(now);

      expect(controller.state, HistoryPeriod.current(now));
      controller.previous();
      expect(controller.state.start, DateTime(2026, 7, 7));
      controller.next();
      expect(controller.state, HistoryPeriod.current(now));
      controller.next();
      expect(controller.state, HistoryPeriod.current(now));
    });
  });

  group('HistoryService', () {
    late RecessDatabase database;
    late HistoryService service;

    setUp(() {
      database = RecessDatabase(NativeDatabase.memory());
      service = HistoryService(
        database: database,
        exercises: const _StaticCatalog(),
      );
    });

    tearDown(() => database.close());

    test('returns an empty current period', () async {
      final data = await service.load(
        HistoryPeriod.current(DateTime(2026, 7, 20)),
      );

      expect(data.isEmpty, isTrue);
      expect(data.summary.completed, 0);
      expect(data.summary.averageDuration, isNull);
      expect(data.summary.averageResponseDelay, isNull);
    });

    test('groups local days and calculates weekly aggregates', () async {
      await _complete(
        database,
        scheduled: DateTime(2026, 7, 18, 9),
        started: DateTime(2026, 7, 18, 9, 5),
        completed: DateTime(2026, 7, 18, 9, 15),
      );
      await _complete(
        database,
        scheduled: DateTime(2026, 7, 19, 10),
        started: DateTime(2026, 7, 19, 10, 15),
        completed: DateTime(2026, 7, 19, 10, 35),
      );
      final rain = await database.createSession(
        scheduledAt: DateTime(2026, 7, 19, 14),
        createdAt: DateTime(2026, 7, 19, 13),
      );
      await database.deferSession(
        rain.id,
        RecessDeferralType.fiveMinutes,
        DateTime(2026, 7, 19, 14, 5),
        DateTime(2026, 7, 19, 14, 1),
      );
      await database.rainCheckSession(rain.id, DateTime(2026, 7, 19, 14, 2));

      final data = await service.load(
        HistoryPeriod.current(DateTime(2026, 7, 20)),
      );

      expect(data.days.map((day) => day.date), [
        DateTime(2026, 7, 19),
        DateTime(2026, 7, 18),
      ]);
      expect(data.days.first.sessions, hasLength(2));
      expect(data.days.first.completed, 1);
      expect(data.days.first.deferred, 1);
      expect(data.days.first.rainChecked, 1);
      expect(data.summary.completed, 2);
      expect(data.summary.deferred, 1);
      expect(data.summary.rainChecked, 1);
      expect(data.summary.averageDuration, const Duration(minutes: 15));
      expect(data.summary.averageResponseDelay, const Duration(minutes: 10));
      expect(
        data.days.last.sessions.single.exerciseName,
        'Shoulder Rolls',
      );
    });

    test('refreshes provider after session completion', () async {
      final session = await database.createSession(
        scheduledAt: DateTime(2026, 7, 20, 9),
        createdAt: DateTime(2026, 7, 20, 8),
      );
      await database.startSession(
        session.id,
        DateTime(2026, 7, 20, 9, 5),
        'shoulder-rolls',
      );
      final notifications = _FakeNotifications();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          notificationServiceProvider.overrideWithValue(notifications),
          exerciseCatalogProvider.overrideWithValue(const _StaticCatalog()),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(notifications.close);
      final period = HistoryPeriod.current(DateTime(2026, 7, 20));
      final subscription = container.listen(
        historyProvider(period),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      expect(
        (await container.read(historyProvider(period).future))
            .summary
            .completed,
        0,
      );
      await container.read(recessActionsProvider).complete(session.id);
      expect(
        (await container.read(historyProvider(period).future))
            .summary
            .completed,
        1,
      );
    });
  });
}

Future<void> _complete(
  RecessDatabase database, {
  required DateTime scheduled,
  required DateTime started,
  required DateTime completed,
}) async {
  final session = await database.createSession(
    scheduledAt: scheduled,
    createdAt: scheduled.subtract(const Duration(hours: 1)),
  );
  await database.startSession(session.id, started, 'shoulder-rolls');
  await database.completeSession(session.id, completed);
}

class _StaticCatalog implements ExerciseCatalog {
  const _StaticCatalog();

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
      ];
}

class _FakeNotifications implements BellNotifications {
  final _opened = StreamController<String>.broadcast();

  Future<void> close() => _opened.close();

  @override
  Stream<String> get openedPayloads => _opened.stream;
  @override
  Future<void> cancelCadenceBell({Set<int> retaining = const {}}) async {}
  @override
  Future<List<PendingCadenceBell>> pendingCadenceBells() async => const [];
  @override
  Future<void> cancelDeferredBell() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> ringBells(int sessionId, {required bool deferred}) async => true;
  @override
  Future<bool> scheduleCadenceBell(int sessionId, DateTime scheduledAt) async =>
      true;
  @override
  Future<bool> scheduleDeferredBell(
    int sessionId,
    DateTime scheduledAt,
  ) async =>
      true;
  @override
  String? takeInitialPayload() => null;
}
