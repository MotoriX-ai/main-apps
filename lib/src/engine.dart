import 'dart:math' as math;

import 'filter.dart';
import 'recipe.dart';
import 'scoring.dart';
import 'types.dart';

enum RepState { idle, ascending, top, descending }

class RepCounter {
  RepCounter(List<double> template, this.progressionFactor,
      {this.fps = 30, this.minimumRepFrames = 12}) {
    final edge = math.max(2, (template.length * .08).round());
    final baselineValues = [
      ...template.take(edge),
      ...template.skip(math.max(0, template.length - edge)),
    ]..sort();
    base = _percentile(baselineValues, .5);
    final farthest =
        template.reduce((a, b) => (a - base).abs() >= (b - base).abs() ? a : b);
    direction = farthest >= base ? 1 : -1;
    final displacement = template
        .map((value) => direction * (value - base))
        .where((value) => value.isFinite)
        .toList()
      ..sort();
    low = _percentile(displacement, .2) * progressionFactor;
    high = _percentile(displacement, .8) * progressionFactor;
    if (high - low < 1e-3) high = low + 1;
    peak = 0;
  }
  final double progressionFactor;
  final double fps;
  final int minimumRepFrames;
  late double base, low, high, peak;
  late int direction;
  RepState state = RepState.idle;
  int count = 0, frame = 0, topFrames = 0;
  int? startFrame;

  static double _percentile(List<double> sorted, double percentile) {
    final position = (sorted.length - 1) * percentile;
    final lower = position.floor(), upper = position.ceil();
    if (lower == upper) return sorted[lower];
    final fraction = position - lower;
    return sorted[lower] * (1 - fraction) + sorted[upper] * fraction;
  }

  RepEvent? update(double angle) {
    frame++;
    if (!angle.isFinite) return null;
    final oriented = direction * (angle - base);
    switch (state) {
      case RepState.idle:
        if (oriented > low) {
          state = RepState.ascending;
          peak = oriented;
          startFrame = frame;
          topFrames = 0;
        }
        break;
      case RepState.ascending:
        peak = math.max(peak, oriented);
        if (oriented > high) {
          state = RepState.top;
        } else if (oriented < low) {
          state = RepState.idle;
          startFrame = null;
        }
        break;
      case RepState.top:
        peak = math.max(peak, oriented);
        topFrames++;
        if (oriented < high) state = RepState.descending;
        break;
      case RepState.descending:
        if (oriented > high) {
          state = RepState.top;
          break;
        }
        if (oriented < low) {
          final frames = frame - (startFrame ?? frame);
          state = RepState.idle;
          final event = frames >= minimumRepFrames
              ? RepEvent(
                  rep: ++count,
                  peak: base + direction * peak,
                  duration:
                      Duration(milliseconds: (frames / fps * 1000).round()),
                  hold:
                      Duration(milliseconds: (topFrames / fps * 1000).round()))
              : null;
          peak = 0;
          startFrame = null;
          topFrames = 0;
          return event;
        }
        break;
    }
    return null;
  }

  double get progress =>
      ((peak - low) / math.max(high - low, 1e-6)).clamp(0, 1);
}

class PhaseTracker {
  PhaseTracker(this.recipe, {this.maximumAdvance = 3})
      : weights = _weights(recipe),
        costs = List.filled(recipe.templateLength, 0);
  final ExerciseRecipe recipe;
  final int maximumAdvance;
  final Map<String, double> weights;
  List<double> costs;
  bool started = false;
  int phase = 0;

  static Map<String, double> _weights(ExerciseRecipe recipe) {
    final raw = <String, double>{};
    for (final name in recipe.tracked) {
      final tolerance = recipe.tolerance[name];
      if (tolerance == null || tolerance.isEmpty) continue;
      final mean = tolerance.reduce((a, b) => a + b) / tolerance.length;
      raw[name] = 1 / (mean * mean + 1e-6);
    }
    if (raw.isEmpty) return const {};
    final total = raw.values.reduce((a, b) => a + b);
    return raw.map((key, value) => MapEntry(key, value / total));
  }

  int update(Map<String, double> features) {
    final distance = List<double>.generate(recipe.templateLength, (index) {
      var value = 0.0, used = false;
      for (final name in recipe.tracked) {
        final actual = features[name];
        if (actual == null || !actual.isFinite) continue;
        final templateList = recipe.template[name];
        final weight = weights[name];
        if (templateList == null ||
            index >= templateList.length ||
            weight == null) {
          continue;
        }
        final delta = actual - templateList[index];
        value += weight * delta * delta;
        used = true;
      }
      return used ? value : double.infinity;
    });
    if (!started) {
      costs = [...distance];
      started = true;
    } else {
      final next = List.filled(recipe.templateLength, double.infinity);
      for (var j = 0; j < recipe.templateLength; j++) {
        var best = double.infinity;
        for (var k = 0; k <= maximumAdvance; k++) {
          final previous = (j - k) % recipe.templateLength;
          best = math.min(best, costs[previous] * .9);
        }
        next[j] = distance[j] + best;
      }
      final minimum = next.reduce((a, b) => math.min(a, b));
      costs = next.map((value) => value - minimum).toList();
    }
    phase = costs.indexOf(costs.reduce((a, b) => math.min(a, b)));
    return phase;
  }
}

class FrameFeedback {
  const FrameFeedback(
      {required this.repCount,
      required this.repState,
      required this.phase,
      required this.progress,
      required this.colors,
      required this.deviation,
      required this.tempoColors,
      required this.tempoRatio,
      this.cue,
      this.completedRep,
      this.completedScore});
  final int repCount;
  final RepState repState;
  final int phase;
  final double progress;
  final Map<String, JointColor> colors;
  final Map<String, double> deviation;
  final Map<String, JointColor> tempoColors;
  final Map<String, double> tempoRatio;
  final String? cue;
  final RepEvent? completedRep;
  final RepScore? completedScore;
}

class PhysioRuntime {
  PhysioRuntime(this.recipe, {double fps = 30})
      : filters = FeatureFilterBank(recipe.tracked, frequency: fps),
        counter = RepCounter(
            recipe.template[recipe.primary.first] ?? const [0.0],
            recipe.progressionFactor,
            fps: fps),
        tracker = PhaseTracker(recipe),
        fps = fps;
  final ExerciseRecipe recipe;
  final FeatureFilterBank filters;
  final RepCounter counter;
  final PhaseTracker tracker;
  final double fps;
  final Map<String, int> _streak = {};
  final Map<String, double> _previous = {};
  final Map<String, double> _tempoTravel = {};
  final Map<String, int> _tempoSamples = {};
  int _frame = 0, _lastCueFrame = -100000;
  final List<Map<String, double>> _cycle = [];

  FrameFeedback update(Map<String, double> rawFeatures) {
    _frame++;
    final features = filters(rawFeatures);
    final previousState = counter.state;
    final wasActive = counter.state != RepState.idle;
    final primaryJoint = recipe.primary.firstOrNull;
    final event = counter.update(primaryJoint == null
        ? double.nan
        : (features[primaryJoint] ?? double.nan));
    final isActive = counter.state != RepState.idle;
    if (!wasActive && isActive) {
      _tempoTravel.clear();
      _tempoSamples.clear();
      _cycle
        ..clear()
        ..add(Map.of(features));
    } else if (wasActive) {
      _cycle.add(Map.of(features));
    }
    RepScore? score;
    if (event != null) {
      score =
          scoreRepetition(_cycle, recipe, event.duration.inMilliseconds / 1000);
      _cycle.clear();
    } else if (wasActive && !isActive) {
      _cycle.clear();
    }
    final phase = tracker.update(features);
    final colors = <String, JointColor>{}, deviation = <String, double>{};
    for (final name in recipe.tracked) {
      final actual = features[name];
      if (actual == null || !actual.isFinite) {
        colors[name] = JointColor.gray;
        _streak[name] = 0;
        continue;
      }
      final templateList = recipe.template[name];
      final toleranceList = recipe.tolerance[name];
      if (templateList == null ||
          toleranceList == null ||
          phase >= templateList.length ||
          phase >= toleranceList.length) {
        colors[name] = JointColor.gray;
        _streak[name] = 0;
        continue;
      }
      final normalized = (actual - templateList[phase]).abs() /
          math.max(toleranceList[phase], 1e-6);
      deviation[name] = normalized;
      colors[name] = normalized <= 1
          ? JointColor.green
          : normalized <= 2.5
              ? JointColor.amber
              : JointColor.red;
      _streak[name] = normalized > 2.5 ? (_streak[name] ?? 0) + 1 : 0;
    }
    final tempoColors = <String, JointColor>{};
    final tempoRatio = <String, double>{};
    final tempoActive = wasActive || isActive;
    for (final name in recipe.tracked) {
      tempoColors[name] = JointColor.gray;
      if (!recipe.primary.contains(name) || !tempoActive) continue;
      final actual = features[name];
      final previous = _previous[name];
      if (actual == null ||
          previous == null ||
          !actual.isFinite ||
          !previous.isFinite) {
        continue;
      }
      _tempoTravel[name] =
          (_tempoTravel[name] ?? 0) + (actual - previous).abs();
      _tempoSamples[name] = (_tempoSamples[name] ?? 0) + 1;
      final samples = _tempoSamples[name] ?? 0;
      if (samples < 5) continue;
      final actualAverage = (_tempoTravel[name] ?? 0.0) / (samples / fps);
      final targetAverage = _targetAverageSpeed(name);
      if (targetAverage <= 1e-6) continue;
      final ratio = actualAverage / targetAverage;
      tempoRatio[name] = ratio;
      tempoColors[name] =
          ratio >= .8 && ratio <= 1.2 ? JointColor.red : JointColor.amber;
    }
    _previous
      ..clear()
      ..addAll(features);
    String? cue;
    if ((_frame - _lastCueFrame) / fps >= 3) {
      final candidates =
          recipe.tracked.where((name) => (_streak[name] ?? 0) >= 10).toList()
            ..sort((a, b) {
              final guardOrder = (recipe.guard.contains(b) ? 1 : 0) -
                  (recipe.guard.contains(a) ? 1 : 0);
              return guardOrder != 0
                  ? guardOrder
                  : (deviation[b] ?? 0).compareTo(deviation[a] ?? 0);
            });
      if (candidates.isNotEmpty) {
        final name = candidates.first;
        final actual = features[name];
        final templateList = recipe.template[name];
        if (actual != null &&
            actual.isFinite &&
            templateList != null &&
            phase < templateList.length) {
          final low = actual < templateList[phase];
          cue = _cue(name, low);
          _lastCueFrame = _frame;
          _streak[name] = 0;
        }
      }
    }
    if (event != null) {
      cue = recipe.guidance['rep_complete'] ??
          'Good, repetition ${event.rep} complete';
      _lastCueFrame = _frame;
    } else if (previousState != counter.state &&
        counter.state == RepState.top) {
      cue = recipe.guidance['hold'] ??
          'Good, hold this position and keep your body stable';
      _lastCueFrame = _frame;
    } else if (previousState != counter.state &&
        counter.state == RepState.descending &&
        cue == null) {
      cue = recipe.guidance['descending'] ??
          'Return to the starting position slowly';
      _lastCueFrame = _frame;
    }
    return FrameFeedback(
        repCount: counter.count,
        repState: counter.state,
        phase: phase,
        progress: counter.progress,
        colors: colors,
        deviation: deviation,
        tempoColors: tempoColors,
        tempoRatio: tempoRatio,
        cue: cue,
        completedRep: event,
        completedScore: score);
  }

  double _targetAverageSpeed(String name) {
    final values = recipe.template[name];
    if (values == null || values.isEmpty) return 0.0;
    var travel = 0.0;
    for (var index = 1; index < values.length; index++) {
      travel += (values[index] - values[index - 1]).abs();
    }
    return travel *
        recipe.progressionFactor /
        math.max(recipe.cycleSeconds, 1e-6);
  }

  String _cue(String name, bool low) {
    final side = name.endsWith('_L')
        ? 'left'
        : name.endsWith('_R')
            ? 'right'
            : '';
    if (recipe.guard.contains(name)) {
      if (name == 'trunk_incline') {
        return recipe.guidance['guard_trunk'] ??
            'Keep your torso upright and do not lean';
      }
      if (name == 'pelvis_shift') {
        return recipe.guidance['guard_pelvis'] ?? 'Keep your pelvis stable';
      }
      if (name.startsWith('shoulder_hike')) {
        return 'Keep your $side shoulder relaxed';
      }
      return 'Keep your ${_jointName(name)} stable';
    }
    if (name.startsWith('knee_flex')) {
      return low
          ? 'Bend your $side knee a little more'
          : 'Straighten your $side knee slowly';
    }
    if (name == 'trunk_incline') return 'Keep your torso upright';
    if (name.startsWith('hip_flex')) {
      return low
          ? 'Lift your $side thigh a little higher'
          : 'Lower your $side thigh slowly';
    }
    if (name.startsWith('elbow_flex')) {
      return low
          ? 'Bend your $side elbow a little more'
          : 'Straighten your $side elbow';
    }
    if (name.startsWith('shoulder_elev')) {
      return low
          ? 'Raise your $side arm higher'
          : 'Lower your $side arm slowly';
    }
    return 'Return to the demonstrated position';
  }

  String _jointName(String name) {
    if (name.startsWith('knee')) return 'knee';
    if (name.startsWith('hip')) return 'thigh';
    if (name.startsWith('ankle')) return 'ankle';
    if (name.startsWith('shoulder')) return 'shoulder';
    if (name.startsWith('elbow')) return 'elbow';
    return 'other body part';
  }
}
