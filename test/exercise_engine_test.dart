import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/exercises/exercise.dart';
import 'package:recess/src/exercises/exercise_repository.dart';
import 'package:recess/src/exercises/exercise_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('launch catalog contains the scoped local exercise library', () async {
    final exercises = await AssetExerciseRepository().load();

    expect(exercises.length, inInclusiveRange(15, 20));
    expect(
      exercises.map((exercise) => exercise.category).toSet(),
      ExerciseCategory.values.toSet(),
    );
  });

  test('repository parses and validates exercise JSON', () async {
    final repository = AssetExerciseRepository(
      bundle: StringAssetBundle(_validCatalogJson),
    );

    final exercises = await repository.load();

    expect(exercises, hasLength(2));
    expect(exercises.first.id, 'indoor-move');
    expect(exercises.first.category, ExerciseCategory.movement);
    expect(exercises.first.durationMinutes, 2);
    expect(exercises.first.availableIndoors, isTrue);
    expect(exercises.first.availableOutdoors, isFalse);
  });

  test('repository rejects duplicate exercise IDs', () async {
    final repository = AssetExerciseRepository(
      bundle: StringAssetBundle('[$_exerciseJson,$_exerciseJson]'),
    );

    await expectLater(repository.load(), throwsFormatException);
  });

  test('repository rejects malformed JSON and missing exercise IDs', () async {
    final malformed = AssetExerciseRepository(
      bundle: StringAssetBundle('{not-json'),
    );
    final missingId = AssetExerciseRepository(
      bundle: StringAssetBundle('''
        [{
          "title": "Missing ID",
          "instruction": "This entry has no ID.",
          "durationMinutes": 2,
          "category": "mindfulness",
          "availableIndoors": true,
          "availableOutdoors": true
        }]
      '''),
    );

    await expectLater(malformed.load(), throwsFormatException);
    await expectLater(missingId.load(), throwsFormatException);
  });

  test('service randomly selects from the available catalog', () async {
    final service = ExerciseService(
      catalog: StaticExerciseCatalog(_exercises),
      random: PredictableRandom(1),
    );

    final selected = await service.select(
      environment: ExerciseEnvironment.outdoor,
    );

    expect(selected.id, 'outdoor-breath');
  });

  test('service prevents an immediate repeat when alternatives exist',
      () async {
    final service = ExerciseService(
      catalog: StaticExerciseCatalog(_exercises),
      random: PredictableRandom(0),
    );

    final selected = await service.select(
      environment: ExerciseEnvironment.outdoor,
      previousExerciseId: 'indoor-move',
    );

    expect(selected.id, 'outdoor-breath');
  });

  test('repeat prevention keeps uniform access to remaining choices', () async {
    const catalog = StaticExerciseCatalog([
      ..._exercises,
      Exercise(
        id: 'outdoor-stretch',
        title: 'Outdoor Stretch',
        instruction: 'Stretch outside.',
        durationMinutes: 2,
        category: ExerciseCategory.stretch,
        availableIndoors: false,
        availableOutdoors: true,
      ),
    ]);
    final firstChoice = ExerciseService(
      catalog: catalog,
      random: PredictableRandom(0),
    );
    final secondChoice = ExerciseService(
      catalog: catalog,
      random: PredictableRandom(1),
    );

    final selected = await Future.wait([
      firstChoice.select(
        environment: ExerciseEnvironment.outdoor,
        previousExerciseId: 'indoor-move',
      ),
      secondChoice.select(
        environment: ExerciseEnvironment.outdoor,
        previousExerciseId: 'indoor-move',
      ),
    ]);

    expect(
      selected.map((exercise) => exercise.id).toSet(),
      {'outdoor-breath', 'outdoor-stretch'},
    );
  });

  test('indoor selection excludes outdoor-only exercises', () async {
    final service = ExerciseService(
      catalog: StaticExerciseCatalog(_exercises),
      random: PredictableRandom(0),
    );

    final selected = await service.select(
      environment: ExerciseEnvironment.indoor,
    );

    expect(selected.id, 'indoor-move');
    expect(selected.availableIndoors, isTrue);
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

class PredictableRandom implements Random {
  PredictableRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => value % max;
}

const _exercises = [
  Exercise(
    id: 'indoor-move',
    title: 'Indoor Move',
    instruction: 'Move gently.',
    durationMinutes: 2,
    category: ExerciseCategory.movement,
    availableIndoors: true,
    availableOutdoors: true,
  ),
  Exercise(
    id: 'outdoor-breath',
    title: 'Outdoor Breath',
    instruction: 'Breathe outside.',
    durationMinutes: 3,
    category: ExerciseCategory.breathing,
    availableIndoors: false,
    availableOutdoors: true,
  ),
];

const _exerciseJson = '''
{
  "id": "indoor-move",
  "title": "Indoor Move",
  "instruction": "Move gently.",
  "durationMinutes": 2,
  "category": "movement",
  "availableIndoors": true,
  "availableOutdoors": false
}
''';

const _validCatalogJson = '[$_exerciseJson,${'''
{
  "id": "outdoor-breath",
  "title": "Outdoor Breath",
  "instruction": "Breathe outside.",
  "durationMinutes": 3,
  "category": "breathing",
  "availableIndoors": false,
  "availableOutdoors": true
}
'''}]';
