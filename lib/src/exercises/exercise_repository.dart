import 'dart:convert';

import 'package:flutter/services.dart';

import 'exercise.dart';

abstract interface class ExerciseCatalog {
  Future<List<Exercise>> load();
}

class AssetExerciseRepository implements ExerciseCatalog {
  AssetExerciseRepository({
    AssetBundle? bundle,
    this.assetPath = 'assets/exercises.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;
  Future<List<Exercise>>? _catalog;

  @override
  Future<List<Exercise>> load() => _catalog ??= _loadAndValidate();

  Future<List<Exercise>> _loadAndValidate() async {
    final decoded = jsonDecode(await _bundle.loadString(assetPath));
    if (decoded is! List) {
      throw const FormatException('Exercise catalog must be a JSON list.');
    }
    final exercises = decoded.map((entry) {
      if (entry is! Map<String, Object?>) {
        throw const FormatException('Each exercise must be a JSON object.');
      }
      return Exercise.fromJson(entry);
    }).toList(growable: false);
    if (exercises.isEmpty) {
      throw const FormatException('Exercise catalog cannot be empty.');
    }
    final ids = <String>{};
    for (final exercise in exercises) {
      if (!ids.add(exercise.id)) {
        throw FormatException('Duplicate exercise id: ${exercise.id}.');
      }
    }
    return List.unmodifiable(exercises);
  }
}
