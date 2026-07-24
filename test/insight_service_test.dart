import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/database.dart';
import 'package:recess/src/core/insights.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/exercises/exercise.dart';
import 'package:recess/src/exercises/exercise_repository.dart';

void main() {
  test('loads facts through the database date-range boundary', () async {
    final database = RecessDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.saveSchedule(
      const WorkSchedule(
        startMinutes: 9 * 60,
        endMinutes: 12 * 60,
        cadenceMinutes: 60,
      ),
    );
    final session = await database.createSession(
      scheduledAt: DateTime(2026, 7, 20, 10),
      createdAt: DateTime(2026, 7, 20, 9),
    );
    await database.startSession(
      session.id,
      DateTime(2026, 7, 20, 10, 5),
      'move',
    );
    await database.completeSession(
      session.id,
      DateTime(2026, 7, 20, 10, 15),
    );
    final service = InsightService(
      database: database,
      exercises: const _StaticCatalog(),
    );

    final summary = await service.load(DateTime(2026, 7, 20, 18));

    expect(summary.today.completed, 1);
    expect(
        summary.today.completedMovementDuration, const Duration(minutes: 10));
    expect(summary.sevenDays.scheduled, 1);
    expect(
      summary.observations
          .singleWhere(
            (value) => value.type == InsightObservationType.weeklyCompletion,
          )
          .description,
      'You completed 1 of 14 scheduled Recesses this week.',
    );
  });
}

class _StaticCatalog implements ExerciseCatalog {
  const _StaticCatalog();

  @override
  Future<List<Exercise>> load() async => const [
        Exercise(
          id: 'move',
          title: 'Move',
          instruction: 'Move.',
          durationMinutes: 5,
          category: ExerciseCategory.movement,
          availableIndoors: true,
          availableOutdoors: true,
        ),
      ];
}
