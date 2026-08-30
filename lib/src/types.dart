class Point2 {
  const Point2(this.x, this.y);
  final double x;
  final double y;

  Point2 operator -(Point2 other) => Point2(x - other.x, y - other.y);
  double get length => sqrtValue(x * x + y * y);
}

class HandFrame {
  const HandFrame({required this.side, required this.landmarks});
  final String side;
  final List<Point2> landmarks;
}

double sqrtValue(double value) {
  if (value <= 0) return 0;
  var guess = value > 1 ? value : 1.0;
  for (var i = 0; i < 12; i++) {
    guess = (guess + value / guess) / 2;
  }
  return guess;
}

class PoseFrame {
  const PoseFrame(
      {required this.landmarks,
      required this.visibility,
      required this.timestamp,
      this.extraFeatures = const {},
      this.hands = const []});
  final List<Point2> landmarks;
  final List<double> visibility;
  final Duration timestamp;
  final Map<String, double> extraFeatures;
  final List<HandFrame> hands;

  /// Converts MediaPipe normalized coordinates to pixels before angle math.
  /// This preserves geometry on non-square camera frames.
  factory PoseFrame.fromNormalized({
    required List<Point2> landmarks,
    required List<double> visibility,
    required double frameWidth,
    required double frameHeight,
    required Duration timestamp,
  }) =>
      PoseFrame(
        landmarks: landmarks
            .map((point) => Point2(point.x * frameWidth, point.y * frameHeight))
            .toList(growable: false),
        visibility: visibility,
        timestamp: timestamp,
        extraFeatures: const {},
        hands: const [],
      );

  void validate() {
    if (landmarks.length != 33 || visibility.length != 33) {
      throw ArgumentError(
          'MediaPipe PoseFrame harus memiliki 33 landmark dan visibility');
    }
  }
}

/// Implement this adapter with MediaPipe Tasks on Android/iOS.
abstract interface class PoseLandmarkSource {
  Stream<PoseFrame> get frames;
  bool get supportsHandTracking;
  Future<void> start();
  Future<void> stop();
}

enum JointColor { green, amber, red, gray }

class RepEvent {
  const RepEvent(
      {required this.rep,
      required this.peak,
      required this.duration,
      required this.hold});
  final int rep;
  final double peak;
  final Duration duration;
  final Duration hold;
}
