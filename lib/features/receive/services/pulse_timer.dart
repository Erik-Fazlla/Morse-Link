import '../domain/pulse.dart';
import 'light_detector.dart';

/// Closes each light interval into a [Pulse] when the next transition arrives.
/// Durations are derived purely from transition timestamps, so output is
/// deterministic for a given transition sequence.
class PulseTimer {
  bool? _openState;
  int _openAtMs = 0;

  /// Returns the pulse that just ended, if any.
  Pulse? onTransition(LightTransition t) {
    Pulse? closed;
    if (_openState != null) {
      closed = Pulse(isOn: _openState!, durationMs: t.atMs - _openAtMs);
    }
    _openState = t.isOn;
    _openAtMs = t.atMs;
    return closed;
  }

  /// Close the currently open interval at [nowMs].
  Pulse? flush(int nowMs) {
    if (_openState == null) return null;
    final p = Pulse(isOn: _openState!, durationMs: nowMs - _openAtMs);
    _openState = null;
    return p;
  }

  void reset() {
    _openState = null;
    _openAtMs = 0;
  }
}
