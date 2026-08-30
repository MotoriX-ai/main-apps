import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motorix_phase2/app/core/api_config.dart';
import 'package:motorix_phase2/app/features/clinic/models/pipeline_models.dart';
import 'package:motorix_phase2/app/features/clinic/services/pipeline_client.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    ApiConfig.instance.resetToDefault();
  });

  test('pipeline job exposes both generated preview assets and urls', () {
    final job = PipelineJob.fromJson({
      'id': 'job-123',
      'status': 'review',
      'progress': 100,
      'message': 'Recipe siap direview dokter',
      'error': null,
      'preview_url': '/v1/jobs/job-123/preview',
      'guide_url': '/v1/jobs/job-123/guide',
      'share_code': 'MX-A1B2C3D4',
      'recipe_url': '/v1/jobs/job-123/recipe',
      'artifact_url': '/v1/jobs/job-123/artifact',
    });

    expect(job.id, 'job-123');
    expect(job.previewUrl, '/v1/jobs/job-123/preview');
    expect(job.guideUrl, '/v1/jobs/job-123/guide');
    expect(job.shareCode, 'MX-A1B2C3D4');
    expect(job.recipeUrl, '/v1/jobs/job-123/recipe');
    expect(job.artifactUrl, '/v1/jobs/job-123/artifact');
    expect(job.isFinished, isTrue);
  });

  test('pipeline client builds direct video stream and download URLs', () {
    final client = PipelineClient(baseUrlOverride: 'http://127.0.0.1:8000');
    addTearDown(client.dispose);

    expect(client.previewUri('abc').toString(),
        'http://127.0.0.1:8000/v1/jobs/abc/preview');
    expect(client.guideUri('abc').toString(),
        'http://127.0.0.1:8000/v1/jobs/abc/guide');
    expect(client.downloadRecipeUri('abc').toString(),
        'http://127.0.0.1:8000/v1/jobs/abc/download');
    expect(client.downloadArtifactUri('abc').toString(),
        'http://127.0.0.1:8000/v1/jobs/abc/artifact');
  });

  test('pipeline client uses dynamic ApiConfig base URL', () {
    final client = PipelineClient();
    addTearDown(client.dispose);

    expect(client.baseUrl, ApiConfig.instance.baseUrl);

    ApiConfig.instance.setBaseUrl('http://192.168.1.50:8000');
    expect(client.baseUrl, 'http://192.168.1.50:8000');
  });

  test('pipeline client parses health details and models correctly', () async {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/v1/health') {
        return http.Response(
          jsonEncode({
            'ok': true,
            'notebook': true,
            'offline_ready': true,
            'models': {
              'pose_heavy.task': {'available': true, 'size_bytes': 30664242},
              'hand.task': {'available': true, 'size_bytes': 7819105},
              'pose_lite.task': {'available': true, 'size_bytes': 5777746},
            },
            'media_tools': {
              'ready': true,
              'ffmpeg': '/usr/bin/ffmpeg',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final client = PipelineClient(client: mockClient);
    addTearDown(client.dispose);

    final health = await client.getHealthDetails();
    expect(health.ok, isTrue);
    expect(health.notebook, isTrue);
    expect(health.offlineReady, isTrue);
    expect(health.mediaToolsReady, isTrue);
    expect(health.models['pose_heavy.task']['available'], isTrue);
  });

  test('pipeline client patches recipe and publishes', () async {
    final mockClient = MockClient((request) async {
      if (request.method == 'PATCH' &&
          request.url.path == '/v1/jobs/test-job/recipe') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'exercise_name': body['exercise_name'] ?? 'Updated Name',
            'prescription': body['prescription'] ?? {},
            'quality': {'validation_status': 'review'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/v1/jobs/test-job/publish') {
        return http.Response(
          jsonEncode({
            'exercise_name': 'Updated Name',
            'quality': {
              'validation_status': 'approved',
              'therapist_reviewed': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final client = PipelineClient(client: mockClient);
    addTearDown(client.dispose);

    final patched = await client.patchRecipe('test-job', {
      'exercise_name': 'Knee Extension Modified',
      'prescription': {'target_reps': 15},
    });
    expect(patched['exercise_name'], 'Knee Extension Modified');

    final published = await client.publish('test-job');
    expect(published['quality']['validation_status'], 'approved');
  });

  test('catalog search, saved movements, and assignment use API contracts',
      () async {
    final mockClient = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/v1/catalog') {
        expect(request.url.queryParameters['query'], 'knee');
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'template-1',
                'exercise_name': 'Knee Extension',
                'description': 'Seated movement',
                'movement_focus': 'knee',
                'movement_side': 'right',
                'publisher_name': 'Dr Nadia',
                'tags': ['knee'],
              }
            ]
          }),
          200,
        );
      }
      if (request.method == 'GET' && request.url.path == '/v1/me/templates') {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'template-1', 'exercise_name': 'Knee Extension'}
            ]
          }),
          200,
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/v1/catalog/template-1/assignment-requests') {
        return http.Response(jsonEncode({'id': 'request-1'}), 200);
      }
      return http.Response('Not Found', 404);
    });
    final client = PipelineClient(client: mockClient);
    addTearDown(client.dispose);

    final catalog = await client.getCatalog(query: 'knee');
    final saved = await client.getMyTemplates();
    final requestId = await client.requestAssignment('template-1');

    expect(catalog.single.publisher, 'Dr Nadia');
    expect(saved.single.id, 'template-1');
    expect(requestId, 'request-1');
  });
}
