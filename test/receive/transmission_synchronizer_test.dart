import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/pulse.dart';
import 'package:morse/features/receive/domain/pulse_symbol.dart';
import 'package:morse/features/receive/domain/sync_phase.dart';
import 'package:morse/features/receive/services/pulse_classifier.dart';
import 'package:morse/features/receive/services/transmission_synchronizer.dart';
import 'package:morse/features/receive/services/unit_estimator.dart';

TransmissionSynchronizer build() => TransmissionSynchronizer(
      estimator: MedianUnitEstimator(seedUnitMs: 180),
      classifier: PulseClassifier(),
    );

/// Feed a list of pulses, collecting all emitted symbols.
List<PulseSymbol> feed(TransmissionSynchronizer s, List<Pulse> pulses) {
  final out = <PulseSymbol>[];
  for (final p in pulses) {
    out.addAll(s.process(p));
  }
  return out;
}

const dotOn = Pulse(isOn: true, durationMs: 100);
const dashOn = Pulse(isOn: true, durationMs: 300);
const symGap = Pulse(isOn: false, durationMs: 100);

void main() {
  test('starts searching', () {
    expect(build().phase, SyncPhase.searching);
  });

  test('ignores OFF noise while searching — stays searching, emits nothing', () {
    final s = build();
    final emitted = feed(s, const [
      Pulse(isOn: false, durationMs: 50),
      Pulse(isOn: false, durationMs: 300),
      Pulse(isOn: false, durationMs: 50),
    ]);
    expect(s.phase, SyncPhase.searching);
    expect(emitted, isEmpty);
  });

  test('locks on a consistent train and replays the buffer', () {
    final s = build();
    // Four clean dots → enough ON pulses and a long clean run.
    final emitted = feed(s, const [
      dotOn, symGap, dotOn, symGap, dotOn, symGap, dotOn,
    ]);
    expect(s.phase, SyncPhase.locked);
    expect(emitted.where((x) => x == PulseSymbol.dot).length, 4);
  });

  test('does NOT lock on too few pulses (conservative gate)', () {
    final s = build();
    final emitted = feed(s, const [dotOn, symGap, dotOn, symGap, dotOn]);
    expect(s.phase, isNot(SyncPhase.locked));
    expect(emitted, isEmpty);
  });

  test('rejects irregular timing — a misfit pulse resets to searching', () {
    final s = build();
    // Establish a unit with three clean dots, then a 2u pulse fits nothing.
    feed(s, const [dotOn, symGap, dotOn, symGap, dotOn]);
    final emitted = feed(s, const [Pulse(isOn: true, durationMs: 200)]);
    expect(s.phase, SyncPhase.searching);
    expect(emitted, isEmpty);
  });

  test('long silence while gating resets to searching', () {
    final s = build();
    feed(s, const [dotOn, symGap]); // not yet stable
    final emitted = feed(s, const [Pulse(isOn: false, durationMs: 5000)]);
    expect(s.phase, SyncPhase.searching);
    expect(emitted, isEmpty);
  });

  test('reset returns to searching', () {
    final s = build();
    s.process(dotOn);
    s.reset();
    expect(s.phase, SyncPhase.searching);
  });
}
