import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/services/unit_estimator.dart';

void main() {
  test('reports seed unit before it has evidence', () {
    final e = MedianUnitEstimator(seedUnitMs: 180);
    expect(e.estimatedUnitMs, 180);
    expect(e.isStable, false);
  });

  test('a single ambiguous pulse does NOT move off the seed', () {
    final e = MedianUnitEstimator(seedUnitMs: 180);
    e.addOnPulse(540); // could be a dash — must not be assumed a dot
    expect(e.isStable, false);
    expect(e.estimatedUnitMs, 180);
  });

  test('converges to dot length from dots + dashes once stable', () {
    final e = MedianUnitEstimator(seedUnitMs: 180);
    for (final d in [100, 300, 100, 100, 300]) {
      e.addOnPulse(d);
    }
    expect(e.isStable, true);
    expect(e.estimatedUnitMs, inInclusiveRange(90, 110));
  });

  test('ignores non-positive durations', () {
    final e = MedianUnitEstimator(seedUnitMs: 180);
    e.addOnPulse(0);
    e.addOnPulse(-10);
    expect(e.isStable, false);
    expect(e.estimatedUnitMs, 180);
  });

  test('reset clears state', () {
    final e = MedianUnitEstimator(seedUnitMs: 180);
    for (final d in [100, 100, 100]) {
      e.addOnPulse(d);
    }
    e.reset();
    expect(e.estimatedUnitMs, 180);
    expect(e.isStable, false);
  });
}
