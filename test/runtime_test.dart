import 'package:motorix_phase2/motorix_phase2.dart';
import 'package:test/test.dart';

ExerciseRecipe demoRecipe() => ExerciseRecipe.fromJson({
      'schema_version': '1.0',
      'recipe_id': 'demo',
      'exercise_name': 'Knee extension',
      'capture': {'camera_view': 'sagittal_right'},
      'joints': {
        'primary': ['knee_flex_R'],
        'guard': ['trunk_incline']
      },
      'template': {
        'length': 8,
        'knee_flex_R': [10, 20, 50, 75, 75, 50, 20, 10],
        'trunk_incline': [0, 0, 0, 0, 0, 0, 0, 0]
      },
      'tolerance': {
        'knee_flex_R': [5, 5, 5, 5, 5, 5, 5, 5],
        'trunk_incline': [3, 3, 3, 3, 3, 3, 3, 3]
      },
      'timing': {'cycle_sec': 2.0},
      'prescription': {'target_reps': 10, 'progression_factor': 1.0},
      'quality': {
        'validation_status': 'approved',
        'therapist_reviewed': true,
      },
    });

void main() {
  test('legacy and timed prescriptions parse compatibly', () {
    final legacy = demoRecipe();
    expect(legacy.mode, ExerciseMode.repetitions);
    expect(legacy.targetSets, 1);
    expect(legacy.restSeconds, 0);

    final timedJson = Map<String, dynamic>.from({
      'schema_version': '1.0',
      'recipe_id': 'hold',
      'exercise_name': 'Timed hold',
      'capture': {'camera_view': 'frontal'},
      'joints': {
        'primary': ['knee_flex_R'],
        'guard': <String>[]
      },
      'template': {
        'length': 3,
        'knee_flex_R': [10, 70, 10]
      },
      'tolerance': {
        'knee_flex_R': [5, 5, 5]
      },
      'timing': {'cycle_sec': 2},
      'prescription': {
        'mode': 'duration',
        'target_sets': 3,
        'target_duration_sec': 45,
        'rest_sec': 30,
        'progression_factor': 1,
      },
      'quality': {
        'validation_status': 'approved',
        'therapist_reviewed': true,
      },
    });
    final timed = ExerciseRecipe.fromJson(timedJson);
    expect(timed.mode, ExerciseMode.duration);
    expect(timed.targetDurationSeconds, 45);
    expect(timed.targetSets, 3);
    expect(timed.restSeconds, 30);
  });

  test('recipe rejects a mismatched series', () {
    final json = {
      'schema_version': '1.0',
      'recipe_id': 'x',
      'exercise_name': 'x',
      'capture': {'camera_view': 'frontal'},
      'joints': {
        'primary': ['x'],
        'guard': []
      },
      'template': {
        'length': 3,
        'x': [1, 2]
      },
      'tolerance': {
        'x': [1, 1, 1]
      },
      'timing': {'cycle_sec': 2},
      'prescription': {'target_reps': 1, 'progression_factor': 1},
    };
    expect(() => ExerciseRecipe.fromJson(json), throwsFormatException);
  });

  test('FSM counts one complete repetition', () {
    final counter = RepCounter(demoRecipe().template['knee_flex_R']!, 1,
        fps: 30, minimumRepFrames: 3);
    RepEvent? event;
    for (final value in [10.0, 25.0, 55.0, 75.0, 72.0, 45.0, 18.0, 9.0]) {
      event = counter.update(value) ?? event;
    }
    expect(counter.count, 1);
    expect(event?.rep, 1);
  });

  test('FSM counts a movement whose primary value decreases', () {
    final counter = RepCounter([80, 70, 55, 30, 20, 20, 35, 55, 72, 80], 1,
        fps: 30, minimumRepFrames: 3);
    RepEvent? event;
    for (final value in <double>[80, 72, 58, 38, 20, 20, 36, 58, 73, 81]) {
      event = counter.update(value) ?? event;
    }
    expect(counter.count, 1);
    expect(event?.peak, lessThan(30));
  });

  test('head orientation features use the same normalized geometry', () {
    final points = List.generate(33, (_) => const Point2(0, 0));
    points[0] = const Point2(55, 35); // nose
    points[2] = const Point2(42, 30); // left eye
    points[5] = const Point2(62, 30); // right eye
    points[7] = const Point2(35, 32); // left ear
    points[8] = const Point2(70, 38); // right ear
    points[11] = const Point2(35, 80);
    points[12] = const Point2(70, 80);
    points[23] = const Point2(40, 140);
    points[24] = const Point2(65, 140);
    final features = featuresFromPose(PoseFrame(
      landmarks: points,
      visibility: List.filled(33, 1),
      timestamp: Duration.zero,
    ));
    expect(features['head_yaw']!.isFinite, isTrue);
    expect(features['head_pitch']!.isFinite, isTrue);
    expect(features['head_roll']!, greaterThan(0));
  });

  test('signed trunk angle preserves movement direction', () {
    expect(
        angleVertical(const Point2(0, 1), const Point2(.2, 0)), greaterThan(0));
    expect(
        angleVertical(const Point2(0, 1), const Point2(-.2, 0)), lessThan(0));
  });

  test('normalized landmarks are converted with frame aspect ratio', () {
    final frame = PoseFrame.fromNormalized(
      landmarks: List.generate(33, (_) => const Point2(.5, .5)),
      visibility: List.filled(33, 1),
      frameWidth: 1920,
      frameHeight: 1080,
      timestamp: Duration.zero,
    );
    expect(frame.landmarks.first.x, 960);
    expect(frame.landmarks.first.y, 540);
  });

  test('hand features remain available when the body is outside frame', () {
    final frame = PoseFrame(
      landmarks: List.filled(33, const Point2(0, 0)),
      visibility: List.filled(33, 0),
      timestamp: Duration.zero,
      extraFeatures: const {
        'curl_thumb_R': 145,
        'hand_spread_R': 38,
      },
    );
    final features = featuresFromPose(frame);
    expect(features['curl_thumb_R'], 145);
    expect(features['hand_spread_R'], 38);
    expect(features['knee_flex_R']!.isNaN, isTrue);
  });

  test('approved finger recipe is accepted by the patient runtime', () {
    final recipe = ExerciseRecipe.fromJson({
      'schema_version': '1.0',
      'recipe_id': 'finger-demo',
      'exercise_name': 'Genggam jari kanan',
      'capture': {'camera_view': 'close_up'},
      'joints': {
        'primary': ['curl_thumb_R'],
        'guard': ['hand_spread_R']
      },
      'template': {
        'length': 4,
        'curl_thumb_R': [10, 120, 120, 10],
        'hand_spread_R': [50, 25, 25, 50],
      },
      'tolerance': {
        'curl_thumb_R': [15, 15, 15, 15],
        'hand_spread_R': [8, 8, 8, 8],
      },
      'timing': {'cycle_sec': 2.0},
      'prescription': {'target_reps': 8, 'progression_factor': 1.0},
      'quality': {
        'validation_status': 'approved',
        'therapist_reviewed': true,
      },
    });
    expect(recipe.requiresHandTracking, isTrue);
    expect(recipe.primary, ['curl_thumb_R']);
  });

  test('runtime flags persistent guard compensation', () {
    final runtime = PhysioRuntime(demoRecipe());
    FrameFeedback? feedback;
    String? cue;
    for (var i = 0; i < 110; i++) {
      feedback = runtime.update({'knee_flex_R': 10, 'trunk_incline': 20});
      cue ??= feedback.cue;
    }
    expect(feedback!.colors['trunk_incline'], JointColor.red);
    expect(cue, isNotNull);
  });

  test('runtime exposes tempo heat for moving primary joints', () {
    final runtime = PhysioRuntime(demoRecipe());
    var sawTempoHeat = false;
    for (var cycle = 0; cycle < 4; cycle++) {
      for (final knee in <double>[10, 30, 50, 75, 75, 50, 30, 10]) {
        final feedback = runtime.update({
          'knee_flex_R': knee,
          'trunk_incline': 0,
        });
        final color = feedback.tempoColors['knee_flex_R'];
        sawTempoHeat |= color == JointColor.red || color == JointColor.amber;
        expect(feedback.tempoColors['trunk_incline'], JointColor.gray);
      }
    }
    expect(sawTempoHeat, isTrue);
  });

  test('runtime produces a side-specific English movement cue', () {
    final runtime = PhysioRuntime(demoRecipe());
    final cues = <String>[];
    for (var i = 0; i < 150; i++) {
      final feedback = runtime.update({
        'knee_flex_R': 120,
        'trunk_incline': 0,
      });
      if (feedback.cue != null) cues.add(feedback.cue!);
    }
    expect(cues.any((cue) => cue.toLowerCase().contains('right')), isTrue);
  });

  test('recipe guidance can override the spoken hold instruction', () {
    final json = {
      'schema_version': '1.0',
      'recipe_id': 'guided',
      'exercise_name': 'Knee extension',
      'capture': {'camera_view': 'sagittal_right'},
      'joints': {
        'primary': ['knee_flex_R'],
        'guard': ['trunk_incline']
      },
      'template': {
        'length': 8,
        'knee_flex_R': [10, 20, 50, 75, 75, 50, 20, 10],
        'trunk_incline': [0, 0, 0, 0, 0, 0, 0, 0]
      },
      'tolerance': {
        'knee_flex_R': [5, 5, 5, 5, 5, 5, 5, 5],
        'trunk_incline': [3, 3, 3, 3, 3, 3, 3, 3]
      },
      'timing': {'cycle_sec': 2.0},
      'prescription': {'target_reps': 10, 'progression_factor': 1.0},
      'quality': {
        'validation_status': 'approved',
        'therapist_reviewed': true,
      },
      'guidance': {'hold': 'Hold for two more seconds'},
    };
    expect(ExerciseRecipe.fromJson(json).guidance['hold'],
        'Hold for two more seconds');
  });

  test('DTW repetition scorer rewards the template motion', () {
    final recipe = demoRecipe();
    final frames = List.generate(
        recipe.templateLength,
        (index) => {
              for (final joint in recipe.tracked)
                joint: recipe.template[joint]![index],
            });
    final score = scoreRepetition(frames, recipe, recipe.cycleSeconds);
    expect(score.form, closeTo(100, .01));
    expect(score.rom, closeTo(100, .01));
    expect(score.tempo, closeTo(100, .01));
    expect(score.compensation, closeTo(100, .01));
    expect(score.total, closeTo(100, .01));
  });

  test('runtime handles missing and non-finite features without throwing', () {
    final runtime = PhysioRuntime(demoRecipe());
    // Simulate streak accumulation followed by a frame with missing features
    for (var i = 0; i < 20; i++) {
      runtime.update({'knee_flex_R': 120, 'trunk_incline': 20});
    }
    // Now pass missing / NaN features
    expect(
      () => runtime.update({'knee_flex_R': double.nan}),
      returnsNormally,
    );
    expect(
      () => runtime.update({}),
      returnsNormally,
    );
  });

  test('scorer handles frames with missing joints gracefully', () {
    final recipe = demoRecipe();
    final framesWithMissingJoints = [
      {'knee_flex_R': 10.0},
      {'trunk_incline': 0.0},
      <String, double>{},
      {'knee_flex_R': 75.0, 'trunk_incline': 0.0},
      {'knee_flex_R': 10.0},
    ];
    expect(
      () => scoreRepetition(framesWithMissingJoints, recipe, 2.0),
      returnsNormally,
    );
  });
}
