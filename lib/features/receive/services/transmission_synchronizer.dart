import '../domain/pulse.dart';
import '../domain/pulse_symbol.dart';
import '../domain/sync_phase.dart';
import 'pulse_classifier.dart';
import 'unit_estimator.dart';

/// Gates decoding behind a synchronization phase. Buffers leading pulses while
/// the estimator stabilizes, then replays them on lock so no symbols are lost.
/// Seam for future preamble detection / acknowledgements / noise filtering.
///
/// Lock happens either when timing stabilizes (>=3 ON pulses) or, for short
/// messages that never reach that, when a long trailing silence finalizes the
/// buffered pulses. While searching, OFF pulses are ignored — no light yet
/// means no signal, so pre-transmission silence/noise cannot start decoding.
class TransmissionSynchronizer {
  TransmissionSynchronizer({
    required UnitEstimator estimator,
    required PulseClassifier classifier,
    this.finalizeGapUnits = 7,
  })  : _estimator = estimator,
        _classifier = classifier;

  final UnitEstimator _estimator;
  final PulseClassifier _classifier;

  /// A trailing OFF pulse this many units long (or longer) finalizes a short,
  /// not-yet-stable message.
  final int finalizeGapUnits;

  final List<Pulse> _buffer = [];
  SyncPhase _phase = SyncPhase.searching;

  SyncPhase get phase => _phase;
  int get estimatedUnitMs => _estimator.estimatedUnitMs;

  /// Feed one pulse. Returns the symbols ready for decoding — empty while still
  /// buffering, the replayed batch on the lock transition, or a single symbol
  /// while locked.
  List<PulseSymbol> process(Pulse pulse) {
    if (_phase == SyncPhase.locked) {
      if (pulse.isOn && pulse.durationMs > 0) {
        _estimator.addOnPulse(pulse.durationMs);
      }
      return [_classifier.classify(pulse, _estimator.estimatedUnitMs)];
    }

    // searching: ignore OFF (no signal yet); first ON begins synchronizing.
    if (_phase == SyncPhase.searching) {
      if (!pulse.isOn) return const [];
      _phase = SyncPhase.synchronizing;
    }

    // synchronizing: calibrate from ON pulses, buffer everything.
    if (pulse.isOn && pulse.durationMs > 0) {
      _estimator.addOnPulse(pulse.durationMs);
    }

    if (_estimator.isStable) {
      _buffer.add(pulse);
      return _lockAndReplay();
    }

    // Finalize a short message on a long trailing silence. The silence pulse
    // itself is not replayed (it is a boundary, not a symbol).
    final isFinalizingSilence = !pulse.isOn &&
        _bufferHasOnPulse() &&
        pulse.durationMs >= finalizeGapUnits * _estimator.estimatedUnitMs;
    if (isFinalizingSilence) {
      return _lockAndReplay();
    }

    _buffer.add(pulse);
    return const [];
  }

  List<PulseSymbol> _lockAndReplay() {
    _phase = SyncPhase.locked;
    final unit = _estimator.estimatedUnitMs;
    final replayed = _buffer
        .map((p) => _classifier.classify(p, unit))
        .toList(growable: false);
    _buffer.clear();
    return replayed;
  }

  bool _bufferHasOnPulse() => _buffer.any((p) => p.isOn);

  void reset() {
    _phase = SyncPhase.searching;
    _buffer.clear();
    _estimator.reset();
  }
}
