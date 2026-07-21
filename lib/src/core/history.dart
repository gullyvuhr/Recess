import '../exercises/exercise_repository.dart';
import 'database.dart';
import 'models.dart';

class HistoryPeriod {
  const HistoryPeriod(this.start);

  factory HistoryPeriod.current(DateTime now) => HistoryPeriod(
        DateTime(now.year, now.month, now.day).subtract(
          const Duration(days: 6),
        ),
      );

  final DateTime start;

  DateTime get endExclusive => start.add(const Duration(days: 7));
  DateTime get endInclusive => endExclusive.subtract(const Duration(days: 1));

  HistoryPeriod previous() =>
      HistoryPeriod(start.subtract(const Duration(days: 7)));

  HistoryPeriod next(DateTime now) {
    final current = HistoryPeriod.current(now);
    final candidate = HistoryPeriod(start.add(const Duration(days: 7)));
    return candidate.start.isAfter(current.start) ? current : candidate;
  }

  bool canMoveNext(DateTime now) =>
      start.isBefore(HistoryPeriod.current(now).start);

  @override
  bool operator ==(Object other) =>
      other is HistoryPeriod && other.start == start;

  @override
  int get hashCode => start.hashCode;
}

class HistorySummary {
  const HistorySummary({
    required this.completed,
    required this.deferred,
    required this.rainChecked,
    required this.averageDuration,
    required this.averageResponseDelay,
  });

  final int completed;
  final int deferred;
  final int rainChecked;
  final Duration? averageDuration;
  final Duration? averageResponseDelay;
}

class HistorySession {
  const HistorySession({required this.session, this.exerciseName});

  final RecessSession session;
  final String? exerciseName;
}

class HistoryDay {
  const HistoryDay({required this.date, required this.sessions});

  final DateTime date;
  final List<HistorySession> sessions;

  int get completed => sessions
      .where((item) => item.session.status == RecessSessionStatus.completed)
      .length;
  int get deferred =>
      sessions.where((item) => item.session.deferralCount > 0).length;
  int get rainChecked => sessions
      .where((item) => item.session.status == RecessSessionStatus.rainChecked)
      .length;
}

class HistoryData {
  const HistoryData({
    required this.period,
    required this.summary,
    required this.days,
  });

  final HistoryPeriod period;
  final HistorySummary summary;
  final List<HistoryDay> days;

  bool get isEmpty => days.isEmpty;
}

class HistoryService {
  const HistoryService({required this.database, required this.exercises});

  final RecessDatabase database;
  final ExerciseCatalog exercises;

  Future<List<HistorySession>> loadRecentCompleted({int limit = 4}) async {
    final sessions = (await database.completedSessions()).take(limit).toList();
    final catalog = await exercises.load();
    final exerciseNames = {
      for (final exercise in catalog) exercise.id: exercise.title
    };
    return sessions
        .map(
          (session) => HistorySession(
            session: session,
            exerciseName: session.exerciseId == null
                ? null
                : exerciseNames[session.exerciseId],
          ),
        )
        .toList(growable: false);
  }

  Future<HistoryData> load(HistoryPeriod period) async {
    final sessions = await database.sessionsInRange(
      period.start,
      period.endExclusive,
    );
    final catalog = await exercises.load();
    final exerciseNames = {
      for (final exercise in catalog) exercise.id: exercise.title
    };
    final items = sessions
        .map(
          (session) => HistorySession(
            session: session,
            exerciseName: session.exerciseId == null
                ? null
                : exerciseNames[session.exerciseId],
          ),
        )
        .toList(growable: false);

    final grouped = <DateTime, List<HistorySession>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.session.workdayDate, () => []).add(item);
    }
    final days = grouped.entries
        .map((entry) => HistoryDay(date: entry.key, sessions: entry.value))
        .toList(growable: false)
      ..sort((a, b) => b.date.compareTo(a.date));

    final completed = sessions
        .where((session) => session.status == RecessSessionStatus.completed)
        .toList(growable: false);
    final durations = completed
        .map((session) => session.completedDuration)
        .whereType<Duration>();
    final delays =
        sessions.map((session) => session.responseDelay).whereType<Duration>();

    return HistoryData(
      period: period,
      summary: HistorySummary(
        completed: completed.length,
        deferred: sessions.where((session) => session.deferralCount > 0).length,
        rainChecked: sessions
            .where(
                (session) => session.status == RecessSessionStatus.rainChecked)
            .length,
        averageDuration: _average(durations),
        averageResponseDelay: _average(delays),
      ),
      days: days,
    );
  }

  Duration? _average(Iterable<Duration> values) {
    var count = 0;
    var totalMicroseconds = 0;
    for (final value in values) {
      count++;
      totalMicroseconds += value.inMicroseconds;
    }
    return count == 0
        ? null
        : Duration(microseconds: totalMicroseconds ~/ count);
  }
}
