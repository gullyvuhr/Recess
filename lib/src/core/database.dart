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
      scheduled_at INTEGER NOT NULL,
      started_at INTEGER,
      completed_at INTEGER,
      status TEXT NOT NULL,
      deferral_type TEXT,
      exercise_id TEXT,
      created_at INTEGER NOT NULL
    )
  ''';
  static const _createOneOpenSessionIndex = '''
    CREATE UNIQUE INDEX IF NOT EXISTS one_open_recess_session
    ON recess_sessions((1))
    WHERE status IN ('scheduled', 'deferred', 'active')
  ''';

  @override
  int get schemaVersion => 3;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) => _ensureSchema(),
        onUpgrade: (_, from, to) async {
          if (from < 2) {
            await customStatement(_createSessions);
            await customStatement('''
              INSERT INTO recess_sessions(
                scheduled_at,
                started_at,
                completed_at,
                status,
                deferral_type,
                created_at
              )
              SELECT
                created_at,
                CASE WHEN status IN ('started', 'completed') THEN created_at END,
                CASE WHEN status = 'completed' THEN created_at END,
                CASE status
                  WHEN 'started' THEN 'completed'
                  WHEN 'completed' THEN 'completed'
                  WHEN 'rainCheck' THEN 'rainChecked'
                END,
                NULL,
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
        },
        beforeOpen: (_) => _ensureSchema(),
      );

  Future<void> _ensureSchema() async {
    await customStatement(_createSettings);
    await customStatement(_createLegacyEntries);
    await customStatement(_createSessions);
    await customStatement(_createOneOpenSessionIndex);
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

  Future<RecessSession> createSession({
    required DateTime scheduledAt,
    required DateTime createdAt,
  }) async {
    final id = await customInsert(
      'INSERT INTO recess_sessions(scheduled_at, status, created_at) VALUES(?, ?, ?)',
      variables: [
        Variable.withInt(scheduledAt.millisecondsSinceEpoch),
        Variable.withString(RecessSessionStatus.scheduled.name),
        Variable.withInt(createdAt.millisecondsSinceEpoch),
      ],
    );
    return (await session(id))!;
  }

  Future<RecessSession> openOrCreateScheduledSession({
    required DateTime scheduledAt,
    required DateTime createdAt,
  }) =>
      transaction(() async {
        final open = await openSession();
        if (open != null) return open;
        return createSession(scheduledAt: scheduledAt, createdAt: createdAt);
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
      "UPDATE recess_sessions SET scheduled_at = ? WHERE id = ? AND status IN ('scheduled', 'deferred')",
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
  ) async {
    final changed = await customUpdate(
      "UPDATE recess_sessions SET status = ?, deferral_type = ?, scheduled_at = ? WHERE id = ? AND status = 'scheduled'",
      variables: [
        Variable.withString(RecessSessionStatus.deferred.name),
        Variable.withString(type.name),
        Variable.withInt(scheduledAt.millisecondsSinceEpoch),
        Variable.withInt(id),
      ],
    );
    return _requiredTransition(id, changed, 'defer');
  }

  Future<RecessSession> rainCheckSession(int id) async {
    final changed = await customUpdate(
      "UPDATE recess_sessions SET status = ? WHERE id = ? AND status IN ('scheduled', 'deferred')",
      variables: [
        Variable.withString(RecessSessionStatus.rainChecked.name),
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
          SUM(CASE WHEN status = 'rainChecked' AND scheduled_at >= ? AND scheduled_at < ? THEN 1 ELSE 0 END) AS rain_checks
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

  RecessSession _sessionFromRow(QueryRow row) {
    final deferral = row.readNullable<String>('deferral_type');
    return RecessSession(
      id: row.read<int>('id'),
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('scheduled_at'),
      ),
      startedAt: _date(row.readNullable<int>('started_at')),
      completedAt: _date(row.readNullable<int>('completed_at')),
      status: RecessSessionStatus.values.byName(row.read<String>('status')),
      deferralType:
          deferral == null ? null : RecessDeferralType.values.byName(deferral),
      exerciseId: row.readNullable<String>('exercise_id'),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
    );
  }

  DateTime? _date(int? milliseconds) => milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds);
}
