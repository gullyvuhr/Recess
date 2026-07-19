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
  static const defaultExerciseEnvironment = ExerciseEnvironment.indoor;

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

  Future<SessionActionResult<RecessSession?>> restore() async {
    final open = await _database.openSession();
    if (open == null) {
      return _scheduleNextCadence();
    }
    if (open.status == RecessSessionStatus.scheduled) {
      final scheduledAt = _nextCadenceAt(_clock(), await _database.schedule());
      if (scheduledAt != null) {
        final rescheduled = await _database.rescheduleCadenceSession(
          open.id,
          scheduledAt,
        );
        final scheduled = await _notifications.scheduleCadenceBell(
          rescheduled.id,
          rescheduled.scheduledAt,
        );
        return SessionActionResult(
          value: rescheduled,
          notificationSucceeded: scheduled,
        );
      }
    } else if (open.status == RecessSessionStatus.deferred) {
      final scheduled =
          await _notifications.scheduleDeferredBell(open.id, open.scheduledAt);
      return SessionActionResult(
        value: open,
        notificationSucceeded: scheduled,
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
    await _notifications.cancelCadenceBell();
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
    );
    return start(session.id);
  }

  Future<SessionActionResult<RecessSession>> defer(
    int sessionId,
    RecessDeferralType type,
  ) async {
    await _notifications.cancelCadenceBell();
    final delay = switch (type) {
      RecessDeferralType.fiveMinutes => const Duration(minutes: 5),
      RecessDeferralType.afterThis => const Duration(minutes: 15),
    };
    final scheduledAt = _clock().add(delay);
    final session = await _database.deferSession(
      sessionId,
      type,
      scheduledAt,
    );
    final reminderScheduled =
        await _notifications.scheduleDeferredBell(session.id, scheduledAt);
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
    final session = await _database.rainCheckSession(sessionId);
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
    return _exercises.select(
      environment: defaultExerciseEnvironment,
      previousExerciseId: previous,
    );
  }

  Future<SessionActionResult<RecessSession?>> _scheduleNextCadence() async {
    final schedule = await _database.schedule();
    if (schedule == null) {
      return const SessionActionResult(
        value: null,
        notificationSucceeded: false,
      );
    }
    final now = _clock();
    final scheduledAt = _nextCadenceAt(now, schedule)!;
    final session = await _database.openOrCreateScheduledSession(
      scheduledAt: scheduledAt,
      createdAt: now,
    );
    final scheduled =
        await _notifications.scheduleCadenceBell(session.id, scheduledAt);
    return SessionActionResult(
      value: session,
      notificationSucceeded: scheduled,
    );
  }

  DateTime? _nextCadenceAt(DateTime now, WorkSchedule? schedule) {
    if (schedule == null) return null;
    final hour = schedule.bellMinutes ~/ 60;
    final minute = schedule.bellMinutes % 60;
    var result = DateTime(now.year, now.month, now.day, hour, minute);
    if (!result.isAfter(now)) {
      result = DateTime(now.year, now.month, now.day + 1, hour, minute);
    }
    return result;
  }
}
