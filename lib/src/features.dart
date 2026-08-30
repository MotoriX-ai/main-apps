import 'dart:math' as math;

import 'types.dart';

const featureNames = <String>[
  'knee_flex_L',
  'knee_flex_R',
  'hip_flex_L',
  'hip_flex_R',
  'ankle_dorsi_L',
  'ankle_dorsi_R',
  'shoulder_elev_L',
  'shoulder_elev_R',
  'elbow_flex_L',
  'elbow_flex_R',
  'trunk_incline',
  'head_yaw',
  'head_pitch',
  'head_roll',
  'shoulder_hike_L',
  'shoulder_hike_R',
  'stance_width',
  'view_ratio',
  'pelvis_shift',
  'wrist_flex_L',
  'wrist_flex_R',
  'curl_thumb_L',
  'curl_thumb_R',
  'curl_index_L',
  'curl_index_R',
  'curl_middle_L',
  'curl_middle_R',
  'curl_ring_L',
  'curl_ring_R',
  'curl_pinky_L',
  'curl_pinky_R',
  'hand_spread_L',
  'hand_spread_R',
];

const _index = <String, int>{
  'sho_l': 11,
  'sho_r': 12,
  'elb_l': 13,
  'elb_r': 14,
  'wri_l': 15,
  'wri_r': 16,
  'nose': 0,
  'eye_l': 2,
  'eye_r': 5,
  'ear_l': 7,
  'ear_r': 8,
  'hip_l': 23,
  'hip_r': 24,
  'knee_l': 25,
  'knee_r': 26,
  'ank_l': 27,
  'ank_r': 28,
  'foot_l': 31,
  'foot_r': 32,
};

double angleAt(Point2 a, Point2 b, Point2 c) {
  final v1 = a - b;
  final v2 = c - b;
  final n1 = v1.length;
  final n2 = v2.length;
  if (n1 < 1e-6 || n2 < 1e-6) return double.nan;
  final cosine = ((v1.x * v2.x + v1.y * v2.y) / (n1 * n2)).clamp(-1.0, 1.0);
  return math.acos(cosine) * 180 / math.pi;
}

double angleVertical(Point2 a, Point2 b) {
  final vector = b - a;
  return math.atan2(vector.x, -vector.y) * 180 / math.pi;
}

Map<String, double> featuresFromPose(PoseFrame frame,
    {double visibilityThreshold = 0.35}) {
  frame.validate();
  final result = <String, double>{
    for (final name in featureNames) name: double.nan,
    ...frame.extraFeatures,
  };
  Point2? point(String name) {
    final i = _index[name];
    if (i == null || i >= frame.visibility.length || i >= frame.landmarks.length) {
      return null;
    }
    return frame.visibility[i] >= visibilityThreshold
        ? frame.landmarks[i]
        : null;
  }

  double angle(String a, String b, String c,
      {double offset = 0, bool invert = false}) {
    final pa = point(a), pb = point(b), pc = point(c);
    if (pa == null || pb == null || pc == null) return double.nan;
    final value = angleAt(pa, pb, pc);
    return (invert ? 180 - value : value) + offset;
  }

  final leftShoulder = point('sho_l'), rightShoulder = point('sho_r');
  final leftHip = point('hip_l'), rightHip = point('hip_r');
  if (leftShoulder == null ||
      rightShoulder == null ||
      leftHip == null ||
      rightHip == null) {
    return result;
  }
  final midShoulder = Point2((leftShoulder.x + rightShoulder.x) / 2,
      (leftShoulder.y + rightShoulder.y) / 2);
  final midHip =
      Point2((leftHip.x + rightHip.x) / 2, (leftHip.y + rightHip.y) / 2);
  final torso = (midShoulder - midHip).length;
  if (torso < 1e-6) return result;
  for (final side in ['l', 'r']) {
    final suffix = side.toUpperCase();
    result['knee_flex_$suffix'] =
        angle('hip_$side', 'knee_$side', 'ank_$side', invert: true);
    result['hip_flex_$suffix'] =
        angle('sho_$side', 'hip_$side', 'knee_$side', invert: true);
    result['ankle_dorsi_$suffix'] =
        angle('knee_$side', 'ank_$side', 'foot_$side', offset: -90);
    result['shoulder_elev_$suffix'] =
        angle('hip_$side', 'sho_$side', 'elb_$side');
    result['elbow_flex_$suffix'] =
        angle('sho_$side', 'elb_$side', 'wri_$side', invert: true);
    final shoulder = side == 'l' ? leftShoulder : rightShoulder;
    final hip = side == 'l' ? leftHip : rightHip;
    result['shoulder_hike_$suffix'] = (hip.y - shoulder.y) / torso;
  }
  result['trunk_incline'] = angleVertical(midHip, midShoulder);
  final nose = point('nose');
  final leftEye = point('eye_l'), rightEye = point('eye_r');
  final leftEar = point('ear_l'), rightEar = point('ear_r');
  if (nose != null &&
      leftEye != null &&
      rightEye != null &&
      leftEar != null &&
      rightEar != null) {
    final earMid =
        Point2((leftEar.x + rightEar.x) / 2, (leftEar.y + rightEar.y) / 2);
    final eyeMid =
        Point2((leftEye.x + rightEye.x) / 2, (leftEye.y + rightEye.y) / 2);
    final earSpan = (rightEar - leftEar).length;
    if (earSpan > 1e-6) {
      result['head_yaw'] = (nose.x - earMid.x) / earSpan * 60;
      result['head_pitch'] = (nose.y - eyeMid.y) / earSpan * 60;
      result['head_roll'] =
          math.atan2(rightEar.y - leftEar.y, rightEar.x - leftEar.x) *
              180 /
              math.pi;
    }
  }
  final leftAnkle = point('ank_l'), rightAnkle = point('ank_r');
  result['stance_width'] = leftAnkle == null || rightAnkle == null
      ? double.nan
      : (leftAnkle.x - rightAnkle.x).abs() / torso;
  result['view_ratio'] = (leftShoulder - rightShoulder).length / torso;
  result['pelvis_shift'] = (midHip.x - midShoulder.x) / torso;
  return result;
}
