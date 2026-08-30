import 'dart:math' as math;

class OneEuroFilter {
  OneEuroFilter(
      {required this.frequency,
      this.minCutoff = 1.0,
      this.beta = 0.007,
      this.derivativeCutoff = 1.0});
  final double frequency;
  final double minCutoff;
  final double beta;
  final double derivativeCutoff;
  double? _previousRaw;
  double? _filtered;
  double? _filteredDerivative;

  double _alpha(double cutoff) {
    final samplePeriod = 1 / frequency;
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / samplePeriod);
  }

  double call(double value) {
    if (!value.isFinite) return double.nan;
    final prevRaw = _previousRaw;
    final derivative =
        prevRaw == null ? 0.0 : (value - prevRaw) * frequency;
    _previousRaw = value;
    final derivativeAlpha = _alpha(derivativeCutoff);
    final prevFilteredDeriv = _filteredDerivative;
    final filteredDerivative = prevFilteredDeriv == null
        ? derivative
        : derivativeAlpha * derivative +
            (1 - derivativeAlpha) * prevFilteredDeriv;
    _filteredDerivative = filteredDerivative;
    final cutoff = minCutoff + beta * filteredDerivative.abs();
    final alpha = _alpha(cutoff);
    final prevFiltered = _filtered;
    final filtered = prevFiltered == null
        ? value
        : alpha * value + (1 - alpha) * prevFiltered;
    _filtered = filtered;
    return filtered;
  }
}

class FeatureFilterBank {
  FeatureFilterBank(Iterable<String> features, {double frequency = 30})
      : _filters = {
          for (final feature in features)
            feature: OneEuroFilter(frequency: frequency)
        };
  final Map<String, OneEuroFilter> _filters;

  Map<String, double> call(Map<String, double> values) => {
        for (final entry in values.entries)
          entry.key: _filters[entry.key]?.call(entry.value) ?? entry.value,
      };
}
