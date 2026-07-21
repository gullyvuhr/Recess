import 'exercise.dart';

class ExercisePrescriptionService {
  const ExercisePrescriptionService();

  String generate(Exercise exercise, int sessionDurationMinutes) {
    return switch (exercise.executionType) {
      ExerciseExecutionType.timed => _timed(exercise, sessionDurationMinutes),
      ExerciseExecutionType.repetitions =>
        _repetitions(exercise, sessionDurationMinutes),
      ExerciseExecutionType.hold => _hold(exercise, sessionDurationMinutes),
      ExerciseExecutionType.sequence =>
        _sequence(exercise, sessionDurationMinutes),
    };
  }

  String _timed(Exercise exercise, int minutes) {
    final duration = '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    return switch (exercise.id) {
      'deep-breathing' => 'Take slow, comfortable breaths for $duration.',
      'box-breathing' =>
        'Inhale, pause, exhale, and pause for a count of four.\nRepeat for $duration.',
      'eye-break' => 'Focus on something at least 20 feet away for $duration.',
      'five-minute-walk' => 'Walk for $duration.',
      'hip-mobility' =>
        'Make slow hip circles for $duration, changing direction halfway.',
      'march-in-place' =>
        'March in place for $duration, letting your arms swing naturally.',
      'fast-stair-climb' =>
        'Alternate 30 seconds of brisk marching with 30 seconds of gentle marching for $duration.',
      _ => '${exercise.description}\nContinue for $duration.',
    };
  }

  String _repetitions(Exercise exercise, int minutes) {
    final (sets, restSeconds) = switch (minutes) {
      3 => (2, 30),
      5 => (3, 30),
      10 => (5, 45),
      15 => (7, 45),
      _ => _unsupportedDuration(minutes),
    };
    return '$sets sets of 10 ${exercise.title.toLowerCase()}.\n'
        'Rest $restSeconds seconds between sets.';
  }

  String _hold(Exercise exercise, int minutes) {
    final (holdSeconds, repetitions) = switch (minutes) {
      3 => (20, 3),
      5 => (30, 4),
      10 => (45, 5),
      15 => (60, 5),
      _ => _unsupportedDuration(minutes),
    };
    final perSide = _usesBothSides(exercise) ? ' per side' : '';
    return 'Hold for $holdSeconds seconds$perSide.\n'
        'Repeat $repetitions times.';
  }

  String _sequence(Exercise exercise, int minutes) {
    final rounds = exercise.restSecondsBetweenRounds == null
        ? switch (minutes) {
            3 => 2,
            5 => 3,
            10 => 5,
            15 => 7,
            _ => _unsupportedDuration(minutes),
          }
        : switch (minutes) {
            3 => 1,
            5 => 2,
            10 => 4,
            15 => 6,
            _ => _unsupportedDuration(minutes),
          };
    final steps = exercise.sequenceSteps.map((step) => '- $step').join('\n');
    final rest = exercise.restSecondsBetweenRounds == null
        ? ''
        : '\nRest ${exercise.restSecondsBetweenRounds} seconds between rounds.';
    return '$steps\n\nComplete $rounds ${rounds == 1 ? 'round' : 'rounds'}.$rest';
  }

  bool _usesBothSides(Exercise exercise) {
    final description = exercise.description.toLowerCase();
    return description.contains('switch') ||
        description.contains('each side') ||
        description.contains('other side');
  }

  Never _unsupportedDuration(int minutes) => throw ArgumentError.value(
        minutes,
        'sessionDurationMinutes',
        'Use a supported Recess duration.',
      );
}
