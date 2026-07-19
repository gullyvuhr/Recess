import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/models.dart';

void main() {
  test('work schedule retains minute-of-day boundaries', () {
    const schedule = WorkSchedule(startMinutes: 540, endMinutes: 1020);
    expect(schedule.startMinutes, 9 * 60);
    expect(schedule.endMinutes, 17 * 60);
  });

  test('today progress exposes each outcome separately', () {
    const progress = TodayProgress(started: 2, completed: 1, rainChecks: 1);
    expect(progress.started, 2);
    expect(progress.completed, 1);
    expect(progress.rainChecks, 1);
  });
}
