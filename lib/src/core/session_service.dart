import 'database.dart';
import 'models.dart';
import 'notifications.dart';
import '../exercises/exercise.dart';
import '../exercises/exercise_service.dart';

typedef Clock = DateTime Function();

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

  Future<RecessSession?> restore() async {
    final open = await _database.openSession();
    if (open == null) {
      await _scheduleNextCadence();
      return null;
    }
    if (open.status == RecessSessionStatus.scheduled) {
      final scheduledAt = _nextCadenceAt(_clock(), await _database.schedule());
      if (scheduledAt != null) {
        final rescheduled = await _database.rescheduleCadenceSession(
          open.id,
          scheduledAt,
        );
        await _notifications.scheduleCadenceBell(
          rescheduled.id,
          rescheduled.scheduledAt,
        );
      }
    } else if (open.status == RecessSessionStatus.deferred) {
      await _notifications.scheduleDeferredBell(open.id, open.scheduledAt);
    } else if (open.status == RecessSessionStatus.active) {
      return _ensureExerciseAssigned(open);
    }
    return open;
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

  Future<RecessSession> ringBellNow() async {
    final open = await _database.openSession();
    final session = open ?? await _scheduleNextCadence();
    if (session == null) {
      throw StateError('A work schedule is required before ringing Bells.');
    }
    await _notifications.ringBells(
      session.id,
      deferred: session.status == RecessSessionStatus.deferred,
    );
    return session;
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
    );
    return start(session.id);
  }

  Future<RecessSession> defer(
    int sessionId,
    RecessDeferralType type,
  ) async {
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
    await _notifications.scheduleDeferredBell(session.id, scheduledAt);
    return session;
  }

  Future<RecessSession> rainCheck(int sessionId) async {
    await _notifications.cancelDeferredBell();
    final session = await _database.rainCheckSession(sessionId);
    await _scheduleNextCadence();
    return session;
  }

  Future<RecessSession> complete(int sessionId) async {
    final session = await _database.completeSession(sessionId, _clock());
    await _scheduleNextCadence();
    return session;
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

  Future<RecessSession?> _scheduleNextCadence() async {
    final schedule = await _database.schedule();
    if (schedule == null) return null;
    final now = _clock();
    final scheduledAt = _nextCadenceAt(now, schedule)!;
    final session = await _database.openOrCreateScheduledSession(
      scheduledAt: scheduledAt,
      createdAt: now,
    );
    await _notifications.scheduleCadenceBell(session.id, scheduledAt);
    return session;
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
