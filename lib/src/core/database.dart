import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

class RecessDatabase extends GeneratedDatabase {
  RecessDatabase(super.executor);

  static const _createSettings =
      'CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)';
  static const _createLegacyEntries =
      'CREATE TABLE IF NOT EXISTS recess_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, status TEXT NOT NULL, created_at INTEGER NOT NULL)';
  static const _createSessions = '''
    CREATE TABLE IF NOT EXISTS recess_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      original_scheduled_at INTEGER NOT NULL,
      scheduled_at INTEGER NOT NULL,
      acknowledged_at INTEGER,
      started_at INTEGER,
      completed_at INTEGER,
      status TEXT NOT NULL,
      deferral_type TEXT,
      deferral_count INTEGER NOT NULL DEFAULT 0,
      last_deferred_at INTEGER,
      rain_checked_at INTEGER,
      exercise_id TEXT,
      cadence_minutes INTEGER NOT NULL DEFAULT 60,
      created_at INTEGER NOT NULL
    )
  ''';
  static const _createOneOpenSessionIndex = '''
    CREATE UNIQUE INDEX IF NOT EXISTS one_open_recess_session
    ON recess_sessions((1))
    WHERE status IN ('scheduled', 'deferred', 'active')
  ''';
  static const _createHistoryDateIndex = '''
    CREATE INDEX IF NOT EXISTS recess_sessions_original_scheduled_at
    ON recess_sessions(original_scheduled_at)
  ''';
  static const _createHistoryStatusIndex = '''
    CREATE INDEX IF NOT EXISTS recess_sessions_status
    ON recess_sessions(status)
  ''';

  @override
  int get schemaVersion => 4;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) => _ensureSchema(),
        onUpgrade: (_, from, to) async {
          await customStatement(_createSettings);
          if (from < 2) {
            await customStatement(_createSessions);
            await customStatement('''
              INSERT INTO recess_sessions(
                original_scheduled_at,
                scheduled_at,
                acknowledged_at,
                started_at,
                completed_at,
                status,
                deferral_type,
                deferral_count,
                last_deferred_at,
                rain_checked_at,
                cadence_minutes,
                created_at
              )
              SELECT
                created_at,
                created_at,
                NULL,
                CASE WHEN status IN ('started', 'completed') THEN created_at END,
                CASE WHEN status = 'completed' THEN created_at END,
                CASE status
                  WHEN 'started' THEN 'completed'
                  WHEN 'completed' THEN 'completed'
                  WHEN 'rainCheck' THEN 'rainChecked'
                END,
                NULL,
                0,
                NULL,
                CASE WHEN status = 'rainCheck' THEN created_at END,
                COALESCE(
                  (SELECT CAST(value AS INTEGER) FROM settings WHERE key = 'cadence_minutes'),
                  60
                ),
                created_at
              FROM recess_entries
              WHERE status IN ('started', 'completed', 'rainCheck')
            ''');
          }
          if (from >= 2 && from < 3) {
            await customStatement(
              'ALTER TABLE recess_sessions ADD COLUMN exercise_id TEXT',
            );
          }
          if (from >= 2 && from < 4) {
            await customStatement(
              'ALTER TABLE recess_sessions ADD COLUMN original_scheduled_at INTEGER',
            );
            await customStatement(
              'ALTER TABLE recess_sessions ADD COLUMN acknowledged_at INTEGER',
            );
            await customStatement(
              'ALTER TABLE recess_sessions ADD COLUMN deferral_count INTEGER NOT NULL DEFAULT 0',
            );
            await customStatement(
              'ALTER TABLE recess_sessions ADD COLUMN last_deferred_at INTEGER',
            );
            await customStatement(
              'ALTER TABLE recess_sessions ADD COLUMN rain_checked_at INTEGER',
            );
            await customStatement(
              'ALTER TABLE recess_sessions ADD COLUMN cadence_minutes INTEGER NOT NULL DEFAULT 60',
            );
            await customStatement('''
              UPDATE recess_sessions
              SET
                original_scheduled_at = scheduled_at,
                deferral_count = CASE
                  WHEN status = 'deferred' OR deferral_type IS NOT NULL THEN 1
                  ELSE 0
                END,
                last_deferred_at = CASE
                  WHEN status = 'deferred' OR deferral_type IS NOT NULL THEN scheduled_at
                END,
                rain_checked_at = CASE
                  WHEN status = 'rainChecked' THEN scheduled_at
                END,
                cadence_minutes = COALESCE(
                  (SELECT CAST(value AS INTEGER) FROM settings WHERE key = 'cadence_minutes'),
                  60
                )
            ''');
          }
        },
        beforeOpen: (_) => _ensureSchema(),
      );

  Future<void> _ensureSchema() async {
    await customStatement(_createSettings);
    await customStatement(_createLegacyEntries);
    await customStatement(_createSessions);
    await customStatement(_createOneOpenSessionIndex);
    await customStatement(_createHistoryDateIndex);
    await customStatement(_createHistoryStatusIndex);
  }

  static Future<RecessDatabase> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final result = RecessDatabase(
      NativeDatabase.createInBackground(
        File(p.join(directory.path, 'recess.sqlite')),
      ),
    );
    await result.customSelect('SELECT 1').getSingle();
    return result;
  }

  Future<String?> setting(String key) async {
    final rows = await customSelect(
      'SELECT value FROM settings WHERE key = ?',
      variables: [Variable.withString(key)],
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('value');
  }

  Future<void> setSetting(String key, String value) => customInsert(
        'INSERT INTO settings(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        variables: [Variable.withString(key), Variable.withString(value)],
      );

  Future<void> saveSchedule(WorkSchedule schedule) async {
    await transaction(() async {
      await setSetting('work_start', '${schedule.startMinutes}');
      await setSetting('work_end', '${schedule.endMinutes}');
      await setSetting('cadence_minutes', '${schedule.cadenceMinutes}');
      await setSetting('onboarding_complete', 'true');
    });
  }

  Future<WorkSchedule?> schedule() async {
    final start = await setting('work_start');
    final end = await setting('work_end');
    final cadence = await setting('cadence_minutes');
    if (start == null || end == null) return null;
    return WorkSchedule(
      startMinutes: int.parse(start),
      endMinutes: int.parse(end),
      cadenceMinutes: cadence == null ? 60 : int.parse(cadence),
    );
  }

  Future<RecessPreferences> preferences() async {
    final duration = int.tryParse(await setting('recess_duration') ?? '');
    final difficulty = await setting('exercise_difficulty');
    final sound = await setting('bell_sound');
    final quietEnabled = await setting('quiet_hours_enabled');
    final quietStart = int.tryParse(await setting('quiet_hours_start') ?? '');
    final quietEnd = int.tryParse(await setting('quiet_hours_end') ?? '');
    final notifications = await setting('notifications_enabled');
    return RecessPreferences(
      durationMinutes: RecessPreferences.supportedDurations.contains(duration)
          ? duration!
          : 5,
      exerciseDifficulty: _enumByName(
        ExerciseDifficulty.values,
        difficulty,
        ExerciseDifficulty.standard,
      ),
      bellSound: _enumByName(
        BellSound.values,
        sound,
        BellSound.schoolBell,
      ),
      quietHoursEnabled: quietEnabled == 'true',
      quietHoursStartMinutes: quietStart != null &&
              quietStart >= 0 &&
              quietStart < Duration.minutesPerDay
          ? quietStart
          : 22 * 60,
      quietHoursEndMinutes:
          quietEnd != null && quietEnd >= 0 && quietEnd < Duration.minutesPerDay
              ? quietEnd
              : 7 * 60,
      notificationsEnabled: notifications != 'false',
    );
  }

  Future<void> savePreferences(RecessPreferences preferences) async {
    if (!RecessPreferences.supportedDurations
        .contains(preferences.durationMinutes)) {
      throw ArgumentError.value(
        preferences.durationMinutes,
        'durationMinutes',
        'Unsupported Recess duration.',
      );
    }
    await transaction(() async {
      await setSetting('recess_duration', '${preferences.durationMinutes}');
      await setSetting(
        'exercise_difficulty',
        preferences.exerciseDifficulty.name,
      );
      await setSetting('bell_sound', preferences.bellSound.name);
      await setSetting(
        'quiet_hours_enabled',
        '${preferences.quietHoursEnabled}',
      );
      await setSetting(
        'quiet_hours_start',
        '${preferences.quietHoursStartMinutes}',
      );
      await setSetting(
        'quiet_hours_end',
        '${preferences.quietHoursEndMinutes}',
      );
      await setSetting(
        'notifications_enabled',
        '${preferences.notificationsEnabled}',
      );
    });
  }

  T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  Future<RecessSession> createSession({
    required DateTime scheduledAt,
    required DateTime createdAt,
    int cadenceMinutes = 60,
  }) async {
    final id = await customInsert(
      'INSERT INTO recess_sessions(original_scheduled_at, scheduled_at, status, cadence_minutes, created_at) VALUES(?, ?, ?, ?, ?)',
      variables: [
        Variable.withInt(scheduledAt.millisecondsSinceEpoch),
        Variable.withInt(scheduledAt.millisecondsSinceEpoch),
        Variable.withString(RecessSessionStatus.scheduled.name),
        Variable.withInt(cadenceMinutes),
        Variable.withInt(createdAt.millisecondsSinceEpoch),
      ],
    );
    return (await session(id))!;
  }

  Future<RecessSession> openOrCreateScheduledSession({
    required DateTime scheduledAt,
    required DateTime createdAt,
    int cadenceMinutes = 60,
  }) =>
      transaction(() async {
        final open = await openSession();
        if (open != null) return open;
        return createSession(
          scheduledAt: scheduledAt,
          createdAt: createdAt,
          cadenceMinutes: cadenceMinutes,
        );
      });

  Future<RecessSession?> session(int id) async {
    final rows = await customSelect(
      'SELECT * FROM recess_sessions WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).get();
    return rows.isEmpty ? null : _sessionFromRow(rows.single);
  }

  Future<RecessSession?> openSession() async {
    final rows = await customSelect(
      "SELECT * FROM recess_sessions WHERE status IN ('scheduled', 'deferred', 'active') ORDER BY id DESC LIMIT 1",
    ).get();
    return rows.isEmpty ? null : _sessionFromRow(rows.single);
  }

  Future<RecessSession> startSession(
    int id,
    DateTime startedAt,
    String exerciseId,
  ) async {
    final changed = await customUpdate(
      "UPDATE recess_sessions SET status = ?, started_at = ?, exercise_id = ? WHERE id = ? AND status IN ('scheduled', 'deferred') AND exercise_id IS NULL",
      variables: [
        Variable.withString(RecessSessionStatus.active.name),
        Variable.withInt(startedAt.millisecondsSinceEpoch),
        Variable.withString(exerciseId),
        Variable.withInt(id),
      ],
    );
    return _requiredTransition(id, changed, 'start');
  }

  Future<RecessSession> assignExerciseToActiveSession(
    int id,
    String exerciseId,
  ) async {
    final changed = await customUpdate(
      "UPDATE recess_sessions SET exercise_id = ? WHERE id = ? AND status = 'active' AND exercise_id IS NULL",
      variables: [Variable.withString(exerciseId), Variable.withInt(id)],
    );
    if (changed == 0) {
      final existing = await session(id);
      if (existing?.status == RecessSessionStatus.active &&
          existing?.exerciseId != null) {
        return existing!;
      }
    }
    return _requiredTransition(id, changed, 'assign exercise to');
  }

  Future<String?> lastAssignedExerciseId() async {
    final rows = await customSelect(
      'SELECT exercise_id FROM recess_sessions WHERE exercise_id IS NOT NULL ORDER BY started_at DESC, id DESC LIMIT 1',
    ).get();
    return rows.isEmpty ? null : rows.single.read<String>('exercise_id');
  }

  Future<RecessSession?> markBellOpened(
    int id,
    DateTime openedAt,
  ) async {
    final changed = await customUpdate(
      "UPDATE recess_sessions SET acknowledged_at = COALESCE(acknowledged_at, ?) WHERE id = ? AND status IN ('scheduled', 'deferred')",
      variables: [
        Variable.withInt(openedAt.millisecondsSinceEpoch),
        Variable.withInt(id),
      ],
    );
    return changed == 1 ? session(id) : null;
  }

  Future<RecessSession> rescheduleCadenceSession(
    int id,
    DateTime scheduledAt,
  ) async {
    final changed = await customUpdate(
      "UPDATE recess_sessions SET scheduled_at = ? WHERE id = ? AND status = 'scheduled'",
      variables: [
        Variable.withInt(scheduledAt.millisecondsSinceEpoch),
        Variable.withInt(id),
      ],
    );
    return _requiredTransition(id, changed, 'reschedule');
  }

  Future<RecessSession> deferSession(
    int id,
    RecessDeferralType type,
    DateTime scheduledAt,
    DateTime deferredAt,
  ) async {
    final changed = await customUpdate(
      "UPDATE recess_sessions SET status = ?, deferral_type = ?, scheduled_at = ?, deferral_count = deferral_count + 1, last_deferred_at = ? WHERE id = ? AND status IN ('scheduled', 'deferred')",
      variables: [
        Variable.withString(RecessSessionStatus.deferred.name),
        Variable.withString(type.name),
        Variable.withInt(scheduledAt.millisecondsSinceEpoch),
        Variable.withInt(deferredAt.millisecondsSinceEpoch),
        Variable.withInt(id),
      ],
    );
    return _requiredTransition(id, changed, 'defer');
  }

  Future<RecessSession> rainCheckSession(int id, DateTime rainCheckedAt) async {
    final changed = await customUpdate(
      "UPDATE recess_sessions SET status = ?, rain_checked_at = ? WHERE id = ? AND status IN ('scheduled', 'deferred')",
      variables: [
        Variable.withString(RecessSessionStatus.rainChecked.name),
        Variable.withInt(rainCheckedAt.millisecondsSinceEpoch),
        Variable.withInt(id),
      ],
    );
    return _requiredTransition(id, changed, 'rain check');
  }

  Future<RecessSession> completeSession(int id, DateTime completedAt) async {
    final changed = await customUpdate(
      "UPDATE recess_sessions SET status = ?, completed_at = ? WHERE id = ? AND status = 'active' AND exercise_id IS NOT NULL",
      variables: [
        Variable.withString(RecessSessionStatus.completed.name),
        Variable.withInt(completedAt.millisecondsSinceEpoch),
        Variable.withInt(id),
      ],
    );
    return _requiredTransition(id, changed, 'complete');
  }

  Future<RecessSession> _requiredTransition(
    int id,
    int changed,
    String transition,
  ) async {
    if (changed != 1) {
      throw StateError('Cannot $transition Recess session $id.');
    }
    return (await session(id))!;
  }

  Future<TodayProgress> todayProgress({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final start = DateTime(current.year, current.month, current.day)
        .millisecondsSinceEpoch;
    final end = DateTime(current.year, current.month, current.day + 1)
        .millisecondsSinceEpoch;
    final row = await customSelect(
      '''
        SELECT
          SUM(CASE WHEN started_at >= ? AND started_at < ? THEN 1 ELSE 0 END) AS started,
          SUM(CASE WHEN completed_at >= ? AND completed_at < ? THEN 1 ELSE 0 END) AS completed,
          SUM(CASE WHEN status = 'rainChecked' AND rain_checked_at >= ? AND rain_checked_at < ? THEN 1 ELSE 0 END) AS rain_checks
        FROM recess_sessions
      ''',
      variables: [
        Variable.withInt(start),
        Variable.withInt(end),
        Variable.withInt(start),
        Variable.withInt(end),
        Variable.withInt(start),
        Variable.withInt(end),
      ],
    ).getSingle();
    return TodayProgress(
      started: row.readNullable<int>('started') ?? 0,
      completed: row.readNullable<int>('completed') ?? 0,
      rainChecks: row.readNullable<int>('rain_checks') ?? 0,
    );
  }

  Future<List<RecessSession>> sessionsInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    final rows = await customSelect(
      '''
        SELECT * FROM recess_sessions
        WHERE original_scheduled_at >= ? AND original_scheduled_at < ?
        ORDER BY original_scheduled_at DESC, id DESC
      ''',
      variables: [
        Variable.withInt(startInclusive.millisecondsSinceEpoch),
        Variable.withInt(endExclusive.millisecondsSinceEpoch),
      ],
    ).get();
    return rows.map(_sessionFromRow).toList();
  }

  Future<List<RecessSession>> sessionsForDay(DateTime localDay) {
    final start = DateTime(localDay.year, localDay.month, localDay.day);
    final end = DateTime(localDay.year, localDay.month, localDay.day + 1);
    return sessionsInRange(start, end);
  }

  Future<List<RecessSession>> completedSessions() =>
      _sessionsWhere("status = 'completed'", 'completed_at DESC, id DESC');

  Future<List<RecessSession>> deferredSessions() => _sessionsWhere(
        'deferral_count > 0',
        'last_deferred_at DESC, id DESC',
      );

  Future<List<RecessSession>> rainCheckedSessions() => _sessionsWhere(
        "status = 'rainChecked'",
        'rain_checked_at DESC, id DESC',
      );

  Future<RecessSession?> mostRecentCompletedSession() async {
    final sessions = await _sessionsWhere(
      "status = 'completed'",
      'completed_at DESC, id DESC',
      limit: 1,
    );
    return sessions.isEmpty ? null : sessions.single;
  }

  Future<Map<RecessSessionStatus, int>> sessionCountsByStatus() async {
    final rows = await customSelect(
      'SELECT status, COUNT(*) AS total FROM recess_sessions GROUP BY status',
    ).get();
    final counts = {
      for (final status in RecessSessionStatus.values) status: 0,
    };
    for (final row in rows) {
      counts[RecessSessionStatus.values.byName(row.read<String>('status'))] =
          row.read<int>('total');
    }
    return counts;
  }

  Future<Duration?> averageCompletedRecessDuration() => _averageDuration(
        'completed_at - started_at',
        "status = 'completed' AND started_at IS NOT NULL AND completed_at IS NOT NULL",
      );

  Future<Duration?> averageResponseDelay() => _averageDuration(
        'started_at - original_scheduled_at',
        'started_at IS NOT NULL',
      );

  Future<List<RecessSession>> _sessionsWhere(
    String where,
    String orderBy, {
    int? limit,
  }) async {
    final rows = await customSelect(
      'SELECT * FROM recess_sessions WHERE $where ORDER BY $orderBy${limit == null ? '' : ' LIMIT $limit'}',
    ).get();
    return rows.map(_sessionFromRow).toList();
  }

  Future<Duration?> _averageDuration(
    String expression,
    String where,
  ) async {
    final row = await customSelect(
      'SELECT AVG($expression) AS average_ms FROM recess_sessions WHERE $where',
    ).getSingle();
    final average = row.readNullable<double>('average_ms');
    return average == null ? null : Duration(milliseconds: average.round());
  }

  RecessSession _sessionFromRow(QueryRow row) {
    final deferral = row.readNullable<String>('deferral_type');
    return RecessSession(
      id: row.read<int>('id'),
      originalScheduledAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('original_scheduled_at'),
      ),
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('scheduled_at'),
      ),
      acknowledgedAt: _date(row.readNullable<int>('acknowledged_at')),
      startedAt: _date(row.readNullable<int>('started_at')),
      completedAt: _date(row.readNullable<int>('completed_at')),
      status: RecessSessionStatus.values.byName(row.read<String>('status')),
      deferralType:
          deferral == null ? null : RecessDeferralType.values.byName(deferral),
      deferralCount: row.read<int>('deferral_count'),
      lastDeferredAt: _date(row.readNullable<int>('last_deferred_at')),
      rainCheckedAt: _date(row.readNullable<int>('rain_checked_at')),
      exerciseId: row.readNullable<String>('exercise_id'),
      cadenceMinutes: row.read<int>('cadence_minutes'),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
    );
  }

  DateTime? _date(int? milliseconds) => milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds);
}
