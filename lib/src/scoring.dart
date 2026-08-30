import 'dart:math' as math;

import 'recipe.dart';

class RepScore {
  const RepScore({
    required this.total,
    required this.form,
    required this.rom,
    required this.tempo,
    required this.compensation,
    required this.jointError,
    this.offender,
  });

  final double total;
  final double form;
  final double rom;
  final double tempo;
  final double compensation;
  final String? offender;
  final Map<String, double> jointError;
}

RepScore scoreRepetition(
  List<Map<String, double>> frames,
  ExerciseRecipe recipe,
  double durationSeconds,
) {
  final sample = _resample(frames, recipe.tracked, recipe.templateLength);
  final path = _dtwPath(sample, recipe);
  final jointError = <String, double>{};
  final formErrors = <double>[];
  for (final joint in recipe.primary) {
    final errors = <double>[];
    final templateList = recipe.template[joint];
    final toleranceList = recipe.tolerance[joint];
    if (templateList == null || toleranceList == null) continue;
    for (final pair in path) {
      if (pair.$1 >= sample.length) continue;
      final actual = sample[pair.$1][joint];
      if (actual == null || !actual.isFinite) continue;
      if (pair.$2 >= toleranceList.length || pair.$2 >= templateList.length) {
        continue;
      }
      final tolerance = math.max(toleranceList[pair.$2], 1e-6);
      errors.add((actual - templateList[pair.$2]).abs() / tolerance);
    }
    if (errors.isNotEmpty) {
      final mean = errors.reduce((a, b) => a + b) / errors.length;
      jointError[joint] = mean;
      formErrors.addAll(errors);
    }
  }
  final form = formErrors.isEmpty
      ? 0.0
      : 100 * math.exp(-formErrors.reduce((a, b) => a + b) / formErrors.length);

  final romRatios = <double>[];
  for (final joint in recipe.primary) {
    final values = sample
        .map((row) => row[joint] ?? double.nan)
        .where((v) => v.isFinite)
        .toList();
    if (values.isEmpty) continue;
    final achieved = values.reduce(math.max) - values.reduce(math.min);
    final targetValues = recipe.template[joint];
    if (targetValues == null || targetValues.isEmpty) continue;
    final target =
        (targetValues.reduce(math.max) - targetValues.reduce(math.min)) *
            recipe.progressionFactor;
    if (target > 1e-6) romRatios.add(math.min(1, achieved / target));
  }
  final rom = romRatios.isEmpty
      ? 0.0
      : 100 * romRatios.reduce((a, b) => a + b) / romRatios.length;
  final tempo = 100 *
      math.exp(-math
          .log(math.max(durationSeconds, 1e-3) / recipe.cycleSeconds)
          .abs());

  String? offender;
  var worstRatio = 0.0;
  for (final joint in recipe.guard) {
    var used = 0, violations = 0;
    final templateList = recipe.template[joint];
    final toleranceList = recipe.tolerance[joint];
    if (templateList == null || toleranceList == null) continue;
    for (var i = 0; i < sample.length; i++) {
      final value = sample[i][joint];
      if (value == null || !value.isFinite) continue;
      if (i >= templateList.length || i >= toleranceList.length) continue;
      used++;
      if ((value - templateList[i]).abs() > 2.5 * toleranceList[i]) {
        violations++;
      }
    }
    final ratio = used == 0 ? 0.0 : violations / used;
    if (ratio > worstRatio) {
      worstRatio = ratio;
      offender = joint;
    }
  }
  if (worstRatio < .1) offender = null;
  final compensation = 100 * (1 - worstRatio);
  final total = .45 * form + .25 * rom + .15 * tempo + .15 * compensation;
  return RepScore(
    total: total.clamp(0, 100),
    form: form.clamp(0, 100),
    rom: rom.clamp(0, 100),
    tempo: tempo.clamp(0, 100),
    compensation: compensation.clamp(0, 100),
    offender: offender,
    jointError: Map.unmodifiable(jointError),
  );
}

List<Map<String, double>> _resample(
  List<Map<String, double>> frames,
  List<String> joints,
  int length,
) {
  if (frames.length < 2) {
    return List.generate(
        length, (_) => {for (final joint in joints) joint: double.nan});
  }
  return List.generate(length, (index) {
    final position = index * (frames.length - 1) / (length - 1);
    final lower = position.floor(), upper = position.ceil();
    final fraction = position - lower;
    return {
      for (final joint in joints)
        joint:
            _interpolate(frames[lower][joint], frames[upper][joint], fraction),
    };
  });
}

double _interpolate(double? a, double? b, double fraction) {
  if (a == null || b == null || !a.isFinite || !b.isFinite) return double.nan;
  return a * (1 - fraction) + b * fraction;
}

List<(int, int)> _dtwPath(
  List<Map<String, double>> sample,
  ExerciseRecipe recipe,
) {
  final n = sample.length, m = recipe.templateLength;
  final costs =
      List.generate(n + 1, (_) => List.filled(m + 1, double.infinity));
  costs[0][0] = 0;
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      var distance = 0.0, used = 0;
      for (final joint in recipe.primary) {
        final actual = sample[i - 1][joint];
        if (actual == null || !actual.isFinite) continue;
        final toleranceList = recipe.tolerance[joint];
        final templateList = recipe.template[joint];
        if (toleranceList == null || templateList == null) continue;
        if (j - 1 >= toleranceList.length || j - 1 >= templateList.length) {
          continue;
        }
        final tolerance = math.max(toleranceList[j - 1], 1e-6);
        final delta = (actual - templateList[j - 1]) / tolerance;
        distance += delta * delta;
        used++;
      }
      if (used == 0) continue;
      costs[i][j] = distance / used +
          math.min(
              costs[i - 1][j - 1], math.min(costs[i - 1][j], costs[i][j - 1]));
    }
  }
  var i = n, j = m;
  final path = <(int, int)>[];
  while (i > 0 && j > 0) {
    path.add((i - 1, j - 1));
    final diagonal = costs[i - 1][j - 1];
    final up = costs[i - 1][j];
    final left = costs[i][j - 1];
    if (diagonal <= up && diagonal <= left) {
      i--;
      j--;
    } else if (up <= left) {
      i--;
    } else {
      j--;
    }
  }
  return path.reversed.toList(growable: false);
}
