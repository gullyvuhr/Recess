import 'models.dart';

const cadenceScheduleDays = 7;
const maxScheduledCadenceBells = 60;

({DateTime start, DateTime end}) currentLocalCalendarWeek(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(
    today.year,
    today.month,
    today.day - (today.weekday - DateTime.monday),
  );
  return (
    start: start,
    end: DateTime(start.year, start.month, start.day + 7),
  );
}

bool isDuringQuietHours(
  DateTime time,
  RecessPreferences preferences,
) {
  if (!preferences.quietHoursEnabled) return false;

  final start = preferences.quietHoursStartMinutes;
  final end = preferences.quietHoursEndMinutes;
  if (start == end) return false;

  final minutes = time.hour * 60 + time.minute;
  if (start < end) {
    return minutes >= start && minutes < end;
  }
  return minutes >= start || minutes < end;
}

List<DateTime> cadenceBellTimes({
  required WorkSchedule schedule,
  required DateTime now,
  RecessPreferences preferences = const RecessPreferences(),
  int days = cadenceScheduleDays,
  int limit = maxScheduledCadenceBells,
}) {
  if (days <= 0 || limit <= 0) return const [];

  final firstDay = DateTime(now.year, now.month, now.day);
  final end = DateTime(firstDay.year, firstDay.month, firstDay.day + days);
  return scheduledBellTimesInRange(
    schedule: schedule,
    preferences: preferences,
    start: now,
    end: end,
    includeStart: false,
    limit: limit,
  );
}

List<DateTime> scheduledBellTimesInRange({
  required WorkSchedule schedule,
  required RecessPreferences preferences,
  required DateTime start,
  required DateTime end,
  bool includeStart = true,
  int? limit,
}) {
  if (!end.isAfter(start) || (limit != null && limit <= 0)) return const [];

  final result = <DateTime>[];
  final firstDay = DateTime(start.year, start.month, start.day);
  for (var dayOffset = 0; limit == null || result.length < limit; dayOffset++) {
    final day = DateTime(
      firstDay.year,
      firstDay.month,
      firstDay.day + dayOffset,
    );
    if (!day.isBefore(end)) break;
    for (var minutes = schedule.startMinutes + schedule.cadenceMinutes;
        minutes < schedule.endMinutes &&
            (limit == null || result.length < limit);
        minutes += schedule.cadenceMinutes) {
      final bell = DateTime(
        day.year,
        day.month,
        day.day,
        minutes ~/ 60,
        minutes % 60,
      );
      final afterStart =
          includeStart ? !bell.isBefore(start) : bell.isAfter(start);
      if (afterStart &&
          bell.isBefore(end) &&
          !isDuringQuietHours(bell, preferences)) {
        result.add(bell);
      }
    }
  }
  return result;
}
