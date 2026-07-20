import '../exercises/exercise.dart';
import '../exercises/exercise_repository.dart';
import 'database.dart';
import 'models.dart';

class TodayInsightMetrics {
  const TodayInsightMetrics({
    required this.completed,
    required this.deferred,
    required this.missed,
    required this.completedMovementDuration,
  });

  final int completed;
  final int deferred;

  /// Null until the Fact Engine has an explicit missed/expired lifecycle fact.
  final int? missed;
  final Duration completedMovementDuration;
}

class SevenDayInsightMetrics {
  const SevenDayInsightMetrics({
    required this.scheduled,
    required this.completed,
    required this.completionRate,
    required this.averageResponseTime,
    required this.averageCompletedDuration,
  });

  /// Persisted Recess occurrences in the period, not raw OS notifications.
  final int scheduled;
  final int completed;
  final double? completionRate;
  final Duration? averageResponseTime;
  final Duration? averageCompletedDuration;
}

enum InsightObservationType {
  weeklyCompletion,
  lateDeferrals,
  responseTimeImproving,
  morningCompletion,
}

class InsightObservation {
  const InsightObservation({
    required this.type,
    required this.title,
    required this.description,
    this.supportingValue,
    this.comparisonPeriod,
  });

  final InsightObservationType type;
  final String title;
  final String description;
  final double? supportingValue;
  final String? comparisonPeriod;

  @override
  bool operator ==(Object other) =>
      other is InsightObservation &&
      other.type == type &&
      other.title == title &&
      other.description == description &&
      other.supportingValue == supportingValue &&
      other.comparisonPeriod == comparisonPeriod;

  @override
  int get hashCode => Object.hash(
        type,
        title,
        description,
        supportingValue,
        comparisonPeriod,
      );
}

class InsightSummary {
  const InsightSummary({
    required this.today,
    required this.sevenDays,
    required this.observations,
  });

  final TodayInsightMetrics today;
  final SevenDayInsightMetrics sevenDays;
  final List<InsightObservation> observations;
}

class InsightEngine {
  const InsightEngine();

  // Explicit sufficiency thresholds. Prefer silence below these boundaries.
  static const minimumWeeklyOccurrences = 4;
  static const minimumDeferrals = 4;
  static const lateDeferralShare = 0.65;
  static const minimumResponseSamplesPerPeriod = 3;
  static const minimumResponseImprovement = 0.20;
  static const minimumResponseImprovementDuration = Duration(minutes: 2);
  static const minimumTimeOfDaySamples = 4;
  static const minimumCompletionRateDifference = 0.20;
  static const maximumObservations = 3;

  InsightSummary summarize({
    required List<RecessSession> sessions,
    required List<Exercise> exercises,
    required DateTime now,
  }) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final currentStart = todayStart.subtract(const Duration(days: 6));
    final previousStart = todayStart.subtract(const Duration(days: 13));
    final current = _inRange(sessions, currentStart, tomorrow);
    final previous = _inRange(sessions, previousStart, currentStart);
    final today = _inRange(sessions, todayStart, tomorrow);
    final exerciseById = {
      for (final exercise in exercises) exercise.id: exercise
    };

    final completedCurrent = _completed(current);
    final currentResponse =
        _durations(current, (session) => session.responseDelay);
    final currentDuration =
        _durations(completedCurrent, (session) => session.completedDuration);

    final candidates = <_ObservationCandidate>[
      ..._weeklyCompletion(current, completedCurrent),
      ..._lateDeferrals(current),
      ..._responseImprovement(current, previous),
      ..._morningCompletion(current),
    ]..sort((a, b) {
        final strength = b.strength.compareTo(a.strength);
        return strength != 0
            ? strength
            : a.observation.type.index.compareTo(b.observation.type.index);
      });

    return InsightSummary(
      today: TodayInsightMetrics(
        completed: _completed(today).length,
        deferred: today.where((session) => session.deferralCount > 0).length,
        missed: null,
        completedMovementDuration: _durations(
          _completed(today).where(
            (session) =>
                exerciseById[session.exerciseId]?.category ==
                ExerciseCategory.movement,
          ),
          (session) => session.completedDuration,
        ).fold(Duration.zero, (total, value) => total + value),
      ),
      sevenDays: SevenDayInsightMetrics(
        scheduled: current.length,
        completed: completedCurrent.length,
        completionRate:
            current.isEmpty ? null : completedCurrent.length / current.length,
        averageResponseTime: _average(currentResponse),
        averageCompletedDuration: _average(currentDuration),
      ),
      observations: List.unmodifiable(
        candidates
            .take(maximumObservations)
            .map((candidate) => candidate.observation),
      ),
    );
  }

  List<_ObservationCandidate> _weeklyCompletion(
    List<RecessSession> sessions,
    List<RecessSession> completed,
  ) {
    if (sessions.length < minimumWeeklyOccurrences) return const [];
    return [
      _ObservationCandidate(
        strength: (sessions.length / 20).clamp(0.0, 0.5),
        observation: InsightObservation(
          type: InsightObservationType.weeklyCompletion,
          title: 'Seven-day completion',
          description:
              'You completed ${completed.length} of ${sessions.length} scheduled Recesses this week.',
          supportingValue: completed.length / sessions.length,
          comparisonPeriod: 'Last 7 days',
        ),
      ),
    ];
  }

  List<_ObservationCandidate> _lateDeferrals(List<RecessSession> sessions) {
    final deferred = sessions
        .where((session) =>
            session.deferralCount > 0 && session.lastDeferredAt != null)
        .toList(growable: false);
    if (deferred.length < minimumDeferrals) return const [];
    final late =
        deferred.where((session) => session.lastDeferredAt!.hour >= 14).length;
    final share = late / deferred.length;
    if (share < lateDeferralShare) return const [];
    return [
      _ObservationCandidate(
        strength: share - 0.5,
        observation: InsightObservation(
          type: InsightObservationType.lateDeferrals,
          title: 'Afternoon deferrals',
          description: 'Most of your deferrals happen after 2 PM.',
          supportingValue: share,
          comparisonPeriod: 'Last 7 days',
        ),
      ),
    ];
  }

  List<_ObservationCandidate> _responseImprovement(
    List<RecessSession> current,
    List<RecessSession> previous,
  ) {
    final currentValues =
        _durations(current, (session) => session.responseDelay);
    final previousValues =
        _durations(previous, (session) => session.responseDelay);
    if (currentValues.length < minimumResponseSamplesPerPeriod ||
        previousValues.length < minimumResponseSamplesPerPeriod) {
      return const [];
    }
    final currentAverage = _average(currentValues)!;
    final previousAverage = _average(previousValues)!;
    if (previousAverage <= Duration.zero) return const [];
    final difference = previousAverage - currentAverage;
    final improvement =
        difference.inMicroseconds / previousAverage.inMicroseconds;
    if (difference < minimumResponseImprovementDuration ||
        improvement < minimumResponseImprovement) {
      return const [];
    }
    return [
      _ObservationCandidate(
        strength: improvement,
        observation: InsightObservation(
          type: InsightObservationType.responseTimeImproving,
          title: 'Response time',
          description: 'Your average response time is improving.',
          supportingValue: improvement,
          comparisonPeriod: 'Last 7 days vs previous 7 days',
        ),
      ),
    ];
  }

  List<_ObservationCandidate> _morningCompletion(
    List<RecessSession> sessions,
  ) {
    final morning = sessions
        .where((session) => session.originalScheduledAt.hour < 12)
        .toList(growable: false);
    final later = sessions
        .where((session) => session.originalScheduledAt.hour >= 12)
        .toList(growable: false);
    if (morning.length < minimumTimeOfDaySamples ||
        later.length < minimumTimeOfDaySamples) {
      return const [];
    }
    final morningRate = _completed(morning).length / morning.length;
    final laterRate = _completed(later).length / later.length;
    final difference = morningRate - laterRate;
    if (difference < minimumCompletionRateDifference) return const [];
    return [
      _ObservationCandidate(
        strength: difference,
        observation: InsightObservation(
          type: InsightObservationType.morningCompletion,
          title: 'Time of day',
          description: 'Morning Recesses are completed more often.',
          supportingValue: difference,
          comparisonPeriod: 'Morning vs afternoon, last 7 days',
        ),
      ),
    ];
  }

  List<RecessSession> _inRange(
    List<RecessSession> sessions,
    DateTime start,
    DateTime end,
  ) =>
      sessions
          .where(
            (session) =>
                !session.originalScheduledAt.isBefore(start) &&
                session.originalScheduledAt.isBefore(end),
          )
          .toList(growable: false);

  List<RecessSession> _completed(Iterable<RecessSession> sessions) => sessions
      .where((session) => session.status == RecessSessionStatus.completed)
      .toList(growable: false);

  List<Duration> _durations(
    Iterable<RecessSession> sessions,
    Duration? Function(RecessSession) select,
  ) =>
      sessions.map(select).whereType<Duration>().toList(growable: false);

  Duration? _average(List<Duration> values) {
    if (values.isEmpty) return null;
    final microseconds = values.fold<int>(
      0,
      (total, value) => total + value.inMicroseconds,
    );
    return Duration(microseconds: microseconds ~/ values.length);
  }
}

class InsightService {
  const InsightService({
    required this.database,
    required this.exercises,
    this.engine = const InsightEngine(),
  });

  final RecessDatabase database;
  final ExerciseCatalog exercises;
  final InsightEngine engine;

  Future<InsightSummary> load(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    final sessions = await database.sessionsInRange(
      today.subtract(const Duration(days: 13)),
      DateTime(now.year, now.month, now.day + 1),
    );
    return engine.summarize(
      sessions: sessions,
      exercises: await exercises.load(),
      now: now,
    );
  }
}

class _ObservationCandidate {
  const _ObservationCandidate({
    required this.strength,
    required this.observation,
  });

  final double strength;
  final InsightObservation observation;
}
