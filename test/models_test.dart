import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/models.dart';

void main() {
  test('work schedule retains minute-of-day boundaries', () {
    const schedule = WorkSchedule(startMinutes: 540, endMinutes: 1020);
    expect(schedule.startMinutes, 9 * 60);
    expect(schedule.endMinutes, 17 * 60);
    expect(schedule.bellMinutes, 13 * 60);
  });

  test('bell falls at the midpoint of an uneven workday', () {
    const schedule = WorkSchedule(
      startMinutes: 8 * 60 + 30,
      endMinutes: 17 * 60,
    );
    expect(schedule.bellMinutes, 12 * 60 + 45);
  });

  test('today progress exposes each outcome separately', () {
    const progress = TodayProgress(started: 2, completed: 1, rainChecks: 1);
    expect(progress.started, 2);
    expect(progress.completed, 1);
    expect(progress.rainChecks, 1);
  });
}
