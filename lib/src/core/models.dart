enum RecessSessionStatus {
  scheduled,
  deferred,
  active,
  completed,
  rainChecked,
}

enum RecessDeferralType { fiveMinutes, afterThis }

enum ExerciseDifficulty { easy, standard, challenging }

enum BellSound { schoolBell, coachWhistle, gentleChime }

class RecessPreferences {
  const RecessPreferences({
    this.durationMinutes = 5,
    this.exerciseDifficulty = ExerciseDifficulty.standard,
    this.bellSound = BellSound.schoolBell,
    this.quietHoursEnabled = false,
    this.quietHoursStartMinutes = 22 * 60,
    this.quietHoursEndMinutes = 7 * 60,
    this.notificationsEnabled = true,
  });

  static const supportedDurations = [3, 5, 10, 15];

  final int durationMinutes;
  final ExerciseDifficulty exerciseDifficulty;
  final BellSound bellSound;
  final bool quietHoursEnabled;
  final int quietHoursStartMinutes;
  final int quietHoursEndMinutes;
  final bool notificationsEnabled;

  RecessPreferences copyWith({
    int? durationMinutes,
    ExerciseDifficulty? exerciseDifficulty,
    BellSound? bellSound,
    bool? quietHoursEnabled,
    int? quietHoursStartMinutes,
    int? quietHoursEndMinutes,
    bool? notificationsEnabled,
  }) =>
      RecessPreferences(
        durationMinutes: durationMinutes ?? this.durationMinutes,
        exerciseDifficulty: exerciseDifficulty ?? this.exerciseDifficulty,
        bellSound: bellSound ?? this.bellSound,
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietHoursStartMinutes:
            quietHoursStartMinutes ?? this.quietHoursStartMinutes,
        quietHoursEndMinutes: quietHoursEndMinutes ?? this.quietHoursEndMinutes,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );
}

enum HomeRecessState { scheduled, active, noMoreToday }

class HomeRecessStatus {
  const HomeRecessStatus(this.state, {this.scheduledAt});

  final HomeRecessState state;
  final DateTime? scheduledAt;
}

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

  Duration? get responseDelay {
    final start = startedAt;
    if (start == null || start.isBefore(originalScheduledAt)) return null;
    return start.difference(originalScheduledAt);
  }
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
