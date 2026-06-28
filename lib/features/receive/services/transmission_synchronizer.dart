import '../domain/pulse.dart';
import '../domain/pulse_symbol.dart';
import '../domain/sync_phase.dart';
import 'pulse_classifier.dart';
import 'unit_estimator.dart';

/// How a candidate pulse fits the timing model for an estimated unit.
enum _Fit { clean, boundary, misfit }

/// Conservative synchronization gate. Decoding only begins once there is strong
/// evidence of a real, regularly-timed transmission — this is what stops the
/// receiver from emitting random letters when the camera merely moves or sees
/// ambient light.
///
/// Gate (scale-invariant — the unit is estimated from the signal itself):
/// - SEARCHING ignores OFF pulses; a real transmission starts with light ON.
/// - While SYNCHRONIZING it buffers pulses and, once the unit is estimable,
///   requires every recent pulse to quantize cleanly to 1u/3u (ON) or
///   1u/3u/7u (OFF) within tolerance.
/// - It LOCKs only after [minOnPulses] ON pulses AND [minConsecutiveFit]
///   consecutive clean-fitting pulses, then replays the buffer so nothing is
///   lost.
/// - Any gross misfit (irregular duration / inconsistent spacing), a long
///   silence, or buffer overflow resets to SEARCHING.
/// - When LOCKED, a long end-of-transmission silence flushes and re-gates.
///
/// Seam for future preamble detection / acknowledgements.
class TransmissionSynchronizer {
  TransmissionSynchronizer({
    required UnitEstimator estimator,
    required PulseClassifier classifier,
    this.minOnPulses = 4,
    this.minConsecutiveFit = 6,
    this.resetGapUnits = 12,
    this.maxCandidatePulses = 24,
  })  : _estimator = estimator,
        _classifier = classifier;

  final UnitEstimator _estimator;
  final PulseClassifier _classifier;

  /// Minimum number of ON pulses required before a lock is allowed.
  final int minOnPulses;

  /// Minimum run of consecutive clean-fitting pulses required to lock.
  final int minConsecutiveFit;

  /// An OFF pulse this many units long (or longer) ends a candidate / message.
  final int resetGapUnits;

  /// If the candidate grows past this without locking, it is incoherent noise.
  final int maxCandidatePulses;

  final List<Pulse> _buffer = [];
  SyncPhase _phase = SyncPhase.searching;

  SyncPhase get phase => _phase;
  int get estimatedUnitMs => _estimator.estimatedUnitMs;

  List<PulseSymbol> process(Pulse pulse) {
    if (_phase == SyncPhase.locked) {
      return _processLocked(pulse);
    }

    // SEARCHING: ignore OFF — no light yet means no signal to lock onto.
    if (_phase == SyncPhase.searching) {
      if (!pulse.isOn) return const [];
      _phase = SyncPhase.synchronizing;
    }

    // A long silence while still gating means the candidate (real or noise)
    // has ended without enough evidence → start over.
    final unitForGap = _estimator.estimatedUnitMs;
    if (!pulse.isOn && pulse.durationMs >= resetGapUnits * unitForGap) {
      _toSearching();
      return const [];
    }

    if (pulse.isOn && pulse.durationMs > 0) {
      _estimator.addOnPulse(pulse.durationMs);
    }
    _buffer.add(pulse);
    if (_buffer.length > maxCandidatePulses) {
      _toSearching();
      return const [];
    }

    // Can't judge consistency until the unit is estimable.
    if (!_estimator.isStable) return const [];
    final u = _estimator.estimatedUnitMs.toDouble();

    // The newest pulse failing the model is strong evidence of non-Morse
    // (irregular timing / inconsistent spacing) → reject the candidate.
    if (_fit(pulse, u) == _Fit.misfit) {
      _toSearching();
      return const [];
    }

    if (_hasLockEvidence(u)) {
      return _lockAndReplay();
    }
    return const [];
  }

  List<PulseSymbol> _processLocked(Pulse pulse) {
    if (pulse.isOn && pulse.durationMs > 0) {
      _estimator.addOnPulse(pulse.durationMs);
    }
    final u = _estimator.estimatedUnitMs;
    final symbol = _classifier.classify(pulse, u);
    // End of transmission: a long silence flushes the last letter and re-gates
    // so the next message (or noise) must earn a fresh lock.
    if (!pulse.isOn && u > 0 && pulse.durationMs >= resetGapUnits * u) {
      _toSearching();
    }
    return [symbol];
  }

  /// Lock when there are enough ON pulses and a long enough trailing run of
  /// clean-fitting pulses.
  bool _hasLockEvidence(double u) {
    var run = 0;
    for (var i = _buffer.length - 1; i >= 0; i--) {
      if (_fit(_buffer[i], u) != _Fit.clean) break;
      run++;
    }
    if (run < minConsecutiveFit) return false;
    final onCount = _buffer.where((p) => p.isOn).length;
    return onCount >= minOnPulses;
  }

  _Fit _fit(Pulse p, double u) {
    if (u <= 0 || p.durationMs <= 0) return _Fit.misfit;
    final r = p.durationMs / u;
    if (p.isOn) {
      if (r >= 0.4 && r <= 1.6) return _Fit.clean; // dot
      if (r >= 2.2 && r <= 4.2) return _Fit.clean; // dash
      return _Fit.misfit;
    }
    if (r >= 0.4 && r <= 1.6) return _Fit.clean; // symbol gap
    if (r >= 2.2 && r <= 4.2) return _Fit.clean; // letter gap
    if (r >= 5.0 && r <= 9.0) return _Fit.clean; // word gap
    if (r > 9.0) return _Fit.boundary; // end-of-message silence
    return _Fit.misfit; // dead zones between valid multiples
  }

  List<PulseSymbol> _lockAndReplay() {
    _phase = SyncPhase.locked;
    final u = _estimator.estimatedUnitMs;
    final replayed = _buffer
        .map((p) => _classifier.classify(p, u))
        .toList(growable: false);
    _buffer.clear();
    return replayed;
  }

  void _toSearching() {
    _phase = SyncPhase.searching;
    _buffer.clear();
    _estimator.reset();
  }

  void reset() => _toSearching();
}
