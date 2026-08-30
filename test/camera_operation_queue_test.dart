import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_phase2/app/features/camera/models/camera_errors.dart';
import 'package:motorix_phase2/app/features/camera/services/camera_operation_queue.dart';

void main() {
  test('camera operations execute in requested order', () async {
    final queue = CameraOperationQueue();
    final releaseStart = Completer<void>();
    final events = <String>[];

    final start = queue.run(() async {
      events.add('start');
      await releaseStart.future;
    });
    final stop = queue.run(() async => events.add('stop'));
    final restart = queue.run(() async => events.add('restart'));

    await Future<void>.delayed(Duration.zero);
    expect(events, ['start']);
    releaseStart.complete();
    await Future.wait([start, stop, restart]);
    expect(events, ['start', 'stop', 'restart']);
  });

  test('permission errors are actionable', () {
    expect(
      cameraErrorMessage(Exception('CameraAccessDeniedWithoutPrompt')),
      contains('Pengaturan perangkat'),
    );
    expect(
      cameraErrorMessage(Exception('NotAllowedError: Permission denied')),
      contains('Izin kamera belum diberikan'),
    );
    expect(
      cameraErrorMessage(Exception('NotReadableError')),
      contains('sedang digunakan'),
    );
  });
}
