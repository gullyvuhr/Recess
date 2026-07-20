enum RecessSessionStatus {
  scheduled,
  deferred,
  active,
  completed,
  rainChecked,
}

enum RecessDeferralType { fiveMinutes, afterThis }

class WorkSchedule {
  const WorkSchedule({
    required this.startMinutes,
    required this.endMinutes,
    this.cadenceMinutes = 60,
  }) : assert(cadenceMinutes > 0);

  final int startMinutes;
  final int endMinutes;
  final int cadenceMinutes;

  int get bellMinutes => startMinutes + (endMinutes - startMinutes) ~/ 2;
}

class RecessSession {
  const RecessSession({
    required this.id,
    required this.originalScheduledAt,
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
    required this.deferralCount,
    required this.cadenceMinutes,
    this.acknowledgedAt,
    this.startedAt,
    this.completedAt,
    this.deferralType,
    this.lastDeferredAt,
    this.rainCheckedAt,
    this.exerciseId,
  });

  final int id;
  final DateTime originalScheduledAt;
  final DateTime scheduledAt;
  final DateTime? acknowledgedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final RecessSessionStatus status;
  final RecessDeferralType? deferralType;
  final int deferralCount;
  final DateTime? lastDeferredAt;
  final DateTime? rainCheckedAt;
  final String? exerciseId;
  final int cadenceMinutes;
  final DateTime createdAt;

  bool get canDefer => status == RecessSessionStatus.scheduled;

  bool get isTerminal =>
      status == RecessSessionStatus.completed ||
      status == RecessSessionStatus.rainChecked;

  DateTime get workdayDate => DateTime(
        originalScheduledAt.year,
        originalScheduledAt.month,
        originalScheduledAt.day,
      );

  Duration? get completedDuration => startedAt == null || completedAt == null
      ? null
      : completedAt!.difference(startedAt!);

  Duration? get responseDelay => startedAt?.difference(originalScheduledAt);
}

class TodayProgress {
  const TodayProgress({
    required this.started,
    required this.completed,
    required this.rainChecks,
  });

  final int started;
  final int completed;
  final int rainChecks;
}
