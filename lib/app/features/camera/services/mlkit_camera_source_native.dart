import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:motorix_phase2/motorix_phase2.dart';

import 'package:motorix_phase2/app/features/camera/services/camera_operation_queue.dart';

class MlKitCameraPoseSource implements PoseLandmarkSource {
  MlKitCameraPoseSource({
    this.enableHands = false,
    CameraLensDirection lensDirection = CameraLensDirection.back,
  }) : _lensDirection = lensDirection;

  final bool enableHands;
  final _frames = StreamController<PoseFrame>.broadcast();
  final detector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    ),
  );
  CameraController? controller;
  List<Point2>? latestLandmarks;
  List<double>? latestVisibility;
  List<HandFrame>? latestHands;
  Size? latestImageSize;
  bool isFrontCamera = true;
  CameraLensDirection _lensDirection;
  bool _busy = false;
  bool _started = false;
  final _operations = CameraOperationQueue();
  int _processedFrames = 0;
  DateTime _fpsWindow = DateTime.now();
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

  bool get framingReady {
    final points = latestLandmarks;
    final size = latestImageSize;
    if (points == null || size == null || poseConfidence < .55) return false;
    final visible = points.where((point) => point.x.isFinite).toList();
    if (visible.length < 20) return false;
    final xs = visible.map((point) => point.x);
    final ys = visible.map((point) => point.y);
    return xs.reduce((a, b) => a < b ? a : b) > size.width * .03 &&
        xs.reduce((a, b) => a > b ? a : b) < size.width * .97 &&
        ys.reduce((a, b) => a < b ? a : b) > size.height * .03 &&
        ys.reduce((a, b) => a > b ? a : b) < size.height * .97;
  }

  @override
  bool get supportsHandTracking => false;

  Widget? get preview {
    final current = controller;
    if (current == null || !current.value.isInitialized) return null;
    return CameraPreview(current);
  }

  double get previewAspectRatio {
    final size = latestImageSize;
    if (size != null && size.height > 0) return size.width / size.height;
    return controller?.value.aspectRatio ?? 9 / 16;
  }

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  Stream<PoseFrame> get frames => _frames.stream;

  @override
  Future<void> start() => _operations.run(_start);

  Future<void> _start() async {
    if (_started) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('Kamera tidak ditemukan');
    final description = cameras.firstWhere(
      (camera) => camera.lensDirection == _lensDirection,
      orElse: () => cameras.first,
    );
    isFrontCamera = description.lensDirection == CameraLensDirection.front;
    final imageFormat =
        Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;
    final nextController = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: imageFormat,
    );
    controller = nextController;
    try {
      await nextController.initialize();
      await nextController.startImageStream(_process);
      _started = true;
    } catch (_) {
      await nextController.dispose();
      controller = null;
      rethrow;
    }
  }

  Future<void> _process(CameraImage image) async {
    if (_busy || !_started) return;
    _busy = true;
    final stopwatch = Stopwatch()..start();
    try {
      final input = _inputImage(image);
      if (input == null) return;
      final poses = await detector.processImage(input.$1);
      if (poses.isEmpty) return;
      final pose = poses.first;
      final points = <Point2>[], visibility = <double>[];
      for (final type in PoseLandmarkType.values) {
        final landmark = pose.landmarks[type];
        points.add(landmark == null
            ? const Point2(double.nan, double.nan)
            : Point2(landmark.x, landmark.y));
        visibility.add(landmark?.likelihood ?? 0);
      }
      final previous = latestLandmarks;
      final smoothed = List<Point2>.generate(points.length, (index) {
        final point = points[index];
        if (!point.x.isFinite || visibility[index] < .45) {
          return const Point2(double.nan, double.nan);
        }
        if (previous == null || !previous[index].x.isFinite) return point;
        const alpha = .65;
        return Point2(
          previous[index].x + (point.x - previous[index].x) * alpha,
          previous[index].y + (point.y - previous[index].y) * alpha,
        );
      });
      latestLandmarks = smoothed;
      latestVisibility = visibility;
      latestImageSize = input.$2;
      _frames.add(PoseFrame(
        landmarks: smoothed,
        visibility: visibility,
        timestamp:
            Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
      ));
    } catch (error, stack) {
      debugPrint('Pose frame gagal: $error\n$stack');
    } finally {
      stopwatch.stop();
      overlayLatencyMs = overlayLatencyMs == 0
          ? stopwatch.elapsedMicroseconds / 1000
          : overlayLatencyMs * .8 + stopwatch.elapsedMicroseconds / 5000;
      _processedFrames++;
      final elapsed = DateTime.now().difference(_fpsWindow);
      if (elapsed >= const Duration(seconds: 1)) {
        processedFps = _processedFrames * 1000 / elapsed.inMilliseconds;
        _processedFrames = 0;
        _fpsWindow = DateTime.now();
      }
      _busy = false;
    }
  }

  Future<void> startRecording() async {
    final current = controller;
    if (current == null) throw StateError('Kamera belum siap');
    if (current.value.isStreamingImages) await current.stopImageStream();
    await current.startVideoRecording(onAvailable: _process);
  }

  Future<XFile> stopRecording() async {
    final current = controller;
    if (current == null) throw StateError('Kamera belum siap');
    final file = await current.stopVideoRecording();
    if (_started && !current.value.isStreamingImages) {
      await current.startImageStream(_process);
    }
    return file;
  }

  Future<void> switchCamera() => _operations.run(() async {
        if (controller?.value.isRecordingVideo ?? false) return;
        _lensDirection = _lensDirection == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front;
        await _stop();
        await _start();
      });

  (InputImage, Size)? _inputImage(CameraImage image) {
    final camera = controller?.description;
    final currentController = controller;
    if (camera == null ||
        currentController == null ||
        image.planes.length != 1) {
      return null;
    }
    final rotation = _rotation(camera, currentController);
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    final plane = image.planes.first;
    final input = InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
    final rotated = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    return (
      input,
      rotated
          ? Size(image.height.toDouble(), image.width.toDouble())
          : Size(image.width.toDouble(), image.height.toDouble())
    );
  }

  InputImageRotation? _rotation(
    CameraDescription camera,
    CameraController currentController,
  ) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }
    final compensation =
        _orientations[currentController.value.deviceOrientation];
    if (compensation == null) return null;
    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + compensation) % 360
        : (camera.sensorOrientation - compensation + 360) % 360;
    return InputImageRotationValue.fromRawValue(degrees);
  }

  @override
  Future<void> stop() => _operations.run(_stop);

  Future<void> _stop() async {
    if (!_started) return;
    _started = false;
    if (controller?.value.isRecordingVideo ?? false) {
      await controller?.stopVideoRecording();
    } else if (controller?.value.isStreamingImages ?? false) {
      await controller?.stopImageStream();
    }
    await controller?.dispose();
    controller = null;
  }

  Future<void> dispose() async {
    await stop();
    await detector.close();
    await _frames.close();
  }
}
