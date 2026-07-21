import 'dart:math';

import '../core/models.dart';
import 'exercise.dart';
import 'exercise_repository.dart';

class ExerciseSelector {
  const ExerciseSelector({required ExerciseCatalog catalog, Random? random})
      : _catalog = catalog;

  final ExerciseCatalog _catalog;

  Future<Exercise> select({
    ExerciseDifficulty difficulty = ExerciseDifficulty.standard,
    ExerciseEnvironment? environment,
    String? previousExerciseId,
    List<String> recentExerciseIds = const [],
  }) async {
    final catalog = await _catalog.load();
    if (catalog.isEmpty) throw StateError('The exercise catalog is empty.');

    final withoutPrevious = catalog
        .where((exercise) => exercise.id != previousExerciseId)
        .toList(growable: false);
    if (withoutPrevious.isEmpty) {
      throw StateError(
        'The exercise catalog cannot avoid repeating $previousExerciseId.',
      );
    }

    final requested = withoutPrevious
        .where((exercise) => exercise.difficulty == difficulty)
        .toList(growable: false);
    final candidates = requested.isNotEmpty
        ? requested
        : _closestDifficulty(withoutPrevious, difficulty);

    final recency = <String, int>{
      for (var index = 0; index < recentExerciseIds.length; index++)
        recentExerciseIds[index]: index,
    };
    return candidates.reduce((best, candidate) {
      final bestRank = recency[best.id];
      final candidateRank = recency[candidate.id];
      if (bestRank == null && candidateRank != null) return best;
      if (candidateRank == null && bestRank != null) return candidate;
      if (bestRank != null && candidateRank != null) {
        return candidateRank > bestRank ? candidate : best;
      }
      return candidate.id.compareTo(best.id) < 0 ? candidate : best;
    });
  }

  Future<Exercise?> findById(String id) async {
    for (final exercise in await _catalog.load()) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  int _difficultyDistance(
    ExerciseDifficulty value,
    ExerciseDifficulty requested,
  ) =>
      (value.index - requested.index).abs();

  List<Exercise> _closestDifficulty(
    List<Exercise> exercises,
    ExerciseDifficulty requested,
  ) {
    final closestDistance = exercises
        .map((exercise) => _difficultyDistance(exercise.difficulty, requested))
        .reduce(min);
    return exercises
        .where(
          (exercise) =>
              _difficultyDistance(exercise.difficulty, requested) ==
              closestDistance,
        )
        .toList(growable: false);
  }
}

typedef ExerciseService = ExerciseSelector;
