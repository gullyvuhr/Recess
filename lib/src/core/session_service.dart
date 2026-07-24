import 'cadence_schedule.dart';
import 'database.dart';
import 'models.dart';
import 'notifications.dart';
import '../exercises/exercise.dart';
import '../exercises/exercise_service.dart';

typedef Clock = DateTime Function();

class SessionActionResult<T> {
  const SessionActionResult({
    required this.value,
    required this.notificationSucceeded,
  });

  final T value;
  final bool notificationSucceeded;
}

class RecessSessionService {
  RecessSessionService({
    required RecessDatabase database,
    required BellNotifications notifications,
    required ExerciseService exercises,
    Clock? clock,
  })  : _database = database,
        _notifications = notifications,
        _exercises = exercises,
        _clock = clock ?? DateTime.now;

  final RecessDatabase _database;
  final BellNotifications _notifications;
  final ExerciseService _exercises;
  final Clock _clock;
  Future<void> _cadenceOperation = Future.value();

  Future<SessionActionResult<RecessSession?>> saveSchedule(
    WorkSchedule schedule,
  ) async {
    await _database.saveSchedule(schedule);
    return restore();
  }

  Future<SessionActionResult<RecessSession?>> restore() async {
    final open = await _database.openSession();
    if (open == null) {
      return _scheduleNextCadence(cancelObsolete: true);
    }
    if (open.status == RecessSessionStatus.scheduled) {
      final times = await _cadenceTimes(
        _clock(),
        await _database.schedule(),
      );
      if (times.isNotEmpty) {
        final rescheduled = await _database.rescheduleCadenceSession(
          open.id,
          times.first,
        );
        final scheduled = await _rebuildCadence(
          rescheduled.id,
          times,
          cancelObsolete: true,
        );
        return SessionActionResult(
          value: rescheduled,
          notificationSucceeded: scheduled,
        );
      }
      final scheduled = await _rebuildCadence(
        open.id,
        times,
        cancelObsolete: true,
      );
      return SessionActionResult(
        value: open,
        notificationSucceeded: scheduled,
      );
    } else if (open.status == RecessSessionStatus.deferred) {
      final reminderScheduled = await _scheduleDeferredBell(
        open.id,
        open.scheduledAt,
      );
      final cadenceScheduled = await _rebuildCadence(
        open.id,
        await _cadenceTimes(_clock(), await _database.schedule()),
        cancelObsolete: true,
      );
      return SessionActionResult(
        value: open,
        notificationSucceeded: reminderScheduled && cadenceScheduled,
      );
    } else if (open.status == RecessSessionStatus.active) {
      return SessionActionResult(
        value: await _ensureExerciseAssigned(open),
        notificationSucceeded: true,
      );
    }
    return SessionActionResult(value: open, notificationSucceeded: false);
  }

  Future<RecessSession?> openBell(String payload) async {
    final parts = payload.split(':');
    if (parts.length == 2 && parts.first == 'bell') {
      return _openResponseSession(int.tryParse(parts[1]));
    }
    if (parts.length == 3 && parts[0] == 'bell' && parts[1] == 'deferred') {
      return _openResponseSession(int.tryParse(parts[2]));
    }
    if (parts.length == 3 && parts[0] == 'bell' && parts[1] == 'immediate') {
      return _openResponseSession(int.tryParse(parts[2]));
    }
    return null;
  }

  Future<bool> refreshBellSound() async {
    final open = await _database.openSession();
    if (open == null) return true;
    final sound = await _bellSound();
    final cadenceScheduled = await _rebuildCadence(
      open.id,
      await _cadenceTimes(_clock(), await _database.schedule()),
      cancelObsolete: true,
    );
    if (open.status != RecessSessionStatus.deferred) {
      return cadenceScheduled;
    }
    final deferredScheduled = await _scheduleDeferredBell(
      open.id,
      open.scheduledAt,
      sound: sound,
    );
    return cadenceScheduled && deferredScheduled;
  }

  Future<SessionActionResult<RecessSession>> ringBellNow() async {
    final open = await _database.openSession();
    final cadence = open == null ? await _scheduleNextCadence() : null;
    final session = open ?? cadence?.value;
    if (session == null) {
      throw StateError('A work schedule is required before ringing Bells.');
    }
    final delivered = await _notifications.ringBells(
      session.id,
      deferred: session.status == RecessSessionStatus.deferred,
      sound: await _bellSound(),
    );
    return SessionActionResult(
      value: session,
      notificationSucceeded: delivered,
    );
  }

  Future<RecessSession?> _openResponseSession(int? id) async {
    if (id == null) return null;
    final session = await _database.session(id);
    if (session == null ||
        (session.status != RecessSessionStatus.scheduled &&
            session.status != RecessSessionStatus.deferred)) {
      return null;
    }
    return _database.markBellOpened(id, _clock());
  }

  Future<RecessSession> start(int sessionId) async {
    await _notifications.cancelDeferredBell();
    final exercise = await _selectExercise();
    return _database.startSession(sessionId, _clock(), exercise.id);
  }

  Future<RecessSession> startNow() async {
    final open = await _database.openSession();
    if (open?.status == RecessSessionStatus.active) {
      return _ensureExerciseAssigned(open!);
    }
    if (open != null) return start(open.id);
    final now = _clock();
    final session = await _database.openOrCreateScheduledSession(
      scheduledAt: now,
      createdAt: now,
      cadenceMinutes: (await _database.schedule())?.cadenceMinutes ?? 60,
    );
    return start(session.id);
  }

  Future<SessionActionResult<RecessSession>> defer(
    int sessionId,
    RecessDeferralType type,
  ) async {
    final current = await _database.session(sessionId);
    if (current?.status != RecessSessionStatus.scheduled) {
      throw StateError('Cannot defer Recess session $sessionId.');
    }
    final delay = switch (type) {
      RecessDeferralType.fiveMinutes => const Duration(minutes: 5),
      RecessDeferralType.afterThis => const Duration(minutes: 15),
    };
    final deferredAt = _clock();
    final scheduledAt = deferredAt.add(delay);
    final session = await _database.deferSession(
      sessionId,
      type,
      scheduledAt,
      deferredAt,
    );
    final reminderScheduled = await _scheduleDeferredBell(
      session.id,
      scheduledAt,
    );
    // Keep the normal daily cadence alive even if this one-shot reminder is
    // ignored. openOrCreateScheduledSession reuses this deferred session.
    final cadence = await _scheduleNextCadence();
    return SessionActionResult(
      value: session,
      notificationSucceeded: reminderScheduled && cadence.notificationSucceeded,
    );
  }

  Future<SessionActionResult<RecessSession>> rainCheck(int sessionId) async {
    await _notifications.cancelDeferredBell();
    final session = await _database.rainCheckSession(sessionId, _clock());
    final cadence = await _scheduleNextCadence();
    return SessionActionResult(
      value: session,
      notificationSucceeded: cadence.notificationSucceeded,
    );
  }

  Future<SessionActionResult<RecessSession>> complete(int sessionId) async {
    final session = await _database.completeSession(sessionId, _clock());
    final cadence = await _scheduleNextCadence();
    return SessionActionResult(
      value: session,
      notificationSucceeded: cadence.notificationSucceeded,
    );
  }

  Future<RecessSession> _ensureExerciseAssigned(RecessSession session) async {
    if (session.exerciseId != null) return session;
    final exercise = await _selectExercise();
    return _database.assignExerciseToActiveSession(session.id, exercise.id);
  }

  Future<Exercise> _selectExercise() async {
    final previous = await _database.lastAssignedExerciseId();
    final recent = (await _database.completedSessions())
        .map((session) => session.exerciseId)
        .whereType<String>()
        .take(5)
        .toList(growable: false);
    final preferences = await _database.preferences();
    return _exercises.select(
      difficulty: preferences.exerciseDifficulty,
      previousExerciseId: previous,
      recentExerciseIds: recent,
    );
  }

  Future<SessionActionResult<RecessSession?>> _scheduleNextCadence({
    bool cancelObsolete = false,
  }) async {
    final schedule = await _database.schedule();
    if (schedule == null) {
      return const SessionActionResult(
        value: null,
        notificationSucceeded: false,
      );
    }
    final now = _clock();
    final times = await _cadenceTimes(now, schedule);
    if (times.isEmpty) {
      await _notifications.cancelCadenceBell();
      return const SessionActionResult(
        value: null,
        notificationSucceeded: true,
      );
    }
    final scheduledAt = times.first;
    final session = await _database.openOrCreateScheduledSession(
      scheduledAt: scheduledAt,
      createdAt: now,
      cadenceMinutes: schedule.cadenceMinutes,
    );
    final scheduled = await _rebuildCadence(
      session.id,
      times,
      cancelObsolete: cancelObsolete,
    );
    return SessionActionResult(
      value: session,
      notificationSucceeded: scheduled,
    );
  }

  Future<List<DateTime>> _cadenceTimes(
    DateTime now,
    WorkSchedule? schedule,
  ) async {
    if (schedule == null) return const [];
    final preferences = await _database.preferences();
    return cadenceBellTimes(
      schedule: schedule,
      now: now,
      preferences: preferences,
    );
  }

  Future<bool> _scheduleDeferredBell(
    int sessionId,
    DateTime scheduledAt, {
    BellSound? sound,
  }) async {
    final preferences = await _database.preferences();
    if (isDuringQuietHours(scheduledAt, preferences)) {
      await _notifications.cancelDeferredBell();
      return true;
    }
    return _notifications.scheduleDeferredBell(
      sessionId,
      scheduledAt,
      sound: sound ?? preferences.bellSound,
    );
  }

  Future<bool> _rebuildCadence(
    int sessionId,
    List<DateTime> times, {
    bool cancelObsolete = false,
  }) =>
      _serializeCadence(() async {
        final sound = await _bellSound();
        final expectedIds =
            times.map(NotificationService.cadenceNotificationId).toSet();
        if (cancelObsolete) {
          await _notifications.cancelCadenceBell(retaining: expectedIds);
        }
        var succeeded = true;
        for (final scheduledAt in times) {
          final scheduled = await _notifications.scheduleCadenceBell(
            sessionId,
            scheduledAt,
            sound: sound,
          );
          succeeded = scheduled && succeeded;
        }
        final pending = await _notifications.pendingCadenceBells();
        final pendingIds = pending.map((bell) => bell.id).toSet();
        final verified = expectedIds.every(pendingIds.contains);
        return succeeded && verified;
      });

  Future<BellSound> _bellSound() async =>
      (await _database.preferences()).bellSound;

  Future<T> _serializeCadence<T>(Future<T> Function() operation) {
    final result = _cadenceOperation.then((_) => operation());
    _cadenceOperation = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }
}
