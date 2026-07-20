import 'models.dart';

const cadenceScheduleDays = 7;
const maxScheduledCadenceBells = 60;

List<DateTime> cadenceBellTimes({
  required WorkSchedule schedule,
  required DateTime now,
  int days = cadenceScheduleDays,
  int limit = maxScheduledCadenceBells,
}) {
  if (days <= 0 || limit <= 0) return const [];

  final result = <DateTime>[];
  final firstDay = DateTime(now.year, now.month, now.day);
  for (var dayOffset = 0;
      dayOffset < days && result.length < limit;
      dayOffset++) {
    final day = DateTime(
      firstDay.year,
      firstDay.month,
      firstDay.day + dayOffset,
    );
    for (var minutes = schedule.startMinutes + schedule.cadenceMinutes;
        minutes < schedule.endMinutes && result.length < limit;
        minutes += schedule.cadenceMinutes) {
      final bell = DateTime(
        day.year,
        day.month,
        day.day,
        minutes ~/ 60,
        minutes % 60,
      );
      if (bell.isAfter(now)) result.add(bell);
    }
  }
  return result;
}
