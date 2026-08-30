import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:motorix_phase2/motorix_phase2.dart';
import 'package:web/web.dart' as web;

import 'package:motorix_phase2/app/features/camera/services/camera_operation_queue.dart';

@JS('motorixPose.start')
external JSPromise<JSAny?> _startPose(
  web.HTMLVideoElement video,
  JSBoolean enableHands,
  JSFunction onResult,
);

@JS('motorixPose')
external JSObject? get _motorixPose;

@JS('motorixPose.stop')
external void _stopPose(web.HTMLVideoElement video);

@JS('motorixPose.startRecording')
external void _startWebRecording(web.HTMLVideoElement video);

@JS('motorixPose.stopRecording')
external JSPromise<_WebRecording> _stopWebRecording(web.HTMLVideoElement video);

extension type _WebRecording(JSObject _) implements JSObject {
  external JSUint8Array get bytes;
  external JSString get mimeType;
}

class MlKitCameraPoseSource implements PoseLandmarkSource {
  MlKitCameraPoseSource({this.enableHands = false}) {
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId, {Object? params}) => _video,
    );
  }

  static int _nextId = 0;
  final bool enableHands;
  final String _viewType = 'motorix-camera-${_nextId++}';
  final _frames = StreamController<PoseFrame>.broadcast();
  final web.HTMLVideoElement _video = web.HTMLVideoElement()
    ..autoplay = true
    ..muted = true
    ..playsInline = true
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'contain'
    ..style.backgroundColor = 'black';

  List<Point2>? latestLandmarks;
  List<double>? latestVisibility;
  List<HandFrame>? latestHands;
  Size? latestImageSize;
  bool isFrontCamera = true;
  bool _started = false;
  final _operations = CameraOperationQueue();
  double processedFps = 0;
  double overlayLatencyMs = 0;

  double get poseConfidence {
    final visibility = latestVisibility;
    if (visibility == null || visibility.length < 25) return 0;
    return [11, 12, 23, 24]
            .map((index) => visibility[index])
            .reduce((a, b) => a + b) /
        4;
  }

  bool get framingReady => poseConfidence >= .55;

  @override
  bool get supportsHandTracking => true;

  Object? get controller => _started ? _video : null;
  Widget? get preview => _started ? HtmlElementView(viewType: _viewType) : null;
  double get previewAspectRatio {
    final size = latestImageSize;
    return size == null || size.height == 0 ? 9 / 16 : size.width / size.height;
  }

  @override
  Stream<PoseFrame> get frames => _frames.stream;

  @override
  Future<void> start() => _operations.run(_start);

  Future<void> _start() async {
    if (_started) return;
    if (_motorixPose == null) {
      throw UnsupportedError('Browser tidak dapat memuat modul kamera.');
    }
    _started = true;
    try {
      await _startPose(
        _video,
        enableHands.toJS,
        ((JSString payload) {
          final data = jsonDecode(payload.toDart) as Map<String, dynamic>;
          final width = (data['width'] as num).toDouble();
          final height = (data['height'] as num).toDouble();
          final raw = data['landmarks'] as List<dynamic>;
          if (raw.length != 33 || width <= 0 || height <= 0) return;
          final points = <Point2>[];
          final visibility = <double>[];
          for (final item in raw) {
            final landmark = item as Map<String, dynamic>;
            points.add(Point2(
              (landmark['x'] as num).toDouble() * width,
              (landmark['y'] as num).toDouble() * height,
            ));
            visibility.add(((landmark['visibility'] as num?) ?? 0).toDouble());
          }
          latestLandmarks = points;
          latestVisibility = visibility;
          latestImageSize = Size(width, height);
          final hands = <HandFrame>[];
          for (final rawHand in data['hands'] as List<dynamic>? ?? const []) {
            final hand = rawHand as Map<String, dynamic>;
            final handPoints = <Point2>[];
            for (final rawPoint in hand['landmarks'] as List<dynamic>) {
              final point = rawPoint as Map<String, dynamic>;
              handPoints.add(Point2(
                (point['x'] as num).toDouble() * width,
                (point['y'] as num).toDouble() * height,
              ));
            }
            if (handPoints.length == 21) {
              hands.add(HandFrame(
                side: hand['side'] as String,
                landmarks: handPoints,
              ));
            }
          }
          latestHands = hands;
          if (!_frames.isClosed) {
            _frames.add(PoseFrame(
              landmarks: points,
              visibility: visibility,
              timestamp: Duration(
                milliseconds: (data['timestamp'] as num).round(),
              ),
              extraFeatures: ((data['handFeatures'] as Map<String, dynamic>?) ??
                      const {})
                  .map(
                      (key, value) => MapEntry(key, (value as num).toDouble())),
              hands: hands,
            ));
          }
        }).toJS,
      ).toDart;
    } catch (_) {
      _started = false;
      rethrow;
    }
  }

  @override
  Future<void> stop() => _operations.run(_stop);

  Future<void> _stop() async {
    if (!_started) return;
    _started = false;
    _stopPose(_video);
  }

  Future<void> startRecording() async {
    if (!_started) throw StateError('Kamera belum siap');
    _startWebRecording(_video);
  }

  Future<XFile> stopRecording() async {
    final recording = await _stopWebRecording(_video).toDart;
    final Uint8List bytes = recording.bytes.toDart;
    return XFile.fromData(
      bytes,
      mimeType: recording.mimeType.toDart,
      name: 'demonstrasi-${DateTime.now().millisecondsSinceEpoch}.webm',
    );
  }

  Future<void> switchCamera() async =>
      throw UnsupportedError('Ganti kamera tersedia di Android/iOS.');

  Future<void> dispose() async {
    await stop();
    await _frames.close();
  }
}
