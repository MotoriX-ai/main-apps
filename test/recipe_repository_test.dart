import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motorix_phase2/app/features/home/services/recipe_repository.dart';
import 'package:test/test.dart';

void main() {
  test('patient code rejects an invalid length before network access', () {
    final repository = RecipeRepository();
    addTearDown(repository.dispose);
    expect(repository.loadByCode('123'), throwsFormatException);
    expect(repository.loadByCode('MX-123'), throwsFormatException);
    expect(repository.loadByCode('1234567890'), throwsFormatException);
  });

  test('patient code downloads published recipe correctly with mock client',
      () async {
    final sampleRecipeJson = {
      'schema_version': '1.0',
      'recipe_id': 'knee_ext_01',
      'exercise_name': 'Ekstensi Lutut Duduk',
      'joints': {
        'primary': ['knee_flex_R'],
        'guard': ['trunk_incline'],
      },
      'template': {
        'length': 3,
        'knee_flex_R': [90.0, 135.0, 180.0],
        'trunk_incline': [0.0, 2.0, 0.0],
      },
      'tolerance': {
        'knee_flex_R': [10.0, 10.0, 10.0],
        'trunk_incline': [5.0, 5.0, 5.0],
      },
      'timing': {
        'cycle_sec': 3.5,
        'direction': {'knee_flex_R': 'increasing'},
        'phase_anchors': {'inflection': 0.5},
      },
      'prescription': {
        'target_reps': 10,
        'progression_factor': 1.0,
      },
      'capture': {
        'camera_view': 'sagittal_right',
        'movement_focus': 'knee',
        'movement_side': 'right',
      },
      'quality': {
        'validation_status': 'approved',
        'therapist_reviewed': true,
      },
    };

    final mockClient = MockClient((request) async {
      if (request.url.path == '/v1/recipes/code/MX-E44D3752') {
        return http.Response(
          jsonEncode(sampleRecipeJson),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final repository = RecipeRepository(client: mockClient);
    addTearDown(repository.dispose);

    // Test with "E44D3752"
    final recipe1 = await repository.loadByCode('E44D3752');
    expect(recipe1.exerciseName, 'Ekstensi Lutut Duduk');
    expect(recipe1.targetReps, 10);

    // Test with "MX-E44D3752"
    final recipe2 = await repository.loadByCode('MX-E44D3752');
    expect(recipe2.exerciseName, 'Ekstensi Lutut Duduk');

    // Test with lowercase "mx-e44d3752"
    final recipe3 = await repository.loadByCode('mx-e44d3752');
    expect(recipe3.exerciseName, 'Ekstensi Lutut Duduk');

    // Test with 404 non-existent code
    expect(repository.loadByCode('00000000'), throwsFormatException);
  });
}
