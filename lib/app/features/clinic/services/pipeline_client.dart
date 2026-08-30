import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:motorix_phase2/app/core/api_config.dart';
import 'package:motorix_phase2/app/features/auth/services/auth_service.dart';
import 'package:motorix_phase2/app/features/clinic/models/clinical_models.dart';
import 'package:motorix_phase2/app/features/clinic/models/pipeline_models.dart';

class PipelineClient {
  PipelineClient({
    http.Client? client,
    String? baseUrlOverride,
  })  : _client = client ?? http.Client(),
        _baseUrlOverride = baseUrlOverride;

  final http.Client _client;
  final String? _baseUrlOverride;

  String get baseUrl => _baseUrlOverride ?? ApiConfig.instance.baseUrl;

  Map<String, String> get _authHeaders {
    final token = AuthService.instance.accessToken;
    return token == null ? const {} : {'Authorization': 'Bearer $token'};
  }

  Map<String, String> get mediaHeaders => _authHeaders;

  Future<bool> health() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/v1/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['ok'] == true || json['offline_ready'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<HealthStatus> getHealthDetails() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/v1/health'))
        .timeout(const Duration(seconds: 6));
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Server tidak merespons'));
    }
    return HealthStatus.fromJson(body);
  }

  Future<Map<String, dynamic>> getModels() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/v1/models'))
        .timeout(const Duration(seconds: 6));
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Status model tidak tersedia'));
    }
    return body;
  }

  Future<PipelineJob> createJob({
    required String exerciseName,
    required String therapistId,
    required int targetReps,
    required double progressionFactor,
    required String movementFocus,
    required String movementSide,
    required SelectedVideo video,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/v1/jobs'))
      ..headers.addAll(_authHeaders)
      ..fields.addAll({
        'exercise_name': exerciseName,
        'therapist_id': therapistId,
        'target_reps': '$targetReps',
        'progression_factor': '$progressionFactor',
        'movement_focus': movementFocus,
        'movement_side': movementSide,
      })
      ..files.add(http.MultipartFile.fromBytes('video', video.bytes,
          filename: video.name));
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(_errorMessage(body, 'Video gagal dikirim'));
    }
    return PipelineJob.fromJson(body);
  }

  Future<PipelineJob> getJob(String id) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/jobs/$id'),
      headers: _authHeaders,
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Status proses tidak tersedia'));
    }
    return PipelineJob.fromJson(body);
  }

  Future<Map<String, dynamic>> getRecipe(String id) async {
    final response = await _client.get(Uri.parse('$baseUrl/v1/jobs/$id/recipe'),
        headers: _authHeaders);
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Recipe belum tersedia'));
    }
    return body;
  }

  Future<Map<String, dynamic>> patchRecipe(
      String id, Map<String, dynamic> patch) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/v1/jobs/$id/recipe'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(patch),
    );
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          _errorMessage(body, 'Gagal memperbarui parameter recipe'));
    }
    return body;
  }

  Future<Map<String, dynamic>> publish(String id) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/jobs/$id/publish'),
      headers: _authHeaders,
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Recipe gagal dipublikasikan'));
    }
    return body;
  }

  Future<Map<String, dynamic>> getRecipeByShareCode(String shareCode) async {
    final response = await _client
        .get(Uri.parse('$baseUrl/v1/recipes/code/$shareCode'))
        .timeout(const Duration(seconds: 10));
    final body = _decode(response);
    if (response.statusCode == 404) {
      throw StateError(
          'Kode latihan tidak ditemukan atau belum dipublikasikan.');
    }
    if (response.statusCode != 200) {
      throw StateError(
          _errorMessage(body, 'Gagal mengambil recipe dari server.'));
    }
    return body;
  }

  Future<List<CatalogExercise>> getCatalog({String query = ''}) async {
    final uri = Uri.parse('$baseUrl/v1/catalog').replace(
      queryParameters: query.trim().isEmpty ? null : {'query': query.trim()},
    );
    final response = await _client.get(uri);
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Katalog tidak tersedia'));
    }
    return (body['items'] as List? ?? const [])
        .map((item) => CatalogExercise.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CatalogExercise>> getMyTemplates() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/me/templates'),
      headers: _authHeaders,
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Gerakan tersimpan tidak tersedia'));
    }
    return (body['items'] as List? ?? const [])
        .map((item) => CatalogExercise.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<String> requestAssignment(String templateId,
      {String note = ''}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/catalog/$templateId/assignment-requests'),
      headers: _authHeaders,
      body: {'note': note},
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Permintaan assignment gagal'));
    }
    return body['id']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> getAssignedRecipe(String templateId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/catalog/$templateId/assigned-recipe'),
      headers: _authHeaders,
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Gerakan belum ditugaskan'));
    }
    return body;
  }

  Future<List<AssignmentRequest>> getAssignmentRequests() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/me/assignment-requests'),
      headers: _authHeaders,
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(
          _errorMessage(body, 'Permintaan assignment tidak tersedia'));
    }
    return (body['items'] as List? ?? const [])
        .map((item) => AssignmentRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> reviewAssignment(String requestId, bool approve) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/assignment-requests/$requestId/review'),
      headers: _authHeaders,
      body: {'approve': '$approve'},
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Review assignment gagal'));
    }
  }

  Future<List<AgendaEntry>> getAgenda(DateTime from, DateTime to) async {
    final uri = Uri.parse('$baseUrl/v1/me/agenda').replace(queryParameters: {
      'from': isoDate(from),
      'to': isoDate(to),
    });
    final response = await _client.get(uri, headers: _authHeaders);
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Agenda tidak tersedia'));
    }
    return (body['items'] as List? ?? const [])
        .map((item) =>
            AgendaEntry.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<SessionHistoryItem>> getHistory({int limit = 100}) async {
    final uri = Uri.parse('$baseUrl/v1/me/history')
        .replace(queryParameters: {'limit': '$limit'});
    final response = await _client.get(uri, headers: _authHeaders);
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Riwayat tidak tersedia'));
    }
    return (body['items'] as List? ?? const [])
        .map((item) =>
            SessionHistoryItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<String> syncSession(PendingSession session) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/me/sessions/sync'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(session.payload),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Sesi belum tersinkron'));
    }
    return body['id']?.toString() ?? '';
  }

  Future<void> reschedule({
    required String prescriptionId,
    required DateTime originalDate,
    required DateTime scheduledDate,
    required String reason,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/prescriptions/$prescriptionId/reschedule'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'original_date': isoDate(originalDate),
        'scheduled_date': isoDate(scheduledDate),
        'reason': reason,
      }),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Jadwal tidak dapat dipindahkan'));
    }
  }

  Future<List<ClinicianPatient>> getClinicianPatients() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/clinician/patients'),
      headers: _authHeaders,
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Daftar pasien tidak tersedia'));
    }
    return (body['items'] as List? ?? const [])
        .map((item) =>
            ClinicianPatient.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<SessionHistoryItem>> getPatientProgress(String patientId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/clinician/patients/$patientId/progress'),
      headers: _authHeaders,
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Progres pasien tidak tersedia'));
    }
    return (body['items'] as List? ?? const [])
        .map((item) =>
            SessionHistoryItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> createPrescription(
      Map<String, dynamic> payload) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/clinician/prescriptions'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final body = _decode(response);
    if (response.statusCode != 201) {
      throw StateError(_errorMessage(body, 'Program tidak dapat disimpan'));
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> getPatientPrescriptions(
      String patientId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/clinician/patients/$patientId/prescriptions'),
      headers: _authHeaders,
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Program pasien tidak tersedia'));
    }
    return (body['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> updatePrescription(
      String id, Map<String, dynamic> payload) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/v1/clinician/prescriptions/$id'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Program tidak dapat diperbarui'));
    }
    return body;
  }

  Future<Map<String, dynamic>> inviteClinician(String email,
      {String role = 'physiotherapist'}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/admin/clinician-invitations'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'role': role}),
    );
    final body = _decode(response);
    if (response.statusCode != 201) {
      throw StateError(_errorMessage(body, 'Invitation tidak dapat dibuat'));
    }
    return body;
  }

  Future<void> approveClinician(
      {required String userId, required String invitationId}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/admin/clinicians/approve'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'invitation_id': invitationId}),
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Klinisi tidak dapat diverifikasi'));
    }
  }

  Future<Map<String, dynamic>> getAdminOverview() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/admin/overview'),
      headers: _authHeaders,
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(_errorMessage(body, 'Data administrasi tidak tersedia'));
    }
    return body;
  }

  Future<void> setAccountStatus(String userId, String status) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/v1/admin/accounts/$userId/status'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode != 204) {
      throw StateError(
          _errorMessage(_decode(response), 'Status akun tidak dapat diubah'));
    }
  }

  Future<void> manageCareTeam({
    required String patientId,
    required String clinicianId,
    required bool assigned,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/admin/care-team'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'patient_id': patientId,
        'clinician_id': clinicianId,
        'assigned': assigned,
      }),
    );
    if (response.statusCode != 204) {
      throw StateError(
          _errorMessage(_decode(response), 'Care team tidak dapat diubah'));
    }
  }

  Future<void> registerPushSubscription(Map<String, dynamic> payload) async {
    final keys = payload['keys'] as Map? ?? const {};
    final response = await _client.post(
      Uri.parse('$baseUrl/v1/me/push-subscriptions'),
      headers: {..._authHeaders, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'endpoint': payload['endpoint'],
        'p256dh': keys['p256dh'],
        'auth': keys['auth'],
        'timezone': 'Asia/Jakarta',
      }),
    );
    if (response.statusCode != 204) {
      throw StateError(
          _errorMessage(_decode(response), 'Web push tidak dapat diaktifkan'));
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/v1/me/notifications'),
      headers: _authHeaders,
    );
    final body = _decode(response);
    if (response.statusCode != 200) {
      throw StateError(
          _errorMessage(body, 'Riwayat notifikasi tidak tersedia'));
    }
    return (body['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Uri previewUri(String id) => Uri.parse('$baseUrl/v1/jobs/$id/preview');

  Uri guideUri(String id) => Uri.parse('$baseUrl/v1/jobs/$id/guide');

  Uri catalogGuideUri(String id) => Uri.parse('$baseUrl/v1/catalog/$id/guide');

  Uri downloadRecipeUri(String id) =>
      Uri.parse('$baseUrl/v1/jobs/$id/download');

  Uri downloadArtifactUri(String id) =>
      Uri.parse('$baseUrl/v1/jobs/$id/artifact');

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      return {'detail': response.body};
    }
  }

  String _errorMessage(Map<String, dynamic> json, String fallback) {
    final detail = json['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List) return detail.join(' · ');
    return fallback;
  }

  void dispose() => _client.close();
}
