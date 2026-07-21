import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/exercises/exercise.dart';
import 'package:recess/src/exercises/exercise_repository.dart';
import 'package:recess/src/exercises/exercise_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('curated library contains ten exercises per difficulty', () async {
    final exercises = await AssetExerciseRepository().load();

    expect(exercises, hasLength(30));
    for (final difficulty in ExerciseDifficulty.values) {
      expect(
        exercises.where((exercise) => exercise.difficulty == difficulty),
        hasLength(10),
      );
    }
    expect(
      exercises.map((exercise) => exercise.category).toSet(),
      ExerciseCategory.values.toSet(),
    );
    expect(
      exercises.map((exercise) => exercise.executionType).toSet(),
      ExerciseExecutionType.values.toSet(),
    );
    expect(
        exercises.every((exercise) => exercise.description.isNotEmpty), isTrue);
    expect(
        exercises.every((exercise) => exercise.estimatedDuration > 0), isTrue);
    expect(
      exercises
          .where(
            (exercise) =>
                exercise.executionType == ExerciseExecutionType.sequence,
          )
          .every((exercise) => exercise.sequenceSteps.isNotEmpty),
      isTrue,
    );
  });

  test('repository parses the complete metadata model', () async {
    final repository = AssetExerciseRepository(
      bundle: StringAssetBundle('[$_easyJson]'),
    );

    final exercise = (await repository.load()).single;

    expect(exercise.id, 'easy-stretch');
    expect(exercise.description, 'Reach gently.');
    expect(exercise.category, ExerciseCategory.stretch);
    expect(exercise.difficulty, ExerciseDifficulty.easy);
    expect(exercise.executionType, ExerciseExecutionType.hold);
    expect(exercise.estimatedDuration, 3);
    expect(exercise.requiresStanding, isTrue);
    expect(exercise.equipmentRequired, isFalse);
  });

  test('repository rejects duplicate IDs and malformed metadata', () async {
    final duplicate = AssetExerciseRepository(
      bundle: StringAssetBundle('[$_easyJson,$_easyJson]'),
    );
    final missingDifficulty = AssetExerciseRepository(
      bundle: StringAssetBundle('''
        [{
          "id": "missing-difficulty",
          "title": "Missing Difficulty",
          "description": "Move gently.",
          "category": "mobility",
          "estimatedDuration": 3,
          "requiresStanding": false,
          "equipmentRequired": false
        }]
      '''),
    );

    await expectLater(duplicate.load(), throwsFormatException);
    await expectLater(missingDifficulty.load(), throwsFormatException);
  });

  test('repository rejects a sequence without ordered steps', () async {
    final repository = AssetExerciseRepository(
      bundle: StringAssetBundle('''
        [{
          "id": "empty-sequence",
          "title": "Empty Sequence",
          "description": "Complete each step in order.",
          "category": "mobility",
          "executionType": "sequence",
          "difficulty": "standard",
          "estimatedDuration": 5,
          "requiresStanding": true,
          "equipmentRequired": false,
          "sequenceSteps": []
        }]
      '''),
    );

    await expectLater(repository.load(), throwsFormatException);
  });

  test('selector filters to the requested difficulty', () async {
    final selector = ExerciseSelector(catalog: _catalog);

    final easy = await selector.select(difficulty: ExerciseDifficulty.easy);
    final standard =
        await selector.select(difficulty: ExerciseDifficulty.standard);
    final challenging =
        await selector.select(difficulty: ExerciseDifficulty.challenging);

    expect(easy.difficulty, ExerciseDifficulty.easy);
    expect(standard.difficulty, ExerciseDifficulty.standard);
    expect(challenging.difficulty, ExerciseDifficulty.challenging);
  });

  test('selector never repeats the immediately previous exercise', () async {
    final selector = ExerciseSelector(catalog: _catalog);

    final selected = await selector.select(
      difficulty: ExerciseDifficulty.easy,
      previousExerciseId: 'easy-a',
      recentExerciseIds: const ['easy-a'],
    );

    expect(selected.id, isNot('easy-a'));
    expect(selected.id, 'easy-b');
  });

  test('selector strongly prefers exercises outside recent history', () async {
    final selector = ExerciseSelector(catalog: _catalog);

    final selected = await selector.select(
      difficulty: ExerciseDifficulty.easy,
      recentExerciseIds: const ['easy-a', 'easy-b'],
    );

    expect(selected.id, 'easy-c');
  });

  test('selector chooses the least recent option when all were used', () async {
    final selector = ExerciseSelector(catalog: _catalog);

    final selected = await selector.select(
      difficulty: ExerciseDifficulty.easy,
      recentExerciseIds: const ['easy-c', 'easy-a', 'easy-b'],
    );

    expect(selected.id, 'easy-b');
  });

  test('selector falls back to the closest tier without repeating', () async {
    const sparse = StaticExerciseCatalog([
      Exercise(
        id: 'only-easy',
        title: 'Only Easy',
        description: 'Move easily.',
        category: ExerciseCategory.mobility,
        difficulty: ExerciseDifficulty.easy,
        estimatedDuration: 3,
        requiresStanding: false,
        equipmentRequired: false,
      ),
      Exercise(
        id: 'standard-option',
        title: 'Standard Option',
        description: 'Move steadily.',
        category: ExerciseCategory.mobility,
        difficulty: ExerciseDifficulty.standard,
        estimatedDuration: 5,
        requiresStanding: true,
        equipmentRequired: false,
      ),
    ]);
    final selector = ExerciseSelector(catalog: sparse);

    final selected = await selector.select(
      difficulty: ExerciseDifficulty.easy,
      previousExerciseId: 'only-easy',
    );

    expect(selected.id, 'standard-option');
  });

  test('identical inputs always produce identical selection', () async {
    final selector = ExerciseSelector(catalog: _catalog);

    final first = await selector.select(
      difficulty: ExerciseDifficulty.standard,
      recentExerciseIds: const ['standard-a'],
    );
    final second = await selector.select(
      difficulty: ExerciseDifficulty.standard,
      recentExerciseIds: const ['standard-a'],
    );

    expect(second.id, first.id);
  });
}

class StringAssetBundle extends CachingAssetBundle {
  StringAssetBundle(this.value);

  final String value;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }
}

class StaticExerciseCatalog implements ExerciseCatalog {
  const StaticExerciseCatalog(this.exercises);

  final List<Exercise> exercises;

  @override
  Future<List<Exercise>> load() async => exercises;
}

const _catalog = StaticExerciseCatalog([
  Exercise(
    id: 'easy-a',
    title: 'Easy A',
    description: 'Easy movement A.',
    category: ExerciseCategory.mobility,
    difficulty: ExerciseDifficulty.easy,
    estimatedDuration: 3,
    requiresStanding: false,
    equipmentRequired: false,
  ),
  Exercise(
    id: 'easy-b',
    title: 'Easy B',
    description: 'Easy movement B.',
    category: ExerciseCategory.stretch,
    difficulty: ExerciseDifficulty.easy,
    estimatedDuration: 3,
    requiresStanding: false,
    equipmentRequired: false,
  ),
  Exercise(
    id: 'easy-c',
    title: 'Easy C',
    description: 'Easy movement C.',
    category: ExerciseCategory.breathing,
    difficulty: ExerciseDifficulty.easy,
    estimatedDuration: 3,
    requiresStanding: false,
    equipmentRequired: false,
  ),
  Exercise(
    id: 'standard-a',
    title: 'Standard A',
    description: 'Standard movement.',
    category: ExerciseCategory.walking,
    difficulty: ExerciseDifficulty.standard,
    estimatedDuration: 5,
    requiresStanding: true,
    equipmentRequired: false,
  ),
  Exercise(
    id: 'challenging-a',
    title: 'Challenging A',
    description: 'Challenging movement.',
    category: ExerciseCategory.cardio,
    difficulty: ExerciseDifficulty.challenging,
    estimatedDuration: 5,
    requiresStanding: true,
    equipmentRequired: false,
  ),
]);

const _easyJson = '''
{
  "id": "easy-stretch",
  "title": "Easy Stretch",
  "description": "Reach gently.",
  "category": "stretch",
  "executionType": "hold",
  "difficulty": "easy",
  "estimatedDuration": 3,
  "requiresStanding": true,
  "equipmentRequired": false
}
''';
