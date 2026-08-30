import 'dart:convert';
import 'dart:math';

import 'package:motorix_phase2/motorix_phase2.dart';
import 'package:package_info_plus/package_info_plus.dart';

String isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String newClientSessionId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20)}';
}

Future<String> motorixAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  } catch (_) {
    return 'unknown';
  }
}

class AgendaEntry {
  AgendaEntry({
    required this.prescriptionId,
    required this.templateId,
    required this.templateVersion,
    required this.scheduledFor,
    required this.exerciseName,
    required this.recipe,
    required this.targetSets,
    required this.restSeconds,
    required this.rescheduleWindowDays,
    required this.preferredTime,
    required this.timezone,
    required this.reminderEnabled,
    required this.reminderMinutesBefore,
    this.sessionStatus,
    this.sessionSummary = const {},
  });

  final String prescriptionId;
  final String templateId;
  final int templateVersion;
  final DateTime scheduledFor;
  final String exerciseName;
  final ExerciseRecipe recipe;
  final int targetSets;
  final int restSeconds;
  final int rescheduleWindowDays;
  final String preferredTime;
  final String timezone;
  final bool reminderEnabled;
  final int reminderMinutesBefore;
  final String? sessionStatus;
  final Map<String, dynamic> sessionSummary;

  bool get completed => sessionStatus == 'completed';
  bool get skipped => sessionStatus == 'skipped';
  int get preferredHour => int.tryParse(preferredTime.split(':').first) ?? 8;
  int get preferredMinute =>
      int.tryParse(preferredTime.split(':').elementAtOrNull(1) ?? '') ?? 0;

  factory AgendaEntry.fromJson(Map<String, dynamic> json) {
    final recipeJson =
        jsonDecode(jsonEncode(json['recipe'])) as Map<String, dynamic>;
    final prescription = Map<String, dynamic>.from(
        recipeJson['prescription'] as Map? ?? const {});
    prescription.addAll({
      'mode': json['mode'] ?? prescription['mode'] ?? 'reps',
      'target_sets': json['target_sets'] ?? prescription['target_sets'] ?? 1,
      'target_reps': json['target_reps'] ?? prescription['target_reps'],
      'target_duration_sec':
          json['target_duration_sec'] ?? prescription['target_duration_sec'],
      'rest_sec': json['rest_sec'] ?? prescription['rest_sec'] ?? 0,
    });
    recipeJson['prescription'] = prescription;
    return AgendaEntry(
      prescriptionId: json['prescription_id'].toString(),
      templateId: json['template_id'].toString(),
      templateVersion: (json['template_version'] as num).toInt(),
      scheduledFor: DateTime.parse(json['scheduled_for'].toString()),
      exerciseName: json['exercise_name']?.toString() ?? 'Gerakan Motorix',
      recipe: ExerciseRecipe.fromJson(recipeJson),
      targetSets: (json['target_sets'] as num?)?.toInt() ?? 1,
      restSeconds: (json['rest_sec'] as num?)?.toInt() ?? 0,
      rescheduleWindowDays:
          (json['reschedule_window_days'] as num?)?.toInt() ?? 0,
      preferredTime: json['preferred_time']?.toString() ?? '08:00',
      timezone: json['timezone']?.toString() ?? 'Asia/Jakarta',
      reminderEnabled: json['reminder_enabled'] != false,
      reminderMinutesBefore:
          (json['reminder_minutes_before'] as num?)?.toInt() ?? 30,
      sessionStatus: json['session_status']?.toString(),
      sessionSummary: Map<String, dynamic>.from(
          json['session_summary'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'prescription_id': prescriptionId,
        'template_id': templateId,
        'template_version': templateVersion,
        'scheduled_for': isoDate(scheduledFor),
        'exercise_name': exerciseName,
        'target_sets': targetSets,
        'rest_sec': restSeconds,
        'reschedule_window_days': rescheduleWindowDays,
        'preferred_time': preferredTime,
        'timezone': timezone,
        'reminder_enabled': reminderEnabled,
        'reminder_minutes_before': reminderMinutesBefore,
        'session_status': sessionStatus,
        'session_summary': sessionSummary,
        'recipe': recipeToJson(recipe),
      };
}

Map<String, dynamic> recipeToJson(ExerciseRecipe recipe) => {
      'schema_version': recipe.schemaVersion,
      'recipe_id': recipe.recipeId,
      'exercise_name': recipe.exerciseName,
      'capture': {'camera_view': recipe.cameraView},
      'joints': {'primary': recipe.primary, 'guard': recipe.guard},
      'template': {'length': recipe.templateLength, ...recipe.template},
      'tolerance': recipe.tolerance,
      'timing': {
        'cycle_sec': recipe.cycleSeconds,
        'phase_anchors': recipe.phaseAnchors,
        'direction': recipe.directions,
      },
      'prescription': {
        'mode': recipe.mode == ExerciseMode.duration ? 'duration' : 'reps',
        'target_reps': recipe.targetReps,
        'target_sets': recipe.targetSets,
        if (recipe.targetDurationSeconds != null)
          'target_duration_sec': recipe.targetDurationSeconds,
        'rest_sec': recipe.restSeconds,
        'progression_factor': recipe.progressionFactor,
      },
      'guidance': recipe.guidance,
      'quality': {
        'validation_status': 'approved',
        'therapist_reviewed': true,
      },
    };

class SessionHistoryItem {
  const SessionHistoryItem({
    required this.id,
    required this.scheduledFor,
    required this.exerciseName,
    required this.status,
    required this.summary,
    required this.uploadedOffline,
  });

  final String id;
  final DateTime scheduledFor;
  final String exerciseName;
  final String status;
  final Map<String, dynamic> summary;
  final bool uploadedOffline;

  double get totalScore => (summary['total_score'] as num?)?.toDouble() ?? 0;
  double get formScore => (summary['form_score'] as num?)?.toDouble() ?? 0;
  double get romScore => (summary['rom_score'] as num?)?.toDouble() ?? 0;
  double get tempoScore => (summary['tempo_score'] as num?)?.toDouble() ?? 0;
  double get stabilityScore =>
      (summary['stability_score'] as num?)?.toDouble() ?? 0;

  factory SessionHistoryItem.fromJson(Map<String, dynamic> json) {
    final template = json['template'] as Map<String, dynamic>? ?? const {};
    return SessionHistoryItem(
      id: json['id'].toString(),
      scheduledFor: DateTime.parse(json['scheduled_for'].toString()),
      exerciseName: template['exercise_name']?.toString() ?? 'Gerakan Motorix',
      status: json['status']?.toString() ?? 'abandoned',
      summary: Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
      uploadedOffline: json['uploaded_offline'] == true,
    );
  }
}

class PendingSession {
  const PendingSession(this.payload);
  final Map<String, dynamic> payload;
  String get clientSessionId => payload['client_session_id'].toString();

  Map<String, dynamic> toJson() => payload;
  factory PendingSession.fromJson(Map<String, dynamic> json) =>
      PendingSession(Map<String, dynamic>.from(json));
}
