import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_phase2/app/features/camera/presentations/session_screen.dart';

void main() {
  test('camera startup continues when TTS initialization throws', () async {
    var cameraStarted = false;

    await startCameraWithOptionalTts(
      initializeTts: () =>
          Future<void>.error(UnsupportedError('speech unavailable')),
      startCamera: () async => cameraStarted = true,
    );

    expect(cameraStarted, isTrue);
  });

  test('replacement TTS stops the previous utterance before speaking',
      () async {
    final calls = <String>[];

    await speakOptionalTts(
      stop: () async => calls.add('stop'),
      speak: () async => calls.add('speak'),
    );

    expect(calls, ['stop', 'speak']);
  });

  test('replacement TTS still speaks when stop fails', () async {
    var spoke = false;

    await speakOptionalTts(
      stop: () => Future<void>.error(Exception('unavailable')),
      speak: () async => spoke = true,
    );

    expect(spoke, isTrue);
  });
}
