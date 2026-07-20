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
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.deferralType,
    this.exerciseId,
  });

  final int id;
  final DateTime scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final RecessSessionStatus status;
  final RecessDeferralType? deferralType;
  final String? exerciseId;
  final DateTime createdAt;

  bool get canDefer => status == RecessSessionStatus.scheduled;
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
