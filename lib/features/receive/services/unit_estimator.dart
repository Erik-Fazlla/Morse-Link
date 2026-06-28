/// Estimates the Morse time-unit (ms) from observed ON-pulse durations.
/// Swap this implementation for future auto-calibration.
abstract class UnitEstimator {
  int get estimatedUnitMs;
  bool get isStable;
  void addOnPulse(int durationMs);
  void reset();
}

/// Reports the seed unit until it has enough evidence (>=3 ON pulses), then
/// the median of the "dot cluster" (durations within 1.6x the running
/// minimum). A single isolated pulse is fundamentally dot/dash-ambiguous, so
/// trusting the seed until real evidence arrives is deliberate.
class MedianUnitEstimator implements UnitEstimator {
  MedianUnitEstimator({this.seedUnitMs = 180});

  final int seedUnitMs;
  final List<int> _onDurations = [];
  int _computed = 0;

  @override
  int get estimatedUnitMs => isStable ? _computed : seedUnitMs;

  @override
  bool get isStable => _onDurations.length >= 3;

  @override
  void addOnPulse(int durationMs) {
    if (durationMs <= 0) return;
    _onDurations.add(durationMs);
    final minOn = _onDurations.reduce((a, b) => a < b ? a : b);
    final dotCluster = _onDurations.where((d) => d <= minOn * 1.6).toList()
      ..sort();
    _computed = _median(dotCluster, fallback: seedUnitMs);
  }

  @override
  void reset() {
    _onDurations.clear();
    _computed = 0;
  }

  int _median(List<int> sorted, {required int fallback}) {
    if (sorted.isEmpty) return fallback;
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }
}
