import '../domain/light_reading.dart';

/// A light ON/OFF transition at a timestamp (the moment the change began).
class LightTransition {
  const LightTransition({required this.isOn, required this.atMs});
  final bool isOn;
  final int atMs;
}

/// Converts a luminance stream into debounced ON/OFF transitions under
/// real-world conditions:
///
/// - **Adaptive threshold:** an asymmetric envelope tracks the OFF floor
///   (fast down / slow up) and the ON peak (fast up / slow down). The decision
///   threshold sits at their midpoint, so ambient level is irrelevant — only
///   contrast matters.
/// - **Hysteresis:** a dead-band around the midpoint prevents flicker when the
///   luminance hovers near the threshold.
/// - **Minimum pulse duration:** a candidate state change must persist for
///   [minPulseMs] before it is confirmed, rejecting momentary noise spikes.
/// - **Idle timeout:** [isIdle] reports when no ON activity has occurred for
///   [idleTimeoutMs] — used to detect the end of a transmission.
/// - **Variable frame rate:** all timing uses the reading timestamps, so
///   missing frames and jitter are tolerated.
///
/// Transition timestamps are the *start* of the change (when the threshold was
/// first crossed), not the confirmation time, so pulse durations stay accurate.
class LightDetector {
  LightDetector({
    this.minRangeForSignal = 30,
    this.hysteresisFraction = 0.2,
    this.minPulseMs = 45,
    this.idleTimeoutMs = 1500,
    this.floorUpRate = 0.01,
    this.peakDownRate = 0.01,
  });

  /// Minimum ON/OFF contrast (0–255) before any signal is considered present.
  final double minRangeForSignal;

  /// Dead-band half-width as a fraction of the current contrast.
  final double hysteresisFraction;

  /// A state change must hold this long (ms) to be confirmed.
  final int minPulseMs;

  /// No ON activity for this long (ms) marks the end of a transmission.
  final int idleTimeoutMs;

  /// Slow-rise rate of the OFF floor while light is brighter than it.
  final double floorUpRate;

  /// Slow-decay rate of the ON peak while light is dimmer than it.
  final double peakDownRate;

  double? _floor;
  double? _peak;
  bool _confirmedOn = false;
  bool? _candidateOn;
  int _candidateSinceMs = 0;
  int? _lastOnMs;

  double get signalStrengthPct {
    if (_floor == null || _peak == null) return 0;
    return (((_peak! - _floor!) / 255.0) * 100).clamp(0, 100).toDouble();
  }

  bool get hasSignal =>
      _floor != null && (_peak! - _floor!) >= minRangeForSignal;

  bool get isOn => _confirmedOn;

  /// True when no ON activity has happened for [idleTimeoutMs].
  bool isIdle(int nowMs) =>
      _lastOnMs != null && (nowMs - _lastOnMs!) >= idleTimeoutMs;

  /// Feed one luminance sample. Returns a transition if (and only if) a
  /// debounced state change is confirmed.
  LightTransition? process(LightReading r) {
    _updateEnvelope(r.luminance);
    if (!hasSignal) {
      return null;
    }

    final mid = (_floor! + _peak!) / 2;
    final band = (_peak! - _floor!) * hysteresisFraction;
    final rawOn = r.luminance > mid + band
        ? true
        : (r.luminance < mid - band ? false : _confirmedOn);

    if (_confirmedOn) {
      _lastOnMs = r.timestampMs;
    }

    if (rawOn == _confirmedOn) {
      _candidateOn = null; // pending flip canceled → noise rejected
      return null;
    }

    if (_candidateOn != rawOn) {
      // New candidate change — start the debounce window.
      _candidateOn = rawOn;
      _candidateSinceMs = r.timestampMs;
      return null;
    }

    // Candidate has persisted; confirm once it has held long enough.
    if (r.timestampMs - _candidateSinceMs >= minPulseMs) {
      final atMs = _candidateSinceMs;
      _confirmedOn = rawOn;
      _candidateOn = null;
      if (rawOn) _lastOnMs = atMs;
      return LightTransition(isOn: rawOn, atMs: atMs);
    }
    return null;
  }

  void _updateEnvelope(double lum) {
    if (_floor == null || _peak == null) {
      _floor = lum;
      _peak = lum;
      return;
    }
    // Floor: snap down to a new dark level, rise slowly otherwise.
    _floor = lum < _floor! ? lum : _floor! + (lum - _floor!) * floorUpRate;
    // Peak: snap up to a new bright level, decay slowly otherwise.
    _peak = lum > _peak! ? lum : _peak! + (lum - _peak!) * peakDownRate;
  }

  void reset() {
    _floor = null;
    _peak = null;
    _confirmedOn = false;
    _candidateOn = null;
    _candidateSinceMs = 0;
    _lastOnMs = null;
  }
}
