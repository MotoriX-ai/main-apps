import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motorix_phase2/app/core/localization.dart';
import 'package:motorix_phase2/app/core/theme.dart';
import 'package:motorix_phase2/app/features/camera/presentations/session_screen.dart';
import 'package:motorix_phase2/app/features/clinic/models/clinical_models.dart';
import 'package:motorix_phase2/app/features/clinic/services/clinical_cache.dart';
import 'package:motorix_phase2/app/features/clinic/services/pipeline_client.dart';
import 'package:motorix_phase2/app/features/home/models/completed_exercise.dart';
import 'package:motorix_phase2/app/features/home/services/notification_service.dart';
import 'package:motorix_phase2/app/features/summary/models/session_summary.dart';

class GuidedDayScreen extends StatefulWidget {
  const GuidedDayScreen({
    super.key,
    required this.entries,
    required this.cache,
    required this.client,
  });

  final List<AgendaEntry> entries;
  final ClinicalCache cache;
  final PipelineClient client;

  @override
  State<GuidedDayScreen> createState() => _GuidedDayScreenState();
}

class _GuidedDayScreenState extends State<GuidedDayScreen> {
  int exerciseIndex = 0;
  int setIndex = 0;
  bool running = false;
  final completedSets = <Map<String, dynamic>>[];
  final summaries = <SessionSummary>[];
  final completedExercises = <CompletedExercise>[];

  AgendaEntry get entry => widget.entries[exerciseIndex];

  Future<void> _runSet() async {
    if (running) return;
    setState(() => running = true);
    final summary = await Navigator.of(context).push<SessionSummary>(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          recipe: entry.recipe,
          returnSummary: true,
        ),
      ),
    );
    if (!mounted) return;
    if (summary == null) {
      setState(() => running = false);
      return;
    }
    summaries.add(summary);
    completedSets.add({
      'set_index': setIndex + 1,
      'repetitions': summary.repetitions,
      'duration_sec': summary.duration.inMilliseconds / 1000,
      'form_score': summary.form,
      'rom_score': summary.rom,
      'tempo_score': summary.tempo,
      'stability_score': summary.compensation,
      'total_score': summary.total,
      'detail': {'tempo_match_ratio': summary.tempoMatchRatio},
    });
    if (setIndex + 1 < entry.targetSets) {
      setState(() {
        setIndex++;
        running = false;
      });
      if (entry.restSeconds > 0) await _rest(entry.restSeconds);
      return;
    }
    await _saveCurrentExercise();
    if (!mounted) return;
    if (exerciseIndex + 1 < widget.entries.length) {
      setState(() {
        exerciseIndex++;
        setIndex = 0;
        summaries.clear();
        completedSets.clear();
        running = false;
      });
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _GuidedSummaryScreen(items: completedExercises),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _saveCurrentExercise() async {
    double average(double Function(SessionSummary) select) => summaries.isEmpty
        ? 0
        : summaries.map(select).reduce((a, b) => a + b) / summaries.length;
    final now = DateTime.now().toUtc();
    final pending = PendingSession({
      'client_session_id': newClientSessionId(),
      'prescription_id': entry.prescriptionId,
      'template_version': entry.templateVersion,
      'scheduled_for': isoDate(entry.scheduledFor),
      'started_at': now
          .subtract(Duration(
              milliseconds: summaries.fold<int>(
                  0, (total, item) => total + item.duration.inMilliseconds)))
          .toIso8601String(),
      'completed_at': now.toIso8601String(),
      'status': 'completed',
      'app_version': await motorixAppVersion(),
      'device_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'uploaded_offline': false,
      'summary': {
        'total_score': average((item) => item.total),
        'form_score': average((item) => item.form),
        'rom_score': average((item) => item.rom),
        'tempo_score': average((item) => item.tempo),
        'stability_score': average((item) => item.compensation),
        'sets_completed': summaries.length,
      },
      'sets': List<Map<String, dynamic>>.from(completedSets),
    });
    await widget.cache.enqueue(pending);
    completedExercises.add(CompletedExercise(
      name: entry.exerciseName,
      score: average((item) => item.total),
      sets: summaries.length,
    ));
    try {
      await widget.client.syncSession(pending);
      await widget.cache.acknowledge(pending.clientSessionId);
    } catch (_) {
      final offline = Map<String, dynamic>.from(pending.payload)
        ..['uploaded_offline'] = true;
      await widget.cache.enqueue(PendingSession(offline));
    }
  }

  Future<void> _rest(int seconds) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RestDialog(seconds: seconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = MotorixStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.get('today'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Image.asset('assets/images/motorix_wordmark.png', height: 42),
          const SizedBox(height: 28),
          LinearProgressIndicator(
            value: (exerciseIndex + (setIndex / entry.targetSets)) /
                widget.entries.length,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 28),
          Text(entry.exerciseName,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('${strings.get('sets')} ${setIndex + 1}/${entry.targetSets}'),
          const SizedBox(height: 8),
          Text(entry.recipe.mode.name == 'duration'
              ? '${entry.recipe.targetDurationSeconds} ${strings.get('seconds')}'
              : '${entry.recipe.targetReps} ${strings.get('reps')}'),
          const Spacer(),
          FilledButton.icon(
            onPressed: running ? null : _runSet,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(strings.get('next')),
          ),
          const SizedBox(height: 16),
          Text(strings.get('nonDiagnostic'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}

class _GuidedSummaryScreen extends StatelessWidget {
  const _GuidedSummaryScreen({required this.items});

  final List<CompletedExercise> items;

  @override
  Widget build(BuildContext context) {
    final strings = MotorixStrings.of(context);
    final average = items.isEmpty
        ? 0.0
        : items.fold<double>(0, (total, item) => total + item.score) /
            items.length;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Image.asset('assets/images/motorix_logo_large.png', height: 82),
          const SizedBox(height: 20),
          Text(
            strings.get('sessionComplete'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${average.toStringAsFixed(0)}/100',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: AppColors.green,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 24),
          for (final item in items)
            ListTile(
              leading: const Icon(Icons.check_circle, color: AppColors.green),
              title: Text(item.name),
              subtitle: Text('${item.sets} ${strings.get('sets')}'),
              trailing: Text(item.score.toStringAsFixed(0)),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.get('done')),
          ),
          const SizedBox(height: 12),
          Text(
            strings.get('nonDiagnostic'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RestDialog extends StatefulWidget {
  const _RestDialog({required this.seconds});
  final int seconds;
  @override
  State<_RestDialog> createState() => _RestDialogState();
}

class _RestDialogState extends State<_RestDialog> {
  late int remaining = widget.seconds;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining <= 1) {
        timer?.cancel();
        unawaited(MotorixNotifications.instance.restComplete());
        Navigator.of(context).pop();
      } else {
        setState(() => remaining--);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(MotorixStrings.of(context).get('rest')),
        content: Text('$remaining s',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.green, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MotorixStrings.of(context).get('next')),
          ),
        ],
      );
}
