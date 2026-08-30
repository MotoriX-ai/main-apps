import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_phase2/app/features/camera/presentations/pose_painter.dart';
import 'package:motorix_phase2/app/features/clinic/presentations/recipe_review_screen.dart';
import 'package:motorix_phase2/app/features/clinic/presentations/video_recorder_screen.dart';
import 'package:motorix_phase2/motorix_phase2.dart';

void main() {
  test('English stop command is normalized and consumed once', () {
    final gate = StopRecordingCommandGate();

    expect(gate.shouldStop('STOP recording!'), isTrue);
    expect(gate.shouldStop('Stop recording'), isFalse);

    gate.reset();
    expect(gate.shouldStop('Please stop recording'), isFalse);
    expect(gate.shouldStop('Finish recording'), isFalse);
  });

  test('speech availability failures keep manual recording available',
      () async {
    expect(
      await initializeOptionalSpeech(
        () => Future<bool>.error(Exception('microphone denied')),
      ),
      isFalse,
    );
  });

  test('framing cue waits and applies cooldown', () {
    final gate = FramingCueThrottle();
    final start = DateTime(2026);

    expect(gate.shouldSpeak(framingReady: false, recording: true, now: start),
        isFalse);
    expect(
        gate.shouldSpeak(
            framingReady: false,
            recording: true,
            now: start.add(const Duration(milliseconds: 1600))),
        isTrue);
    expect(
        gate.shouldSpeak(
            framingReady: false,
            recording: true,
            now: start.add(const Duration(seconds: 4))),
        isFalse);
    expect(
        gate.shouldSpeak(
            framingReady: false,
            recording: true,
            now: start.add(const Duration(seconds: 10))),
        isTrue);
  });

  testWidgets('recorder pose painter carries focus and framing state',
      (tester) async {
    final painter = PosePainter(
      landmarks: List.filled(33, const Point2(10, 10)),
      imageSize: const Size(100, 100),
      mirror: false,
      highlightFocus: 'knee',
      highlightSide: 'right',
      framingReady: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: CustomPaint(painter: painter, size: const Size(100, 100)),
    ));

    final rendered = tester.widget<CustomPaint>(find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is PosePainter,
    ));
    final renderedPainter = rendered.painter! as PosePainter;
    expect(renderedPainter.highlightFocus, 'knee');
    expect(renderedPainter.highlightSide, 'right');
    expect(renderedPainter.framingReady, isFalse);
  });

  testWidgets('review shows every pipeline quality indicator', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReviewQualityBars(quality: {
            'n_cycles_detected': 5,
            'n_cycles_used': 4,
            'mean_confidence': .8,
            'missing_frame_ratio': .1,
            'pc1_variance_ratio': .5,
            'snr_primary': 10.0,
            'phase_confidence': .7,
            'boundary_confidence': .6,
            'phase_anchor_confidence': .4,
          }),
        ),
      ),
    ));

    expect(find.byType(LinearProgressIndicator), findsNWidgets(8));
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('Konsistensi pose awal'), findsOneWidget);
  });

  testWidgets('missing and zero quality values remain reviewable',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReviewQualityBars(quality: {
            'n_cycles_detected': 0,
            'n_cycles_used': 0,
            'mean_confidence': 0.0,
          }),
        ),
      ),
    ));

    expect(find.text('0 / 0'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(6));
  });
}
