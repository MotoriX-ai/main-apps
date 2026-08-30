import 'package:flutter/material.dart';
import 'package:motorix_phase2/motorix_phase2.dart';

class PosePainter extends CustomPainter {
  PosePainter({
    required this.landmarks,
    required this.imageSize,
    required this.mirror,
    this.feedback,
    this.hands = const [],
    this.highlightFocus,
    this.highlightSide = 'auto',
    this.framingReady = true,
  });

  final List<Point2> landmarks;
  final Size imageSize;
  final bool mirror;
  final FrameFeedback? feedback;
  final List<HandFrame> hands;
  final String? highlightFocus;
  final String highlightSide;
  final bool framingReady;

  static const _focusGreen = Color(0xffd9f26a);

  static const bones = <(int, int)>[
    (11, 12),
    (11, 23),
    (12, 24),
    (23, 24),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
    (23, 25),
    (25, 27),
    (27, 29),
    (29, 31),
    (24, 26),
    (26, 28),
    (28, 30),
    (30, 32),
  ];

  static const handBones = <(int, int)>[
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (0, 5),
    (5, 6),
    (6, 7),
    (7, 8),
    (0, 9),
    (9, 10),
    (10, 11),
    (11, 12),
    (0, 13),
    (13, 14),
    (14, 15),
    (15, 16),
    (0, 17),
    (17, 18),
    (18, 19),
    (19, 20),
    (5, 9),
    (9, 13),
    (13, 17),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / imageSize.width)
        .clamp(0.0, size.height / imageSize.height);
    final shownWidth = imageSize.width * scale;
    final shownHeight = imageSize.height * scale;
    final dx = (size.width - shownWidth) / 2;
    final dy = (size.height - shownHeight) / 2;
    Offset map(Point2 point) {
      final x = mirror ? imageSize.width - point.x : point.x;
      return Offset(dx + x * scale, dy + point.y * scale);
    }

    for (final bone in bones) {
      final a = landmarks[bone.$1], b = landmarks[bone.$2];
      if (!a.x.isFinite || !b.x.isFinite) continue;
      final color = _stronger(_bodyColor(bone.$1), _bodyColor(bone.$2));
      _drawHeatLine(canvas, map(a), map(b), color, 3);
    }
    for (var i = 0; i < landmarks.length; i++) {
      final point = landmarks[i];
      if (!point.x.isFinite) continue;
      _drawHeatPoint(canvas, map(point), _bodyColor(i), i >= 23 ? 6 : 4);
    }
    for (final hand in hands) {
      if (hand.landmarks.length < 21) continue;
      for (final bone in handBones) {
        final a = hand.landmarks[bone.$1], b = hand.landmarks[bone.$2];
        if (!a.x.isFinite || !b.x.isFinite) continue;
        final color = _handColor(hand.side, bone.$2);
        _drawHeatLine(canvas, map(a), map(b), color, 4);
      }
      for (var i = 0; i < hand.landmarks.length; i++) {
        final point = hand.landmarks[i];
        if (!point.x.isFinite) continue;
        _drawHeatPoint(canvas, map(point), _handColor(hand.side, i), 5);
      }
    }
  }

  Color _bodyColor(int index) {
    if (feedback == null && highlightFocus != null) {
      if (!_bodyHighlighted(index)) return Colors.white54;
      return framingReady ? _focusGreen : const Color(0xffffc857);
    }
    String? feature;
    if (index <= 10) feature = 'head_yaw';
    if (index == 15) feature = 'wrist_flex_L';
    if (index == 16) feature = 'wrist_flex_R';
    if (index == 25) feature = 'knee_flex_L';
    if (index == 26) feature = 'knee_flex_R';
    if (index == 27 || index == 29 || index == 31) {
      feature = 'ankle_dorsi_L';
    }
    if (index == 28 || index == 30 || index == 32) {
      feature = 'ankle_dorsi_R';
    }
    if (index == 23) feature = 'hip_flex_L';
    if (index == 24) feature = 'hip_flex_R';
    if (index == 13) feature = 'elbow_flex_L';
    if (index == 14) feature = 'elbow_flex_R';
    if (index == 11) feature = 'shoulder_elev_L';
    if (index == 12) feature = 'shoulder_elev_R';
    return _tempoColor(feature);
  }

  Color _handColor(String side, int index) {
    if (feedback == null && highlightFocus != null) {
      final focus = highlightFocus;
      final highlighted = const {
            'auto',
            'full_body',
            'wrist_hand',
            'fingers',
          }.contains(focus) &&
          _handSideMatches(side);
      if (!highlighted) return Colors.white54;
      return framingReady ? _focusGreen : const Color(0xffffc857);
    }
    final suffix = side.toUpperCase().startsWith('L') ? 'L' : 'R';
    final stem = switch (index) {
      >= 1 && <= 4 => 'curl_thumb',
      >= 5 && <= 8 => 'curl_index',
      >= 9 && <= 12 => 'curl_middle',
      >= 13 && <= 16 => 'curl_ring',
      >= 17 && <= 20 => 'curl_pinky',
      _ => 'hand_spread',
    };
    var value = feedback?.tempoColors['${stem}_$suffix'];
    if (value == null || value == JointColor.gray) {
      final opposite = suffix == 'L' ? 'R' : 'L';
      value = feedback?.tempoColors['${stem}_$opposite'];
    }
    return _paintColor(value);
  }

  Color _tempoColor(String? feature) {
    final value = feature == null ? null : feedback?.tempoColors[feature];
    return _paintColor(value);
  }

  Color _paintColor(JointColor? value) {
    return switch (value) {
      JointColor.green => Colors.white,
      JointColor.amber => const Color(0xffffc857),
      JointColor.red => const Color(0xffff4d4d),
      JointColor.gray => Colors.white70,
      null => Colors.white,
    };
  }

  Color _stronger(Color a, Color b) {
    const red = Color(0xffff4d4d), yellow = Color(0xffffc857);
    if (a == red || b == red) return red;
    if (a == yellow || b == yellow) return yellow;
    if (a == _focusGreen || b == _focusGreen) return _focusGreen;
    return Colors.white.withValues(alpha: .78);
  }

  bool _bodyHighlighted(int index) {
    final focus = highlightFocus;
    final inRegion = switch (focus) {
      'head_neck' => index <= 12,
      'shoulder' => index >= 11 && index <= 14,
      'arm_elbow' => index >= 11 && index <= 16,
      'wrist_hand' || 'fingers' => index == 15 || index == 16,
      'trunk' => const {11, 12, 23, 24}.contains(index),
      'hip_thigh' => index >= 23 && index <= 26,
      'knee' => index >= 23 && index <= 28,
      'ankle_foot' => index >= 25,
      'leg' => index >= 23,
      _ => true,
    };
    if (!inRegion || highlightSide == 'auto' || highlightSide == 'bilateral') {
      return inRegion;
    }
    if (index <= 10) return true;
    final isLeft = index.isOdd;
    return highlightSide == 'left' ? isLeft : !isLeft;
  }

  bool _handSideMatches(String side) {
    if (highlightSide == 'auto' || highlightSide == 'bilateral') return true;
    final isLeft = side.toUpperCase().startsWith('L');
    return highlightSide == 'left' ? isLeft : !isLeft;
  }

  void _drawHeatLine(
      Canvas canvas, Offset a, Offset b, Color color, double width) {
    if (color != Colors.white && color != Colors.white70) {
      canvas.drawLine(
          a,
          b,
          Paint()
            ..color = color.withValues(alpha: .26)
            ..strokeWidth = width + 10
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round);
  }

  void _drawHeatPoint(Canvas canvas, Offset point, Color color, double radius) {
    if (color != Colors.white && color != Colors.white70) {
      canvas.drawCircle(
          point, radius + 7, Paint()..color = color.withValues(alpha: .25));
    }
    canvas.drawCircle(point, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}
