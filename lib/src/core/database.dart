import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

class RecessDatabase extends GeneratedDatabase {
  RecessDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (_) async {
          await customStatement('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
          await customStatement('CREATE TABLE IF NOT EXISTS recess_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, status TEXT NOT NULL, created_at INTEGER NOT NULL)');
        },
      );

  static Future<RecessDatabase> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final result = RecessDatabase(NativeDatabase.createInBackground(File(p.join(directory.path, 'recess.sqlite'))));
    await result.customSelect('SELECT 1').getSingle();
    return result;
  }

  Future<String?> setting(String key) async {
    final rows = await customSelect('SELECT value FROM settings WHERE key = ?', variables: [Variable.withString(key)]).get();
    return rows.isEmpty ? null : rows.first.read<String>('value');
  }

  Future<void> setSetting(String key, String value) => customInsert(
        'INSERT INTO settings(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        variables: [Variable.withString(key), Variable.withString(value)],
      );

  Future<void> saveSchedule(WorkSchedule schedule) async {
    await setSetting('work_start', '${schedule.startMinutes}');
    await setSetting('work_end', '${schedule.endMinutes}');
    await setSetting('onboarding_complete', 'true');
  }

  Future<WorkSchedule?> schedule() async {
    final start = await setting('work_start');
    final end = await setting('work_end');
    if (start == null || end == null) return null;
    return WorkSchedule(startMinutes: int.parse(start), endMinutes: int.parse(end));
  }

  Future<int> addEntry(RecessStatus status) => customInsert(
        'INSERT INTO recess_entries(status, created_at) VALUES(?, ?)',
        variables: [Variable.withString(status.name), Variable.withInt(DateTime.now().millisecondsSinceEpoch)],
      );

  Future<TodayProgress> todayProgress() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await customSelect(
      'SELECT status, COUNT(*) AS total FROM recess_entries WHERE created_at >= ? AND created_at < ? GROUP BY status',
      variables: [Variable.withInt(start), Variable.withInt(end)],
    ).get();
    final counts = <String, int>{for (final row in rows) row.read<String>('status'): row.read<int>('total')};
    return TodayProgress(
      started: counts[RecessStatus.started.name] ?? 0,
      completed: counts[RecessStatus.completed.name] ?? 0,
      rainChecks: counts[RecessStatus.rainCheck.name] ?? 0,
    );
  }
}
