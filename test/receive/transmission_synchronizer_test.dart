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

void main() {
  test('starts searching', () {
    expect(build().phase, SyncPhase.searching);
  });

  test('ignores OFF noise while searching — stays searching, emits nothing',
      () {
    final s = build();
    final emitted = <PulseSymbol>[];
    for (final p in const [
      Pulse(isOn: false, durationMs: 50),
      Pulse(isOn: false, durationMs: 300),
      Pulse(isOn: false, durationMs: 50),
    ]) {
      emitted.addAll(s.process(p));
    }
    expect(s.phase, SyncPhase.searching);
    expect(emitted, isEmpty);
  });

  test('buffers during sync then replays on lock; nothing lost', () {
    final s = build();
    final emitted = <PulseSymbol>[];
    // S = dot, gap, dot, gap, dot → estimator stable on the 3rd ON pulse.
    for (final p in const [
      Pulse(isOn: true, durationMs: 100),
      Pulse(isOn: false, durationMs: 100),
      Pulse(isOn: true, durationMs: 100),
      Pulse(isOn: false, durationMs: 100),
      Pulse(isOn: true, durationMs: 100),
    ]) {
      emitted.addAll(s.process(p));
    }
    expect(s.phase, SyncPhase.locked);
    expect(emitted, [
      PulseSymbol.dot,
      PulseSymbol.symbolGap,
      PulseSymbol.dot,
      PulseSymbol.symbolGap,
      PulseSymbol.dot,
    ]);
  });

  test('locks a single short letter via trailing-silence finalize', () {
    final s = build();
    final emitted = <PulseSymbol>[];
    // 'T' at the seed unit: one dash, then a long silence.
    emitted.addAll(s.process(const Pulse(isOn: true, durationMs: 540)));
    expect(s.phase, SyncPhase.synchronizing);
    emitted.addAll(s.process(const Pulse(isOn: false, durationMs: 1400)));
    expect(s.phase, SyncPhase.locked);
    expect(emitted, [PulseSymbol.dash]);
  });

  test('reset returns to searching', () {
    final s = build();
    s.process(const Pulse(isOn: true, durationMs: 100));
    s.reset();
    expect(s.phase, SyncPhase.searching);
  });
}
