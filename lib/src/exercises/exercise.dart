import '../core/models.dart';

enum ExerciseCategory {
  stretch,
  mobility,
  breathing,
  walking,
  strength,
  cardio;

  // Compatibility name for the existing movement-duration insight contract.
  static const movement = mobility;
}

enum ExerciseEnvironment { indoor, outdoor }

enum ExerciseExecutionType { timed, repetitions, hold, sequence }

class Exercise {
  const Exercise({
    required this.id,
    required this.title,
    String? description,
    String? instruction,
    required this.category,
    this.executionType = ExerciseExecutionType.timed,
    this.difficulty = ExerciseDifficulty.standard,
    int? estimatedDuration,
    int? durationMinutes,
    this.requiresStanding = false,
    this.equipmentRequired = false,
    this.sequenceSteps = const [],
    this.restSecondsBetweenRounds,
    bool? availableIndoors,
    bool? availableOutdoors,
  })  : description = description ?? instruction ?? '',
        estimatedDuration = estimatedDuration ?? durationMinutes ?? 1;

  factory Exercise.fromJson(Map<String, Object?> json) {
    final categoryName = _requiredString(json, 'category');
    final difficultyName = _requiredString(json, 'difficulty');
    final executionTypeName = _requiredString(json, 'executionType');
    final duration = json['estimatedDuration'];
    final requiresStanding = json['requiresStanding'];
    final equipmentRequired = json['equipmentRequired'];
    if (duration is! int || duration <= 0) {
      throw const FormatException(
        'estimatedDuration must be a positive integer.',
      );
    }
    if (requiresStanding is! bool || equipmentRequired is! bool) {
      throw const FormatException('Exercise flags must be booleans.');
    }
    final category = ExerciseCategory.values
        .where((value) => value.name == categoryName)
        .firstOrNull;
    final difficulty = ExerciseDifficulty.values
        .where((value) => value.name == difficultyName)
        .firstOrNull;
    final executionType = ExerciseExecutionType.values
        .where((value) => value.name == executionTypeName)
        .firstOrNull;
    if (category == null) {
      throw FormatException('Unknown exercise category: $categoryName.');
    }
    if (difficulty == null) {
      throw FormatException('Unknown exercise difficulty: $difficultyName.');
    }
    if (executionType == null) {
      throw FormatException('Unknown execution type: $executionTypeName.');
    }
    final sequenceSteps = _sequenceSteps(json['sequenceSteps']);
    final restSecondsBetweenRounds = json['restSecondsBetweenRounds'];
    if (executionType == ExerciseExecutionType.sequence &&
        sequenceSteps.isEmpty) {
      throw const FormatException(
        'Sequence exercises must define at least one ordered step.',
      );
    }
    if (executionType != ExerciseExecutionType.sequence &&
        sequenceSteps.isNotEmpty) {
      throw const FormatException(
        'Only sequence exercises may define ordered steps.',
      );
    }
    if (restSecondsBetweenRounds != null &&
        (restSecondsBetweenRounds is! int || restSecondsBetweenRounds <= 0)) {
      throw const FormatException(
        'restSecondsBetweenRounds must be a positive integer.',
      );
    }
    return Exercise(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      category: category,
      difficulty: difficulty,
      executionType: executionType,
      estimatedDuration: duration,
      requiresStanding: requiresStanding,
      equipmentRequired: equipmentRequired,
      sequenceSteps: sequenceSteps,
      restSecondsBetweenRounds: restSecondsBetweenRounds as int?,
    );
  }

  final String id;
  final String title;
  final String description;
  final ExerciseCategory category;
  final ExerciseDifficulty difficulty;
  final ExerciseExecutionType executionType;
  final int estimatedDuration;
  final bool requiresStanding;
  final bool equipmentRequired;
  final List<String> sequenceSteps;
  final int? restSecondsBetweenRounds;

  @Deprecated('Use description.')
  String get instruction => description;

  @Deprecated('Use estimatedDuration.')
  int get durationMinutes => estimatedDuration;

  @Deprecated('Exercise Engine v2 no longer filters by environment.')
  bool get availableIndoors => true;

  @Deprecated('Exercise Engine v2 no longer filters by environment.')
  bool get availableOutdoors => true;

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  static List<String> _sequenceSteps(Object? value) {
    if (value == null) return const [];
    if (value is! List ||
        value.any((step) => step is! String || step.trim().isEmpty)) {
      throw const FormatException(
        'sequenceSteps must contain non-empty strings.',
      );
    }
    return List.unmodifiable(value.cast<String>());
  }
}
