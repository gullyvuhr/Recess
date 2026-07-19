enum RecessStatus { started, completed, rainCheck }

class WorkSchedule {
  const WorkSchedule({required this.startMinutes, required this.endMinutes});
  final int startMinutes;
  final int endMinutes;
}

class RecessEntry {
  const RecessEntry({required this.id, required this.status, required this.createdAt});
  final int id;
  final RecessStatus status;
  final DateTime createdAt;
}

class TodayProgress {
  const TodayProgress({required this.started, required this.completed, required this.rainChecks});
  final int started;
  final int completed;
  final int rainChecks;
}

