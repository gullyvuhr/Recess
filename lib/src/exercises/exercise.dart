enum ExerciseCategory { movement, breathing, mindfulness, stretch }

enum ExerciseEnvironment { indoor, outdoor }

class Exercise {
  const Exercise({
    required this.id,
    required this.title,
    required this.instruction,
    required this.durationMinutes,
    required this.category,
    required this.availableIndoors,
    required this.availableOutdoors,
  });

  factory Exercise.fromJson(Map<String, Object?> json) {
    final id = _requiredString(json, 'id');
    final title = _requiredString(json, 'title');
    final instruction = _requiredString(json, 'instruction');
    final duration = json['durationMinutes'];
    final categoryName = _requiredString(json, 'category');
    final indoors = json['availableIndoors'];
    final outdoors = json['availableOutdoors'];

    if (duration is! int || duration <= 0) {
      throw const FormatException(
          'durationMinutes must be a positive integer.');
    }
    final category = ExerciseCategory.values
        .where((value) => value.name == categoryName)
        .firstOrNull;
    if (category == null) {
      throw FormatException('Unknown exercise category: $categoryName.');
    }
    if (indoors is! bool || outdoors is! bool) {
      throw const FormatException(
        'Exercise availability values must be booleans.',
      );
    }
    if (!indoors && !outdoors) {
      throw const FormatException(
        'An exercise must be available indoors or outdoors.',
      );
    }
    return Exercise(
      id: id,
      title: title,
      instruction: instruction,
      durationMinutes: duration,
      category: category,
      availableIndoors: indoors,
      availableOutdoors: outdoors,
    );
  }

  final String id;
  final String title;
  final String instruction;
  final int durationMinutes;
  final ExerciseCategory category;
  final bool availableIndoors;
  final bool availableOutdoors;

  bool isAvailableIn(ExerciseEnvironment environment) => switch (environment) {
        ExerciseEnvironment.indoor => availableIndoors,
        ExerciseEnvironment.outdoor => availableOutdoors,
      };

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }
}
