import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:motorix_phase2/motorix_phase2.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:motorix_phase2/app/core/localization.dart';
import 'package:motorix_phase2/app/core/theme.dart';
import 'package:motorix_phase2/app/features/camera/models/camera_errors.dart';
import 'package:motorix_phase2/app/features/camera/presentations/pose_painter.dart';
import 'package:motorix_phase2/app/features/camera/services/mlkit_camera_source.dart';
import 'package:motorix_phase2/app/features/summary/models/session_summary.dart';
import 'package:motorix_phase2/app/features/summary/presentations/summary_screen.dart';

Future<void> runOptionalTts(Future<dynamic> Function() operation) async {
  try {
    await operation();
  } catch (_) {}
}

Future<void> speakOptionalTts({
  required Future<dynamic> Function() stop,
  required Future<dynamic> Function() speak,
}) async {
  await runOptionalTts(stop);
  await Future<void>.delayed(const Duration(milliseconds: 75));
  await runOptionalTts(speak);
}

@visibleForTesting
Future<void> startCameraWithOptionalTts({
  required Future<dynamic> Function() initializeTts,
  required Future<void> Function() startCamera,
}) async {
  await runOptionalTts(initializeTts);
  await startCamera();
}

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.recipe,
    this.returnSummary = false,
  });
  final ExerciseRecipe recipe;
  final bool returnSummary;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with WidgetsBindingObserver {
  late final MlKitCameraPoseSource source;
  late final PhysioRuntime runtime;
  final tts = FlutterTts();
  StreamSubscription<PoseFrame>? subscription;
  FrameFeedback? feedback;
  String? error;
  bool ready = false;
  bool finishing = false;
  bool paused = false;
  bool poseReady = false;
  bool hasAnnouncedReady = false;
  String trackingMessage = 'Posisikan seluruh tubuh di dalam kamera.';
  final scores = <RepScore>[];
  final tempoMatchedFrames = <String, int>{};
  final tempoMeasuredFrames = <String, int>{};
  final stopwatch = Stopwatch();
  Timer? durationTimer;
  int completedHoldSeconds = 0;

  bool get _english => motorixLocale.locale.languageCode == 'en';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    source =
        MlKitCameraPoseSource(enableHands: widget.recipe.requiresHandTracking);
    runtime = PhysioRuntime(widget.recipe);
    _start();
  }

  Future<void> _start() async {
    if (mounted) setState(() => error = null);
    try {
      if (widget.recipe.requiresHandTracking && !source.supportsHandTracking) {
        throw UnsupportedError(_english
            ? 'Finger exercises require Hand Landmarker. Use Motorix Web for this build.'
            : 'Latihan jari memerlukan Hand Landmarker. Gunakan Motorix Web untuk build ini.');
      }
      await startCameraWithOptionalTts(
        initializeTts: () async {
          await tts.setLanguage(_english ? 'en-US' : 'id-ID');
          await tts.setSpeechRate(.48);
        },
        startCamera: () async {
          await subscription?.cancel();
          subscription = source.frames.listen(_onPose);
          await source.start();
        },
      );
      stopwatch.start();
      await WakelockPlus.enable();
      if (widget.recipe.mode == ExerciseMode.duration) {
        durationTimer?.cancel();
        durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          final target = widget.recipe.targetDurationSeconds ?? 1;
          if (poseReady) completedHoldSeconds++;
          if (!finishing && completedHoldSeconds >= target) {
            unawaited(_finish());
          } else if (mounted) {
            setState(() {});
          }
        });
      }
      if (mounted) setState(() => ready = true);
    } catch (exception) {
      if (mounted) setState(() => error = cameraErrorMessage(exception));
    }
  }

  Future<void> _speak(String text) => speakOptionalTts(
        stop: tts.stop,
        speak: () => tts.speak(text),
      );

  void _onPose(PoseFrame pose) {
    final handFeatures = widget.recipe.tracked
        .where((name) =>
            name.startsWith('curl_') ||
            name.startsWith('hand_spread_') ||
            name.startsWith('wrist_flex_'))
        .toList(growable: false);
    final isHandExercise = handFeatures.isNotEmpty;
    const requiredLandmarks = [11, 12, 23, 24, 25, 26, 27, 28];
    final visible = requiredLandmarks
        .where((index) => pose.visibility[index] >= .45)
        .length;
    final detectedHandFeatures = handFeatures
        .where((name) => pose.extraFeatures[name]?.isFinite ?? false)
        .length;
    final isPoseReady = isHandExercise
        ? detectedHandFeatures == handFeatures.length
        : visible >= 7;
    if (!isPoseReady) {
      if (mounted) {
        setState(() {
          poseReady = false;
          trackingMessage = isHandExercise
              ? (_english
                  ? 'Move your hand closer and keep every finger visible.'
                  : 'Dekatkan tangan ke kamera dan pastikan semua jari terlihat.')
              : visible < 4
                  ? (_english
                      ? 'Step back until your whole body is visible.'
                      : 'Mundur sedikit sampai seluruh tubuh terlihat.')
                  : (_english
                      ? 'Keep your knees and ankles visible to the camera.'
                      : 'Pastikan lutut dan pergelangan kaki terlihat kamera.');
        });
      }
      return;
    }
    poseReady = true;
    trackingMessage = isHandExercise
        ? (_english
            ? 'Hand detected. Follow the movement guide.'
            : 'Tangan terdeteksi. Ikuti panduan gerakan.')
        : (_english
            ? 'Body detected. Follow the movement guide.'
            : 'Tubuh terdeteksi. Ikuti panduan gerakan.');
    if (!hasAnnouncedReady) {
      hasAnnouncedReady = true;
      unawaited(_speak(widget.recipe.guidance['start'] ??
          (_english
              ? 'Your position is correct. Start the exercise slowly.'
              : 'Posisi Anda sudah benar. Mulai latihan secara perlahan.')));
    }
    final next = runtime.update(featuresFromPose(pose));
    for (final entry in next.tempoColors.entries) {
      if (entry.value != JointColor.red && entry.value != JointColor.amber) {
        continue;
      }
      tempoMeasuredFrames[entry.key] =
          (tempoMeasuredFrames[entry.key] ?? 0) + 1;
      if (entry.value == JointColor.red) {
        tempoMatchedFrames[entry.key] =
            (tempoMatchedFrames[entry.key] ?? 0) + 1;
      }
    }
    final cue = next.cue;
    if (cue != null) unawaited(_speak(cue));
    final score = next.completedScore;
    if (score != null) scores.add(score);
    if (mounted) setState(() => feedback = next);
    if (widget.recipe.mode == ExerciseMode.repetitions &&
        !finishing &&
        next.repCount >= widget.recipe.targetReps &&
        mounted) {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (finishing) return;
    finishing = true;
    durationTimer?.cancel();
    stopwatch.stop();
    await WakelockPlus.disable();
    await source.stop();
    await runOptionalTts(tts.stop);
    if (!mounted) return;
    final summary = SessionSummary(
      recipe: widget.recipe,
      scores: List.unmodifiable(scores),
      repetitions: feedback?.repCount ?? 0,
      duration: widget.recipe.mode == ExerciseMode.duration
          ? Duration(seconds: completedHoldSeconds)
          : stopwatch.elapsed,
      tempoMatchRatio: {
        for (final entry in tempoMeasuredFrames.entries)
          if (entry.value > 0)
            entry.key: (tempoMatchedFrames[entry.key] ?? 0) / entry.value,
      },
    );
    if (widget.returnSummary) {
      Navigator.of(context).pop(summary);
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SummaryScreen(summary: summary),
      ),
    );
  }

  Future<void> _cancel() async {
    final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(motorixText(context,
                id: 'Batalkan latihan?', en: 'Cancel exercise?')),
            content: Text(motorixText(context,
                id: 'Progres sesi ini tidak akan dimasukkan ke ringkasan.',
                en: 'This set will not be included in the summary.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(motorixText(context,
                      id: 'Lanjut latihan', en: 'Continue'))),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child:
                      Text(motorixText(context, id: 'Batalkan', en: 'Cancel'))),
            ],
          ),
        ) ??
        false;
    if (!leave || !mounted) return;
    finishing = true;
    durationTimer?.cancel();
    stopwatch.stop();
    await WakelockPlus.disable();
    await source.stop();
    await runOptionalTts(tts.stop);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _togglePause() async {
    if (finishing) return;
    if (paused) {
      await source.start();
      stopwatch.start();
      if (mounted) setState(() => paused = false);
    } else {
      await source.stop();
      stopwatch.stop();
      poseReady = false;
      if (mounted) setState(() => paused = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(source.stop());
      stopwatch.stop();
      poseReady = false;
      if (mounted) setState(() => ready = false);
    } else if (state == AppLifecycleState.resumed && !finishing && !paused) {
      source.start().then((_) {
        stopwatch.start();
        if (mounted) setState(() => ready = true);
      }).catchError((Object exception) {
        if (mounted) setState(() => error = cameraErrorMessage(exception));
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    subscription?.cancel();
    durationTimer?.cancel();
    unawaited(WakelockPlus.disable());
    source.dispose();
    unawaited(runOptionalTts(tts.stop));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = source.preview;
    final currentError = error;
    final landmarks = source.latestLandmarks;
    final imageSize = source.latestImageSize;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(fit: StackFit.expand, children: [
          if (ready && preview != null)
            Center(child: preview)
          else
            Center(
              child: currentError == null
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(currentError,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: _SessionTypography.fontFamily,
                            )),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(motorixText(context,
                              id: 'Coba lagi', en: 'Try again')),
                        ),
                      ]),
                    ),
            ),
          if (landmarks != null && imageSize != null)
            CustomPaint(
                painter: PosePainter(
              landmarks: landmarks,
              imageSize: imageSize,
              mirror: source.isFrontCamera,
              feedback: feedback,
              hands: source.latestHands ?? const [],
            )),
          Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _TopBar(
                name: widget.recipe.exerciseName,
                onClose: _cancel,
                onPause: _togglePause,
                paused: paused,
                onFinish: _finish,
              )),
          Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _FeedbackPanel(
                feedback: feedback,
                target: widget.recipe.mode == ExerciseMode.duration
                    ? widget.recipe.targetDurationSeconds ?? 1
                    : widget.recipe.targetReps,
                progressValue: widget.recipe.mode == ExerciseMode.duration
                    ? (completedHoldSeconds /
                            (widget.recipe.targetDurationSeconds ?? 1))
                        .clamp(0, 1)
                    : null,
                durationMode: widget.recipe.mode == ExerciseMode.duration,
                latestScore: scores.isEmpty ? null : scores.last,
                poseReady: poseReady,
                trackingMessage: trackingMessage,
              )),
        ]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.name,
      required this.onClose,
      required this.onPause,
      required this.paused,
      required this.onFinish});
  final String name;
  final VoidCallback onClose;
  final VoidCallback onPause;
  final bool paused;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          IconButton(
              onPressed: onClose,
              color: Colors.white,
              icon: const Icon(Icons.close)),
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: _SessionTypography.fontFamily,
                    fontWeight: FontWeight.w700,
                  ))),
          IconButton(
            onPressed: onPause,
            tooltip: paused
                ? motorixText(context, id: 'Lanjutkan', en: 'Resume')
                : motorixText(context, id: 'Jeda', en: 'Pause'),
            color: Colors.white,
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
          ),
          TextButton(
            onPressed: onFinish,
            style: TextButton.styleFrom(
              backgroundColor: _SessionColors.green,
              foregroundColor: _SessionColors.softWhite,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: const StadiumBorder(),
            ),
            child: Text(motorixText(context, id: 'Akhiri', en: 'Finish'),
                style: const TextStyle(
                  color: _SessionColors.softWhite,
                  fontFamily: _SessionTypography.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ]),
      );
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel(
      {required this.feedback,
      required this.target,
      required this.durationMode,
      required this.poseReady,
      required this.trackingMessage,
      this.progressValue,
      this.latestScore});
  final FrameFeedback? feedback;
  final int target;
  final bool durationMode;
  final double? progressValue;
  final RepScore? latestScore;
  final bool poseReady;
  final String trackingMessage;

  @override
  Widget build(BuildContext context) {
    final score = latestScore;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _SessionColors.green.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _SessionColors.lightGreen.withValues(alpha: .35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(
                '${durationMode ? ((progressValue ?? 0) * target).floor() : feedback?.repCount ?? 0}',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: _SessionTypography.fontFamily,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                )),
            Text(
                durationMode
                    ? ' / $target ${motorixText(context, id: 'detik', en: 'seconds')}'
                    : ' / $target ${motorixText(context, id: 'repetisi', en: 'reps')}',
                style: const TextStyle(
                  color: _SessionColors.lightGreen,
                  fontFamily: _SessionTypography.fontFamily,
                )),
            const Spacer(),
            if (score != null)
              Text('${score.total.toStringAsFixed(0)}/100',
                  style: const TextStyle(
                    color: Color(0xffd9f26a),
                    fontFamily: _SessionTypography.fontFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  )),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progressValue ?? feedback?.progress ?? 0,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            color: _SessionColors.lightGreen,
            backgroundColor: _SessionColors.navy.withValues(alpha: .45),
          ),
          const SizedBox(height: 12),
          Text(
            poseReady ? feedback?.cue ?? trackingMessage : trackingMessage,
            style: TextStyle(
              color: poseReady ? Colors.white : const Color(0xffffc857),
              fontFamily: _SessionTypography.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 14,
            runSpacing: 7,
            children: [
              _TempoLegend(color: Color(0xffff4d4d), label: 'Tempo pas'),
              _TempoLegend(
                  color: Color(0xffffc857), label: 'Terlalu cepat/lambat'),
              _TempoLegend(color: Colors.white70, label: 'Belum terbaca'),
            ],
          ),
        ]),
      ),
    );
  }
}

class _TempoLegend extends StatelessWidget {
  const _TempoLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
              color: _SessionColors.softWhite,
              fontFamily: _SessionTypography.fontFamily,
              fontSize: 12,
            )),
      ]);
}

abstract final class _SessionColors {
  static const softWhite = AppColors.softWhite;
  static const navy = AppColors.navy;
  static const green = AppColors.green;
  static const lightGreen = AppColors.lightGreen;
}

abstract final class _SessionTypography {
  static const fontFamily = 'SF Pro';
}
