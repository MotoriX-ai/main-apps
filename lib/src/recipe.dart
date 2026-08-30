class ExerciseRecipe {
  ExerciseRecipe({
    required this.schemaVersion,
    required this.recipeId,
    required this.exerciseName,
    required this.cameraView,
    required this.primary,
    required this.guard,
    required this.templateLength,
    required this.template,
    required this.tolerance,
    required this.cycleSeconds,
    required this.targetReps,
    required this.progressionFactor,
    this.mode = ExerciseMode.repetitions,
    this.targetSets = 1,
    this.targetDurationSeconds,
    this.restSeconds = 0,
    this.phaseAnchors = const {},
    this.directions = const {},
    this.guidance = const {},
  });

  final String schemaVersion;
  final String recipeId;
  final String exerciseName;
  final String cameraView;
  final List<String> primary;
  final List<String> guard;
  final int templateLength;
  final Map<String, List<double>> template;
  final Map<String, List<double>> tolerance;
  final double cycleSeconds;
  final int targetReps;
  final double progressionFactor;
  final ExerciseMode mode;
  final int targetSets;
  final int? targetDurationSeconds;
  final double restSeconds;
  final Map<String, double> phaseAnchors;
  final Map<String, String> directions;
  final Map<String, String> guidance;

  List<String> get tracked => {...primary, ...guard}.toList(growable: false);

  String? get cue => guidance['cue'];
  String? get caution => guidance['caution'];

  bool get requiresHandTracking => tracked.any((name) =>
      name.startsWith('curl_') ||
      name.startsWith('hand_spread_') ||
      name.startsWith('wrist_flex_'));

  factory ExerciseRecipe.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != '1.0') {
      throw const FormatException('Schema recipe yang didukung hanya 1.0');
    }
    final joints = json['joints'] as Map<String, dynamic>;
    final templateJson = json['template'] as Map<String, dynamic>;
    final toleranceJson = json['tolerance'] as Map<String, dynamic>;
    final primary = List<String>.from(joints['primary'] as List);
    final guard = List<String>.from(joints['guard'] as List);
    const supportedPoseFeatures = {
      'knee_flex_L',
      'knee_flex_R',
      'hip_flex_L',
      'hip_flex_R',
      'ankle_dorsi_L',
      'ankle_dorsi_R',
      'shoulder_elev_L',
      'shoulder_elev_R',
      'elbow_flex_L',
      'elbow_flex_R',
      'trunk_incline',
      'head_yaw',
      'head_pitch',
      'head_roll',
      'shoulder_hike_L',
      'shoulder_hike_R',
      'stance_width',
      'view_ratio',
      'pelvis_shift',
      'wrist_flex_L',
      'wrist_flex_R',
      'curl_thumb_L',
      'curl_thumb_R',
      'curl_index_L',
      'curl_index_R',
      'curl_middle_L',
      'curl_middle_R',
      'curl_ring_L',
      'curl_ring_R',
      'curl_pinky_L',
      'curl_pinky_R',
      'hand_spread_L',
      'hand_spread_R',
    };
    final unsupported =
        {...primary, ...guard}.difference(supportedPoseFeatures);
    if (unsupported.isNotEmpty) {
      throw FormatException(
        'Recipe membutuhkan fitur yang belum didukung runtime pose: ${unsupported.join(', ')}',
      );
    }
    final quality = json['quality'] as Map<String, dynamic>?;
    if (quality == null ||
        quality['validation_status'] != 'approved' ||
        quality['therapist_reviewed'] != true) {
      throw const FormatException(
        'Recipe pasien harus approved dan sudah direview dokter',
      );
    }
    final length = (templateJson['length'] as num).toInt();

    List<double> series(Map<String, dynamic> source, String key) {
      final values =
          (source[key] as List?)?.map((v) => (v as num).toDouble()).toList();
      if (values == null || values.length != length) {
        throw FormatException('Series $key harus memiliki $length nilai');
      }
      if (values.any((value) => !value.isFinite)) {
        throw FormatException('Series $key mengandung nilai non-finite');
      }
      return List.unmodifiable(values);
    }

    final tracked = {...primary, ...guard};
    final template = {
      for (final key in tracked) key: series(templateJson, key)
    };
    final tolerance = {
      for (final key in tracked) key: series(toleranceJson, key)
    };
    if (primary.isEmpty) {
      throw const FormatException('Recipe membutuhkan primary joint');
    }

    final prescription = json['prescription'] as Map<String, dynamic>;
    final mode = prescription['mode'] == 'duration'
        ? ExerciseMode.duration
        : ExerciseMode.repetitions;
    final targetReps = (prescription['target_reps'] as num?)?.toInt() ?? 1;
    final targetDurationSeconds =
        (prescription['target_duration_sec'] as num?)?.toInt();
    if (mode == ExerciseMode.duration && targetDurationSeconds == null) {
      throw const FormatException(
          'Recipe durasi membutuhkan target_duration_sec');
    }
    return ExerciseRecipe(
      schemaVersion: '1.0',
      recipeId: json['recipe_id'] as String,
      exerciseName: json['exercise_name'] as String,
      cameraView:
          (json['capture'] as Map<String, dynamic>)['camera_view'] as String,
      primary: List.unmodifiable(primary),
      guard: List.unmodifiable(guard),
      templateLength: length,
      template: Map.unmodifiable(template),
      tolerance: Map.unmodifiable(tolerance),
      cycleSeconds:
          ((json['timing'] as Map<String, dynamic>)['cycle_sec'] as num)
              .toDouble(),
      targetReps: targetReps,
      progressionFactor: (prescription['progression_factor'] as num).toDouble(),
      mode: mode,
      targetSets: (prescription['target_sets'] as num?)?.toInt() ?? 1,
      targetDurationSeconds: targetDurationSeconds,
      restSeconds: (prescription['rest_sec'] as num?)?.toDouble() ?? 0,
      phaseAnchors: Map.unmodifiable(
        (((json['timing'] as Map<String, dynamic>)['phase_anchors']
                    as Map<String, dynamic>?) ??
                const {})
            .map((key, value) => MapEntry(key, (value as num).toDouble())),
      ),
      directions: Map.unmodifiable(
        (((json['timing'] as Map<String, dynamic>)['direction']
                    as Map<String, dynamic>?) ??
                const {})
            .map((key, value) => MapEntry(key, value.toString())),
      ),
      guidance: Map.unmodifiable(
        ((json['guidance'] as Map<String, dynamic>?) ?? const {})
            .map((key, value) => MapEntry(key, value.toString())),
      ),
    );
  }
}

enum ExerciseMode { repetitions, duration }
