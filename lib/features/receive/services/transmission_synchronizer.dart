import '../domain/pulse.dart';
import '../domain/pulse_symbol.dart';
import '../domain/sync_phase.dart';
import 'pulse_classifier.dart';
import 'unit_estimator.dart';

/// Confidence-based synchronization gate. Separates the three concerns:
/// detection (upstream LightDetector), **synchronization** (this class), and
/// decoding (downstream classifier/accumulator/decoder).
///
/// Rather than a brittle all-or-nothing lock that any single mistimed pulse
/// resets, each pulse contributes a continuous fit score to a running
/// confidence:
/// - clean pulses (durations near 1u/3u for ON, 1u/3u/7u for OFF) raise it,
/// - misfits lower it (penalised harder, to keep false positives near zero),
/// - it is bounded, so a clean message *banks* confidence and becomes
///   progressively more tolerant of the occasional glitch (distance / motion).
///
/// It **soft-locks** when confidence crosses [lockHigh] (with enough ON pulses)
/// and **retroactively decodes the buffer**, so a single transmission decodes
/// from its first letter without repetition. It stays locked until confidence
/// falls below [lockLow] (hysteresis) or an end-of-message silence, then
/// re-gates. Random light / camera motion never sustains the rising confidence
/// needed to lock.
class TransmissionSynchronizer {
  TransmissionSynchronizer({
    required UnitEstimator estimator,
    required PulseClassifier classifier,
    this.minOnPulses = 3,
    this.lockHigh = 2.5,
    this.lockLow = 0.8,
    this.confidenceCap = 6.0,
    this.cleanThreshold = 0.5,
    this.misfitPenalty = 1.5,
    this.fitTolerance = 0.6,
    this.resetGapUnits = 12,
    this.maxCandidatePulses = 48,
  })  : _estimator = estimator,
        _classifier = classifier;

  final UnitEstimator _estimator;
  final PulseClassifier _classifier;

  /// ON pulses required before a lock is allowed.
  final int minOnPulses;

  /// Confidence needed to soft-lock.
  final double lockHigh;

  /// Confidence below which a lock is lost.
  final double lockLow;

  /// Upper bound on banked confidence.
  final double confidenceCap;

  /// Fit score at/above which a pulse counts as clean.
  final double cleanThreshold;

  /// Confidence subtracted for a misfit pulse.
  final double misfitPenalty;

  /// Relative deviation that drives the fit score to zero.
  final double fitTolerance;

  /// An OFF pulse this many units long ends a candidate / message.
  final int resetGapUnits;

  /// Safety bound on the candidate buffer.
  final int maxCandidatePulses;

  final List<Pulse> _buffer = [];
  SyncPhase _phase = SyncPhase.searching;
  double _confidence = 0;

  SyncPhase get phase => _phase;
  int get estimatedUnitMs => _estimator.estimatedUnitMs;
  double get confidence => _confidence;

  List<PulseSymbol> process(Pulse pulse) {
    if (_phase == SyncPhase.locked) return _processLocked(pulse);

    // SEARCHING: ignore OFF — no light yet means no signal to lock onto.
    if (_phase == SyncPhase.searching) {
      if (!pulse.isOn) return const [];
      _phase = SyncPhase.synchronizing;
    }

    // A long silence ends the candidate (real or noise) → start over.
    if (!pulse.isOn &&
        pulse.durationMs >= resetGapUnits * _estimator.estimatedUnitMs) {
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

    // Can't score consistency until the unit is estimable.
    if (!_estimator.isStable) return const [];
    final u = _estimator.estimatedUnitMs.toDouble();

    _updateConfidence(pulse, u);
    if (_confidence <= 0) {
      // Drained by sustained misfits → this candidate is not a transmission.
      _toSearching();
      return const [];
    }

    final onCount = _buffer.where((p) => p.isOn).length;
    if (_confidence >= lockHigh && onCount >= minOnPulses) {
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

    // End of transmission: a long silence flushes the last letter and re-gates.
    if (!pulse.isOn && u > 0 && pulse.durationMs >= resetGapUnits * u) {
      _toSearching();
      return [symbol];
    }

    // Track confidence for unlock hysteresis: sustained inconsistency (lost
    // signal / heavy motion) drops the lock; isolated glitches do not.
    _updateConfidence(pulse, u.toDouble());
    if (_confidence <= lockLow) {
      _toSearching();
    }
    return [symbol];
  }

  void _updateConfidence(Pulse pulse, double u) {
    final f = _fitScore(pulse, u);
    if (f >= cleanThreshold) {
      _confidence += f;
    } else {
      _confidence -= misfitPenalty;
    }
    _confidence = _confidence.clamp(0.0, confidenceCap);
  }

  /// Continuous fit in [0,1]: 1 = exactly on a valid multiple, 0 = a full
  /// [fitTolerance] (relative) away or worse.
  double _fitScore(Pulse p, double u) {
    if (u <= 0 || p.durationMs <= 0) return 0;
    final r = p.durationMs / u;
    final ideals = p.isOn ? const [1.0, 3.0] : const [1.0, 3.0, 7.0];
    var nearest = ideals.first;
    var best = (r - nearest).abs();
    for (final m in ideals) {
      final d = (r - m).abs();
      if (d < best) {
        best = d;
        nearest = m;
      }
    }
    final residual = (r - nearest).abs() / nearest;
    return (1 - residual / fitTolerance).clamp(0.0, 1.0);
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
    _confidence = 0;
    _estimator.reset();
  }

  void reset() => _toSearching();
}
