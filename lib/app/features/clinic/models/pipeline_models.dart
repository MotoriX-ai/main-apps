class CatalogExercise {
  const CatalogExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.focus,
    required this.side,
    required this.publisher,
    required this.tags,
    this.state = 'published',
    this.shareCode,
    this.currentVersion = 1,
  });

  final String id;
  final String name;
  final String description;
  final String focus;
  final String side;
  final String publisher;
  final List<String> tags;
  final String state;
  final String? shareCode;
  final int currentVersion;

  factory CatalogExercise.fromJson(Map<String, dynamic> json) =>
      CatalogExercise(
        id: json['id']?.toString() ?? '',
        name: json['exercise_name']?.toString() ?? 'Gerakan Motorix',
        description: json['description']?.toString() ?? '',
        focus: json['movement_focus']?.toString() ?? 'auto',
        side: json['movement_side']?.toString() ?? 'auto',
        publisher: json['publisher_name']?.toString() ?? 'Fisioterapis Motorix',
        tags: List<String>.from(json['tags'] as List? ?? const []),
        state: json['state']?.toString() ?? 'published',
        shareCode: json['share_code']?.toString(),
        currentVersion: (json['current_version'] as num?)?.toInt() ?? 1,
      );
}

class SelectedVideo {
  const SelectedVideo({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;

  String get sizeLabel {
    final mb = bytes.length / (1024 * 1024);
    return mb >= 1
        ? '${mb.toStringAsFixed(1)} MB'
        : '${(bytes.length / 1024).round()} KB';
  }
}

class AssignmentRequest {
  const AssignmentRequest({
    required this.id,
    required this.patient,
    required this.exercise,
    required this.note,
  });

  final String id;
  final String patient;
  final String exercise;
  final String note;

  factory AssignmentRequest.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] as Map<String, dynamic>? ?? const {};
    final template = json['template'] as Map<String, dynamic>? ?? const {};
    return AssignmentRequest(
      id: json['id']?.toString() ?? '',
      patient: patient['display_name']?.toString() ?? 'Pasien Motorix',
      exercise: template['exercise_name']?.toString() ?? 'Gerakan Motorix',
      note: json['patient_note']?.toString() ?? '',
    );
  }
}

class ClinicianPatient {
  const ClinicianPatient({
    required this.id,
    required this.displayName,
    required this.locale,
    required this.status,
  });

  final String id;
  final String displayName;
  final String locale;
  final String status;

  factory ClinicianPatient.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] as Map<String, dynamic>? ?? const {};
    return ClinicianPatient(
      id: patient['id']?.toString() ?? '',
      displayName: patient['display_name']?.toString() ?? 'Pasien Motorix',
      locale: patient['locale']?.toString() ?? 'id',
      status: patient['account_status']?.toString() ?? 'active',
    );
  }
}

class PipelineJob {
  const PipelineJob({
    required this.id,
    required this.status,
    required this.progress,
    required this.message,
    this.error,
    this.previewUrl,
    this.guideUrl,
    this.shareCode,
    this.recipeUrl,
    this.artifactUrl,
  });

  final String id;
  final String status;
  final int progress;
  final String message;
  final String? error;
  final String? previewUrl;
  final String? guideUrl;
  final String? shareCode;
  final String? recipeUrl;
  final String? artifactUrl;

  bool get isFinished =>
      const {'review', 'published', 'failed'}.contains(status);

  factory PipelineJob.fromJson(Map<String, dynamic> json) => PipelineJob(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        progress: (json['progress'] as num?)?.round() ?? 0,
        message: json['message']?.toString() ?? '',
        error: json['error'] as String?,
        previewUrl: json['preview_url'] as String?,
        guideUrl: json['guide_url'] as String?,
        shareCode: json['share_code'] as String?,
        recipeUrl: json['recipe_url'] as String?,
        artifactUrl: json['artifact_url'] as String?,
      );
}

class HealthStatus {
  const HealthStatus({
    required this.ok,
    required this.notebook,
    required this.offlineReady,
    required this.models,
    required this.mediaToolsReady,
  });

  final bool ok;
  final bool notebook;
  final bool offlineReady;
  final Map<String, dynamic> models;
  final bool mediaToolsReady;

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    final mediaTools = json['media_tools'] as Map<String, dynamic>? ?? {};
    return HealthStatus(
      ok: json['ok'] == true,
      notebook: json['notebook'] == true,
      offlineReady: json['offline_ready'] == true,
      models: json['models'] as Map<String, dynamic>? ?? {},
      mediaToolsReady: mediaTools['ready'] == true,
    );
  }
}
