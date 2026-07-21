import 'package:flutter_test/flutter_test.dart';
import 'package:recess/src/core/models.dart';
import 'package:recess/src/exercises/exercise.dart';
import 'package:recess/src/exercises/exercise_prescription_service.dart';

void main() {
  const service = ExercisePrescriptionService();

  test('timed walking scales to the configured session duration', () {
    for (final minutes in RecessPreferences.supportedDurations) {
      expect(
        service.generate(_walking, minutes),
        'Walk for $minutes minutes.',
      );
    }
  });

  test('repetition prescription scales sets and rest deterministically', () {
    expect(
      service.generate(_squats, 3),
      '2 sets of 10 air squats.\nRest 30 seconds between sets.',
    );
    expect(
      service.generate(_squats, 5),
      '3 sets of 10 air squats.\nRest 30 seconds between sets.',
    );
    expect(
      service.generate(_squats, 10),
      '5 sets of 10 air squats.\nRest 45 seconds between sets.',
    );
    expect(
      service.generate(_squats, 15),
      '7 sets of 10 air squats.\nRest 45 seconds between sets.',
    );
  });

  test('hold prescription scales hold and repeat counts deterministically', () {
    expect(
        service.generate(_plank, 3), 'Hold for 20 seconds.\nRepeat 3 times.');
    expect(
        service.generate(_plank, 5), 'Hold for 30 seconds.\nRepeat 4 times.');
    expect(
        service.generate(_plank, 10), 'Hold for 45 seconds.\nRepeat 5 times.');
    expect(
        service.generate(_plank, 15), 'Hold for 60 seconds.\nRepeat 5 times.');
  });

  test('mobility sequence renders ordered steps and scales rounds', () {
    const steps = '- 10 arm circles\n'
        '- 10 torso rotations\n'
        '- 8 alternating reverse lunges\n'
        '- 10 hip hinges';

    expect(service.generate(_mobilityFlow, 3), '$steps\n\nComplete 2 rounds.');
    expect(service.generate(_mobilityFlow, 5), '$steps\n\nComplete 3 rounds.');
    expect(service.generate(_mobilityFlow, 10), '$steps\n\nComplete 5 rounds.');
    expect(service.generate(_mobilityFlow, 15), '$steps\n\nComplete 7 rounds.');
  });

  test('circuit sequence scales rounds and includes prescribed rest', () {
    const steps = '- 10 air squats\n'
        '- 8 desk pushups\n'
        '- 10 alternating reverse lunges\n'
        '- 20-second incline plank';

    expect(
      service.generate(_circuit, 3),
      '$steps\n\nComplete 1 round.\nRest 30 seconds between rounds.',
    );
    expect(service.generate(_circuit, 5), contains('Complete 2 rounds.'));
    expect(service.generate(_circuit, 10), contains('Complete 4 rounds.'));
    expect(service.generate(_circuit, 15), contains('Complete 6 rounds.'));
  });
}

const _walking = Exercise(
  id: 'five-minute-walk',
  title: 'Walking',
  description: 'Walk at a comfortable pace.',
  category: ExerciseCategory.walking,
  difficulty: ExerciseDifficulty.standard,
  executionType: ExerciseExecutionType.timed,
  estimatedDuration: 5,
  requiresStanding: true,
);

const _squats = Exercise(
  id: 'squats',
  title: 'Air Squats',
  description: 'Complete controlled squats.',
  category: ExerciseCategory.strength,
  difficulty: ExerciseDifficulty.standard,
  executionType: ExerciseExecutionType.repetitions,
  estimatedDuration: 5,
  requiresStanding: true,
);

const _plank = Exercise(
  id: 'plank',
  title: 'Plank',
  description: 'Keep a steady plank position.',
  category: ExerciseCategory.strength,
  difficulty: ExerciseDifficulty.challenging,
  executionType: ExerciseExecutionType.hold,
  estimatedDuration: 5,
);

const _mobilityFlow = Exercise(
  id: 'dynamic-mobility-flow',
  title: 'Dynamic Mobility Flow',
  description: 'Complete each movement in order.',
  category: ExerciseCategory.mobility,
  difficulty: ExerciseDifficulty.challenging,
  executionType: ExerciseExecutionType.sequence,
  estimatedDuration: 10,
  sequenceSteps: [
    '10 arm circles',
    '10 torso rotations',
    '8 alternating reverse lunges',
    '10 hip hinges',
  ],
);

const _circuit = Exercise(
  id: 'bodyweight-circuit',
  title: 'Bodyweight Circuit',
  description: 'Complete each movement in order.',
  category: ExerciseCategory.strength,
  difficulty: ExerciseDifficulty.challenging,
  executionType: ExerciseExecutionType.sequence,
  estimatedDuration: 10,
  sequenceSteps: [
    '10 air squats',
    '8 desk pushups',
    '10 alternating reverse lunges',
    '20-second incline plank',
  ],
  restSecondsBetweenRounds: 30,
);
