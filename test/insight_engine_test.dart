import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/cadence_schedule.dart';
import 'package:recess/src/core/insights.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/exercises/exercise.dart';

void main() {
  const engine = InsightEngine();
  final now = DateTime(2026, 7, 20, 12);

  test('no facts returns empty metrics without dividing by zero', () {
    final summary = engine.summarize(
      sessions: const [],
      exercises: _exercises,
      now: now,
    );

    expect(summary.today.completed, 0);
    expect(summary.today.deferred, 0);
    expect(summary.today.missed, isNull);
    expect(summary.today.completedMovementDuration, Duration.zero);
    expect(summary.sevenDays.scheduled, 0);
    expect(summary.sevenDays.completed, 0);
    expect(summary.sevenDays.completionRate, isNull);
    expect(summary.sevenDays.averageResponseTime, isNull);
    expect(summary.sevenDays.averageCompletedDuration, isNull);
    expect(summary.observations, isEmpty);
  });

  test('one day of partial facts derives only supported metrics', () {
    final sessions = [
      _session(
        1,
        DateTime(2026, 7, 20, 9),
        status: RecessSessionStatus.completed,
        startedAt: DateTime(2026, 7, 20, 9, 5),
        completedAt: DateTime(2026, 7, 20, 9, 15),
        exerciseId: 'move',
      ),
      _session(
        2,
        DateTime(2026, 7, 20, 14),
        status: RecessSessionStatus.rainChecked,
        deferralCount: 1,
        lastDeferredAt: DateTime(2026, 7, 20, 14, 2),
      ),
      _session(
        3,
        DateTime(2026, 7, 20, 16),
        status: RecessSessionStatus.completed,
        startedAt: DateTime(2026, 7, 20, 16, 5),
        completedAt: DateTime(2026, 7, 20, 16, 25),
        exerciseId: 'breathe',
      ),
    ];

    final summary = engine.summarize(
      sessions: sessions,
      exercises: _exercises,
      now: now,
    );

    expect(summary.today.completed, 2);
    expect(summary.today.deferred, 1);
    expect(summary.today.missed, isNull);
    expect(
      summary.today.completedMovementDuration,
      const Duration(minutes: 10),
    );
    expect(summary.sevenDays.scheduled, 3);
    expect(summary.sevenDays.completed, 2);
    expect(summary.sevenDays.completionRate, closeTo(2 / 3, 0.000001));
    expect(summary.sevenDays.averageResponseTime, const Duration(minutes: 5));
    expect(
      summary.sevenDays.averageCompletedDuration,
      const Duration(minutes: 15),
    );
    expect(summary.observations, isEmpty);
  });

  test('starts before a scheduled Bell do not create negative response time',
      () {
    final summary = engine.summarize(
      sessions: [
        _session(
          1,
          DateTime(2026, 7, 20, 13),
          status: RecessSessionStatus.completed,
          startedAt: DateTime(2026, 7, 20, 12, 40),
          completedAt: DateTime(2026, 7, 20, 12, 45),
        ),
      ],
      exercises: _exercises,
      now: now,
    );

    expect(summary.sevenDays.averageResponseTime, isNull);
  });

  test('seven complete days produce stable rolling aggregate metrics', () {
    final sessions = [
      for (var day = 14; day <= 20; day++)
        _session(
          day,
          DateTime(2026, 7, day, 10),
          status: RecessSessionStatus.completed,
          startedAt: DateTime(2026, 7, day, 10, 4),
          completedAt: DateTime(2026, 7, day, 10, 12),
          exerciseId: 'move',
        ),
    ];

    final summary = engine.summarize(
      sessions: sessions,
      exercises: _exercises,
      now: now,
    );

    expect(summary.sevenDays.scheduled, 7);
    expect(summary.sevenDays.completed, 7);
    expect(summary.sevenDays.completionRate, 1);
    expect(summary.sevenDays.averageResponseTime, const Duration(minutes: 4));
    expect(
      summary.sevenDays.averageCompletedDuration,
      const Duration(minutes: 8),
    );
    expect(summary.observations, isEmpty);
  });

  test(
      'weekly completion uses all active schedule occurrences and excludes manual sessions',
      () {
    final expected = scheduledBellTimesInRange(
      schedule: const WorkSchedule(
        startMinutes: 9 * 60,
        endMinutes: 12 * 60,
        cadenceMinutes: 60,
      ),
      preferences: const RecessPreferences(),
      start: DateTime(2026, 7, 20),
      end: DateTime(2026, 7, 27),
    );
    final sessions = [
      _session(
        1,
        DateTime(2026, 7, 20, 10),
        status: RecessSessionStatus.completed,
        startedAt: DateTime(2026, 7, 20, 10, 2),
        completedAt: DateTime(2026, 7, 20, 10, 7),
      ),
      _session(
        2,
        DateTime(2026, 7, 20, 11),
        status: RecessSessionStatus.rainChecked,
      ),
      _session(
        3,
        DateTime(2026, 7, 21, 10),
        status: RecessSessionStatus.completed,
        startedAt: DateTime(2026, 7, 21, 10, 1),
        completedAt: DateTime(2026, 7, 21, 10, 6),
      ),
      _session(
        4,
        DateTime(2026, 7, 22, 10),
        status: RecessSessionStatus.completed,
        startedAt: DateTime(2026, 7, 22, 10, 1),
        completedAt: DateTime(2026, 7, 22, 10, 6),
      ),
      _session(
        5,
        DateTime(2026, 7, 22, 10, 30),
        status: RecessSessionStatus.completed,
        startedAt: DateTime(2026, 7, 22, 10, 30),
        completedAt: DateTime(2026, 7, 22, 10, 35),
      ),
    ];

    final summary = engine.summarize(
      sessions: sessions,
      exercises: _exercises,
      expectedWeeklyOccurrences: expected,
      now: DateTime(2026, 7, 22, 12),
    );

    expect(expected, hasLength(14));
    expect(
      summary.observations
          .singleWhere(
            (value) => value.type == InsightObservationType.weeklyCompletion,
          )
          .description,
      'You completed 3 of 14 scheduled Recesses this week.',
    );
  });

  test('weekly completion excludes schedule times disabled by Quiet Hours', () {
    final expected = scheduledBellTimesInRange(
      schedule: const WorkSchedule(
        startMinutes: 9 * 60,
        endMinutes: 13 * 60,
        cadenceMinutes: 60,
      ),
      preferences: const RecessPreferences(
        quietHoursEnabled: true,
        quietHoursStartMinutes: 11 * 60,
        quietHoursEndMinutes: 12 * 60,
      ),
      start: DateTime(2026, 7, 20),
      end: DateTime(2026, 7, 27),
    );

    final summary = engine.summarize(
      sessions: const [],
      exercises: _exercises,
      expectedWeeklyOccurrences: expected,
      now: DateTime(2026, 7, 22, 12),
    );

    expect(expected, hasLength(14));
    expect(
      summary.observations
          .singleWhere(
            (value) => value.type == InsightObservationType.weeklyCompletion,
          )
          .description,
      'You completed 0 of 14 scheduled Recesses this week.',
    );
  });

  test('mixed completed and deferred facts do not invent missed sessions', () {
    final sessions = [
      _session(
        1,
        DateTime(2026, 7, 20, 9),
        status: RecessSessionStatus.completed,
        startedAt: DateTime(2026, 7, 20, 9, 3),
        completedAt: DateTime(2026, 7, 20, 9, 8),
      ),
      _session(
        2,
        DateTime(2026, 7, 20, 11),
        status: RecessSessionStatus.rainChecked,
        deferralCount: 2,
        lastDeferredAt: DateTime(2026, 7, 20, 11, 20),
      ),
      _session(
        3,
        DateTime(2026, 7, 20, 15),
        status: RecessSessionStatus.scheduled,
      ),
    ];

    final summary = engine.summarize(
      sessions: sessions,
      exercises: _exercises,
      now: now,
    );

    expect(summary.today.completed, 1);
    expect(summary.today.deferred, 1);
    expect(summary.today.missed, isNull);
    expect(summary.sevenDays.scheduled, 3);
    expect(summary.sevenDays.completionRate, closeTo(1 / 3, 0.000001));
  });

  test('insufficient samples suppress all observations', () {
    final sessions = [
      for (var hour = 9; hour < 12; hour++)
        _session(
          hour,
          DateTime(2026, 7, 20, hour),
          status: RecessSessionStatus.completed,
          startedAt: DateTime(2026, 7, 20, hour, 5),
          completedAt: DateTime(2026, 7, 20, hour, 10),
        ),
    ];

    final summary = engine.summarize(
      sessions: sessions,
      exercises: _exercises,
      now: now,
    );

    expect(summary.observations, isEmpty);
  });

  test('ranks observations by strength and returns only three', () {
    final current = <RecessSession>[
      for (var day = 17; day <= 20; day++)
        _session(
          day,
          DateTime(2026, 7, day, 9),
          status: RecessSessionStatus.completed,
          startedAt: DateTime(2026, 7, day, 9, 2),
          completedAt: DateTime(2026, 7, day, 9, 8),
        ),
      for (var day = 17; day <= 20; day++)
        _session(
          100 + day,
          DateTime(2026, 7, day, 15),
          status: RecessSessionStatus.rainChecked,
          deferralCount: 1,
          lastDeferredAt: DateTime(2026, 7, day, 15, 1),
        ),
    ];
    final previous = [
      for (var day = 10; day <= 12; day++)
        _session(
          200 + day,
          DateTime(2026, 7, day, 9),
          status: RecessSessionStatus.completed,
          startedAt: DateTime(2026, 7, day, 9, 10),
          completedAt: DateTime(2026, 7, day, 9, 16),
        ),
    ];

    final summary = engine.summarize(
      sessions: [...current, ...previous],
      exercises: _exercises,
      now: now,
    );

    expect(summary.observations, hasLength(3));
    expect(
      summary.observations.map((value) => value.type),
      [
        InsightObservationType.morningCompletion,
        InsightObservationType.responseTimeImproving,
        InsightObservationType.lateDeferrals,
      ],
    );
  });

  test('identical facts always produce identical output', () {
    final sessions = [
      for (var day = 17; day <= 20; day++)
        _session(
          day,
          DateTime(2026, 7, day, 15),
          status: RecessSessionStatus.rainChecked,
          deferralCount: 1,
          lastDeferredAt: DateTime(2026, 7, day, 15, 5),
        ),
    ];

    final first = engine.summarize(
      sessions: sessions,
      exercises: _exercises,
      now: now,
    );
    final second = engine.summarize(
      sessions: sessions,
      exercises: _exercises,
      now: now,
    );

    expect(second.today.completed, first.today.completed);
    expect(second.sevenDays.completionRate, first.sevenDays.completionRate);
    expect(second.observations, first.observations);
  });

  test('uses local calendar boundaries for today and seven days', () {
    final sessions = [
      _session(
        1,
        DateTime(2026, 7, 20),
        status: RecessSessionStatus.completed,
        startedAt: DateTime(2026, 7, 20, 0, 1),
        completedAt: DateTime(2026, 7, 20, 0, 6),
      ),
      _session(
        2,
        DateTime(2026, 7, 19, 23, 59),
        status: RecessSessionStatus.completed,
        startedAt: DateTime(2026, 7, 20, 0, 2),
        completedAt: DateTime(2026, 7, 20, 0, 7),
      ),
      _session(
        3,
        DateTime(2026, 7, 21),
        status: RecessSessionStatus.completed,
        startedAt: DateTime(2026, 7, 21, 0, 1),
        completedAt: DateTime(2026, 7, 21, 0, 6),
      ),
    ];

    final summary = engine.summarize(
      sessions: sessions,
      exercises: _exercises,
      now: DateTime(2026, 7, 20, 23, 30),
    );

    expect(summary.today.completed, 1);
    expect(summary.sevenDays.scheduled, 2);
  });
}

RecessSession _session(
  int id,
  DateTime scheduledAt, {
  required RecessSessionStatus status,
  DateTime? startedAt,
  DateTime? completedAt,
  int deferralCount = 0,
  DateTime? lastDeferredAt,
  String? exerciseId,
}) =>
    RecessSession(
      id: id,
      originalScheduledAt: scheduledAt,
      scheduledAt: scheduledAt,
      status: status,
      createdAt: scheduledAt.subtract(const Duration(minutes: 5)),
      deferralCount: deferralCount,
      cadenceMinutes: 60,
      startedAt: startedAt,
      completedAt: completedAt,
      lastDeferredAt: lastDeferredAt,
      exerciseId: exerciseId,
    );

const _exercises = [
  Exercise(
    id: 'move',
    title: 'Move',
    instruction: 'Move.',
    durationMinutes: 5,
    category: ExerciseCategory.movement,
    availableIndoors: true,
    availableOutdoors: true,
  ),
  Exercise(
    id: 'breathe',
    title: 'Breathe',
    instruction: 'Breathe.',
    durationMinutes: 5,
    category: ExerciseCategory.breathing,
    availableIndoors: true,
    availableOutdoors: true,
  ),
];
