import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:motorix_phase2/app/features/camera/models/camera_errors.dart';
import 'package:motorix_phase2/app/features/camera/presentations/pose_painter.dart';
import 'package:motorix_phase2/app/features/camera/presentations/session_screen.dart';
import 'package:motorix_phase2/app/features/camera/services/mlkit_camera_source.dart';
import 'package:motorix_phase2/app/features/clinic/models/pipeline_models.dart';

@visibleForTesting
Future<bool> initializeOptionalSpeech(
  Future<bool> Function() initialize,
) async {
  try {
    return await initialize();
  } catch (_) {
    return false;
  }
}

@visibleForTesting
class StopRecordingCommandGate {
  bool _consumed = false;

  bool shouldStop(String transcript) {
    if (_consumed) return false;
    final normalized = transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized != 'stop recording') return false;
    _consumed = true;
    return true;
  }

  void reset() => _consumed = false;
}

@visibleForTesting
class FramingCueThrottle {
  DateTime? _lostAt;
  DateTime? _lastCueAt;

  bool shouldSpeak({
    required bool framingReady,
    required bool recording,
    required DateTime now,
  }) {
    if (framingReady || !recording) {
      _lostAt = null;
      return false;
    }
    _lostAt ??= now;
    final lostLongEnough = now.difference(_lostAt!).inMilliseconds >= 1500;
    final cooledDown =
        _lastCueAt == null || now.difference(_lastCueAt!).inSeconds >= 8;
    if (!lostLongEnough || !cooledDown) return false;
    _lastCueAt = now;
    return true;
  }
}

class VideoRecorderScreen extends StatefulWidget {
  const VideoRecorderScreen({
    super.key,
    required this.movementFocus,
    required this.movementSide,
  });

  final String movementFocus;
  final String movementSide;

  @override
  State<VideoRecorderScreen> createState() => _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends State<VideoRecorderScreen>
    with WidgetsBindingObserver {
  final source = MlKitCameraPoseSource();
  final tts = FlutterTts();
  final speech = SpeechToText();
  final stopCommandGate = StopRecordingCommandGate();
  StreamSubscription? frames;
  Timer? speechRestart;
  bool recording = false;
  bool stoppingRecording = false;
  bool speechInitialized = false;
  bool speechAvailable = false;
  bool listening = false;
  bool pausingSpeech = false;
  bool busy = true;
  String? error;
  final framingCueThrottle = FramingCueThrottle();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await frames?.cancel();
      await source.start();
      await runOptionalTts(() async {
        await tts.setLanguage('en-US');
        await tts.setSpeechRate(.48);
        await tts.awaitSpeakCompletion(false);
      });
      frames = source.frames.listen((_) => _onFrame());
      if (!mounted) return source.dispose();
      setState(() {
        busy = false;
        error = null;
      });
      unawaited(_speak(
          'Camera ready. Keep your full body and exercise area visible.'));
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = cameraErrorMessage(exception);
          busy = false;
        });
      }
    }
  }

  void _onFrame() {
    final now = DateTime.now();
    if (framingCueThrottle.shouldSpeak(
      framingReady: source.framingReady,
      recording: recording,
      now: now,
    )) {
      unawaited(_announceDuringRecording(
          'Framing lost. Keep your full body visible.'));
    }
    if (mounted) setState(() {});
  }

  Future<void> _speak(String text) => speakOptionalTts(
        stop: tts.stop,
        speak: () => tts.speak(text),
      );

  Future<void> _speakToCompletion(String text) => runOptionalTts(() async {
        await tts.stop();
        await Future<void>.delayed(const Duration(milliseconds: 75));
        await tts.awaitSpeakCompletion(true);
        await tts.speak(text).timeout(const Duration(seconds: 5));
      });

  Future<void> _announceDuringRecording(String text) async {
    pausingSpeech = true;
    await _stopListening();
    await _speakToCompletion(text);
    pausingSpeech = false;
    if (recording && !stoppingRecording) _scheduleSpeechRestart();
  }

  Future<void> _initializeSpeech() async {
    if (speechInitialized) return;
    speechInitialized = true;
    speechAvailable = await initializeOptionalSpeech(
      () => speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        options: [SpeechToText.androidNoBluetooth],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    speechRestart?.cancel();
    if (!recording ||
        stoppingRecording ||
        pausingSpeech ||
        !speechAvailable ||
        speech.isListening) {
      return;
    }
    try {
      await speech.listen(
        onResult: _onSpeechResult,
        listenOptions: SpeechListenOptions(
          localeId: 'en-US',
          listenFor: Duration(seconds: 55),
          pauseFor: Duration(seconds: 4),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.confirmation,
        ),
      );
      if (mounted) setState(() => listening = speech.isListening);
    } catch (exception) {
      debugPrint('Speech recognition unavailable: $exception');
      speechAvailable = false;
      if (mounted) setState(() => listening = false);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!recording || stoppingRecording) return;
    if (stopCommandGate.shouldStop(result.recognizedWords)) {
      unawaited(_finishRecording());
    }
  }

  void _onSpeechStatus(String status) {
    listening = status == SpeechToText.listeningStatus;
    if (mounted) setState(() {});
    if (recording &&
        !stoppingRecording &&
        !pausingSpeech &&
        (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus)) {
      _scheduleSpeechRestart();
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('Speech recognition error: ${error.errorMsg}');
    listening = false;
    if (error.permanent) speechAvailable = false;
    if (mounted) setState(() {});
    if (!error.permanent && !pausingSpeech) _scheduleSpeechRestart();
  }

  void _scheduleSpeechRestart() {
    speechRestart?.cancel();
    if (!recording || stoppingRecording || pausingSpeech || !speechAvailable) {
      return;
    }
    speechRestart = Timer(
      const Duration(milliseconds: 600),
      () => unawaited(_startListening()),
    );
  }

  Future<void> _stopListening({bool notify = true}) async {
    speechRestart?.cancel();
    listening = false;
    if (speech.isListening) {
      try {
        await speech.stop();
      } catch (_) {}
    }
    if (notify && mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (busy) _initialize();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      setState(() {
        busy = true;
        recording = false;
        stoppingRecording = false;
        error = 'Rekaman dihentikan karena aplikasi berpindah ke background.';
      });
      unawaited(_stopListening());
      unawaited(source.stop());
    }
  }

  Future<void> _toggle() async {
    if (stoppingRecording) return;
    try {
      if (!recording) {
        await source.startRecording();
        stopCommandGate.reset();
        if (mounted) setState(() => recording = true);
        await _speakToCompletion(
            'Recording started. Complete at least four full repetitions. Say stop recording when you are finished.');
        if (!recording || stoppingRecording) return;
        await _initializeSpeech();
        await _startListening();
        return;
      }
      await _finishRecording();
    } catch (exception) {
      debugPrint('Rekaman gagal: $exception');
      if (mounted) {
        setState(() {
          recording = false;
          stoppingRecording = false;
          error = cameraErrorMessage(exception);
        });
      }
    }
  }

  Future<void> _finishRecording() async {
    if (!recording || stoppingRecording) return;
    stoppingRecording = true;
    if (mounted) setState(() => recording = false);
    await _stopListening();
    try {
      final file = await source.stopRecording();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await _speakToCompletion(
          'Recording complete. The video is ready for analysis.');
      if (!mounted) return;
      Navigator.pop(
        context,
        SelectedVideo(name: file.name, bytes: bytes),
      );
    } catch (exception) {
      debugPrint('Recording failed: $exception');
      if (mounted) {
        setState(() => error = cameraErrorMessage(exception));
      }
    } finally {
      stoppingRecording = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    frames?.cancel();
    recording = false;
    stoppingRecording = true;
    speechRestart?.cancel();
    unawaited(_stopListening(notify: false));
    source.dispose();
    unawaited(runOptionalTts(tts.stop));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentError = error;
    final landmarks = source.latestLandmarks;
    final imageSize = source.latestImageSize;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (source.preview != null)
              Center(
                child: AspectRatio(
                  aspectRatio: source.previewAspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      source.preview!,
                      if (landmarks != null && imageSize != null)
                        IgnorePointer(
                          child: CustomPaint(
                            painter: PosePainter(
                              landmarks: landmarks,
                              imageSize: imageSize,
                              mirror: source.isFrontCamera,
                              highlightFocus: widget.movementFocus,
                              highlightSide: widget.movementSide,
                              framingReady: source.framingReady,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              Center(
                child: currentError != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(currentError,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white)),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () {
                                    setState(() => busy = true);
                                    _initialize();
                                  },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Coba lagi'),
                          ),
                        ]))
                    : const CircularProgressIndicator(color: Colors.white),
              ),
            Positioned(
              top: 14,
              left: 14,
              child: IconButton.filledTonal(
                onPressed: recording ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: IconButton.filledTonal(
                tooltip: 'Ganti kamera',
                onPressed: recording
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await source.switchCamera();
                        } catch (exception) {
                          error = exception.toString();
                        }
                        if (mounted) setState(() => busy = false);
                      },
                icon: const Icon(Icons.cameraswitch_outlined),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              top: 76,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16)),
                child: Text(
                  recording
                      ? 'Merekam… lakukan minimal 4 repetisi penuh dengan tempo yang sama.'
                      : 'Diam 1–2 detik, lakukan gerakan, lalu kembali dan diam lagi di posisi awal.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (currentError != null && source.preview != null)
              Positioned(
                left: 18,
                right: 18,
                top: 142,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xdd9f3229),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(currentError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 120,
              child: Column(
                children: [
                  Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetricPill(
                          icon: source.framingReady
                              ? Icons.check_circle
                              : Icons.person_search,
                          label: source.framingReady
                              ? 'Framing siap'
                              : 'Seluruh tubuh harus terlihat',
                          ready: source.framingReady,
                        ),
                        _MetricPill(
                          icon: Icons.speed,
                          label:
                              '${source.processedFps.toStringAsFixed(0)} FPS · ${(source.poseConfidence * 100).round()}%',
                          ready: source.poseConfidence >= .55,
                        ),
                      ]),
                  const SizedBox(height: 8),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    children: [
                      _ColorLegend(color: Color(0xffd9f26a), label: 'Fokus'),
                      _ColorLegend(
                          color: Color(0xffffc857), label: 'Perbaiki framing'),
                      _ColorLegend(color: Colors.white54, label: 'Area lain'),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 34,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  button: true,
                  label: recording ? 'Selesai merekam' : 'Mulai merekam',
                  child: GestureDetector(
                    onTap: busy ? null : _toggle,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            recording ? const Color(0xffd3544d) : Colors.white,
                        border: Border.all(color: Colors.white54, width: 6),
                      ),
                      child: Icon(
                          recording
                              ? Icons.stop_rounded
                              : Icons.videocam_rounded,
                          color: recording
                              ? Colors.white
                              : const Color(0xff176b4b),
                          size: 32),
                    ),
                  ),
                ),
              ),
            ),
            if (recording)
              Positioned(
                left: 18,
                right: 18,
                bottom: 202,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        listening ? Icons.mic_rounded : Icons.mic_off_rounded,
                        color: listening
                            ? const Color(0xffd9f26a)
                            : Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        listening
                            ? 'Listening · Say “Stop recording”'
                            : speechInitialized && !speechAvailable
                                ? 'Voice control unavailable · Use the button'
                                : 'Starting voice control…',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ColorLegend extends StatelessWidget {
  const _ColorLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      );
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.ready,
  });

  final IconData icon;
  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: ready ? const Color(0xdd176b4b) : Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      );
}
