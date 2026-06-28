import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/domain/light_reading.dart';
import 'package:morse/features/receive/services/light_detector.dart';

/// Feed a steady level for [durMs] at [sampleMs] spacing, collecting any
/// transitions, advancing a shared clock.
class _Driver {
  _Driver(this.detector);
  final LightDetector detector;
  int t = 0;
  final List<LightTransition> transitions = [];

  void hold(double lum, int durMs, {int sampleMs = 20}) {
    for (var e = 0; e < durMs; e += sampleMs) {
      final tr = detector.process(LightReading(luminance: lum, timestampMs: t));
      if (tr != null) transitions.add(tr);
      t += sampleMs;
    }
  }
}

void main() {
  test('emits ON then OFF across the adaptive threshold', () {
    final d = _Driver(LightDetector());
    d.hold(15, 200); // ambient / OFF baseline
    d.hold(230, 200); // ON
    d.hold(15, 200); // OFF
    d.hold(230, 200); // ON
    expect(d.transitions.map((t) => t.isOn).toList(), [true, false, true]);
  });

  test('rejects a short noise spike (min pulse filter)', () {
    final d = _Driver(LightDetector(minPulseMs: 45));
    d.hold(15, 200); // baseline
    d.hold(230, 20); // 20ms spike < minPulse → rejected
    d.hold(15, 300); // back to dark
    expect(d.transitions, isEmpty);
  });

  test('flat dark input → no signal, no transitions', () {
    final d = _Driver(LightDetector());
    d.hold(8, 300);
    expect(d.transitions, isEmpty);
    expect(d.detector.signalStrengthPct, lessThan(15));
  });

  test('small wobble near the threshold does not flicker (hysteresis)', () {
    final d = _Driver(LightDetector());
    d.hold(15, 200); // baseline
    d.hold(230, 200); // establish ON (peak ~230, floor ~15, mid ~122)
    // wobble around the midpoint without crossing the hysteresis band
    for (var i = 0; i < 10; i++) {
      d.hold(i.isEven ? 130 : 115, 40);
    }
    // Only the initial OFF→ON transition; no flicker from the wobble.
    expect(d.transitions.where((t) => !t.isOn), isEmpty);
    expect(d.transitions.where((t) => t.isOn).length, 1);
  });

  test('adapts to a brighter ambient level (offset, not contrast)', () {
    final d = _Driver(LightDetector());
    // High ambient floor of 90; ON pulses at 250.
    d.hold(90, 200);
    d.hold(250, 200); // ON
    d.hold(90, 200); // OFF
    expect(d.transitions.map((t) => t.isOn).toList(), [true, false]);
  });

  test('idle timeout reports transmission end after silence', () {
    final d = _Driver(LightDetector(idleTimeoutMs: 500));
    d.hold(15, 100);
    d.hold(230, 100); // ON activity
    expect(d.detector.isIdle(d.t), isFalse);
    d.hold(15, 600); // silence beyond idle timeout
    expect(d.detector.isIdle(d.t), isTrue);
  });
}
