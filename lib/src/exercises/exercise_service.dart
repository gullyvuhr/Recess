import 'dart:math';

import 'exercise.dart';
import 'exercise_repository.dart';

class ExerciseService {
  ExerciseService({required ExerciseCatalog catalog, Random? random})
      : _catalog = catalog,
        _random = random ?? Random();

  final ExerciseCatalog _catalog;
  final Random _random;

  Future<Exercise> select({
    required ExerciseEnvironment environment,
    String? previousExerciseId,
  }) async {
    final available = (await _catalog.load())
        .where((exercise) => exercise.isAvailableIn(environment))
        .toList(growable: false);
    if (available.isEmpty) {
      throw StateError('No exercises are available for ${environment.name}.');
    }
    final choices = available.length > 1 && previousExerciseId != null
        ? available
            .where((exercise) => exercise.id != previousExerciseId)
            .toList(growable: false)
        : available;
    return choices[_random.nextInt(choices.length)];
  }

  Future<Exercise?> findById(String id) async {
    for (final exercise in await _catalog.load()) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }
}
